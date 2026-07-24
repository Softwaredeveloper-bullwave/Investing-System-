"""Paper commodity trading — mirrors `commodity_trading_service.py` exactly
(live USD quote fetched server-side via `get_commodity_detail`, same
USD→INR conversion and avg-cost math) but settles against `PaperWallet`
instead of `finance.Wallet`, and never writes a real `finance.Transaction`.
"""

from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP

from django.db import transaction

from .commodity_service import COMMODITY_CATALOG, get_commodity_detail
from .commodity_trading_service import get_usd_inr_rate
from .models import PaperCommodityHolding, PaperCommodityOrder, PaperWallet
from .trading_service import _write_ledger

DEFAULT_COMMODITY_CHARGE_RATE = Decimal('0.0005')


class PaperCommodityTradingError(Exception):
    pass


def _round2(value) -> float:
    return round(float(value), 2)


def _inr_from_usd(usd_amount: Decimal, rate: Decimal) -> Decimal:
    return (usd_amount * rate).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


def _holding_payload(holding: PaperCommodityHolding, quote: dict, rate: Decimal) -> dict:
    ltp = Decimal(str(quote['ltp']))
    invested_inr = _inr_from_usd(holding.avg_price_usd * holding.quantity, rate)
    current_inr = _inr_from_usd(ltp * holding.quantity, rate)
    pnl_inr = current_inr - invested_inr
    meta = COMMODITY_CATALOG.get(holding.commodity_id, {})
    return {
        'commodityId': holding.commodity_id,
        'name': meta.get('name', holding.commodity_id),
        'shortName': meta.get('short_name', holding.commodity_id),
        'unit': meta.get('unit', ''),
        'quantity': holding.quantity,
        'avgPriceUsd': _round2(holding.avg_price_usd),
        'ltpUsd': _round2(ltp),
        'investedInr': _round2(invested_inr),
        'currentValueInr': _round2(current_inr),
        'pnlInr': _round2(pnl_inr),
        'pnlPercent': _round2((float(pnl_inr) / float(invested_inr) * 100) if invested_inr else 0),
    }


def list_paper_commodity_holdings(user) -> list[dict]:
    rate = get_usd_inr_rate()
    rows = []
    for holding in PaperCommodityHolding.objects.filter(user=user):
        quote = get_commodity_detail(holding.commodity_id)
        if not quote:
            continue
        rows.append(_holding_payload(holding, quote, rate))
    return rows


def build_paper_commodity_order_payload(order: PaperCommodityOrder, quote: dict, holding: PaperCommodityHolding | None = None) -> dict:
    meta = COMMODITY_CATALOG.get(order.commodity_id, {})
    payload = {
        'id': str(order.id),
        'commodityId': order.commodity_id,
        'name': meta.get('name', order.commodity_id),
        'shortName': meta.get('short_name', order.commodity_id),
        'unit': meta.get('unit', ''),
        'side': order.side,
        'quantity': order.quantity,
        'priceUsd': _round2(order.price_usd),
        'amountInr': _round2(order.amount_inr),
        'usdInrRate': _round2(order.usd_inr_rate),
        'charges': _round2(order.charges),
        'time': order.created_at.isoformat(),
        'status': order.status,
        'rejectReason': order.reject_reason,
        'orderValueUsd': _round2(order.price_usd * order.quantity),
        'ltpUsd': _round2(quote['ltp']) if quote else _round2(order.price_usd),
    }
    if order.avg_cost_usd is not None:
        payload['avgCostUsd'] = _round2(order.avg_cost_usd)
    if order.realized_pnl_inr is not None:
        payload['realizedPnlInr'] = _round2(order.realized_pnl_inr)
    if holding and holding.quantity > 0:
        payload['holdingQty'] = holding.quantity
        payload['holdingAvgPriceUsd'] = _round2(holding.avg_price_usd)
    return payload


def list_paper_commodity_orders(user, limit: int = 50) -> list[dict]:
    orders = PaperCommodityOrder.objects.filter(user=user).order_by('-created_at')[:limit]
    rows = []
    for order in orders:
        quote = get_commodity_detail(order.commodity_id) or {'ltp': order.price_usd}
        holding = PaperCommodityHolding.objects.filter(user=user, commodity_id=order.commodity_id).first()
        rows.append(build_paper_commodity_order_payload(order, quote, holding))
    return rows


@transaction.atomic
def place_paper_commodity_order(user, *, commodity_id: str, side: str, quantity: int) -> dict:
    commodity_id = commodity_id.upper().strip()
    side = side.upper().strip()
    if side not in ('BUY', 'SELL'):
        raise PaperCommodityTradingError('Invalid order side.')
    if quantity < 1:
        raise PaperCommodityTradingError('Quantity must be at least 1.')

    quote = get_commodity_detail(commodity_id)
    if not quote:
        raise PaperCommodityTradingError('Commodity not found.')

    price = Decimal(str(quote['ltp']))
    if price <= 0:
        raise PaperCommodityTradingError('Live price unavailable. Try again shortly.')

    rate = get_usd_inr_rate()
    order_usd = price * quantity
    order_inr = _inr_from_usd(order_usd, rate)
    charges = (order_inr * DEFAULT_COMMODITY_CHARGE_RATE).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    holding = PaperCommodityHolding.objects.filter(user=user, commodity_id=commodity_id).first()
    paper_wallet = PaperWallet.objects.select_for_update().get_or_create(
        user=user, defaults={
            'balance': PaperWallet.DEFAULT_STARTING_BALANCE,
            'starting_balance': PaperWallet.DEFAULT_STARTING_BALANCE,
        },
    )[0]

    if side == 'SELL':
        if not holding or holding.quantity < quantity:
            available = holding.quantity if holding else 0
            order = PaperCommodityOrder.objects.create(
                user=user, commodity_id=commodity_id, side=side, quantity=quantity,
                price_usd=price, amount_inr=Decimal('0'), usd_inr_rate=rate,
                status=PaperCommodityOrder.Status.REJECTED,
                reject_reason=f'Insufficient units. You hold {available}.',
            )
            raise PaperCommodityTradingError(order.reject_reason)

        avg_cost = holding.avg_price_usd
        cost_basis_inr = _inr_from_usd(avg_cost * quantity, rate)
        realized_pnl_inr = order_inr - cost_basis_inr - charges
        order = PaperCommodityOrder.objects.create(
            user=user, commodity_id=commodity_id, side=side, quantity=quantity, price_usd=price,
            amount_inr=order_inr, usd_inr_rate=rate, avg_cost_usd=avg_cost,
            realized_pnl_inr=realized_pnl_inr, charges=charges,
        )
        holding.quantity -= quantity
        if holding.quantity == 0:
            holding.delete()
            holding = None
        else:
            holding.save(update_fields=['quantity'])

        net_credit = order_inr - charges
        paper_wallet.balance += net_credit
        paper_wallet.save(update_fields=['balance'])
        _write_ledger(
            user, paper_wallet, entry_type='SELL', amount=net_credit,
            description=f'Sell commodity {quote.get("name", commodity_id)} × {quantity}',
        )
    else:
        total_debit = order_inr + charges
        if total_debit > paper_wallet.balance:
            order = PaperCommodityOrder.objects.create(
                user=user, commodity_id=commodity_id, side=side, quantity=quantity, price_usd=price,
                amount_inr=order_inr, usd_inr_rate=rate, charges=charges,
                status=PaperCommodityOrder.Status.REJECTED,
                reject_reason=(
                    f'Insufficient virtual balance. Need ₹{total_debit:,.2f}, have '
                    f'₹{paper_wallet.balance:,.2f} of practice capital.'
                ),
            )
            raise PaperCommodityTradingError(order.reject_reason)

        order = PaperCommodityOrder.objects.create(
            user=user, commodity_id=commodity_id, side=side, quantity=quantity, price_usd=price,
            amount_inr=order_inr, usd_inr_rate=rate, charges=charges,
        )
        if holding:
            total_cost = holding.quantity * holding.avg_price_usd + Decimal(quantity) * price
            holding.quantity += quantity
            holding.avg_price_usd = total_cost / holding.quantity
            holding.save()
        else:
            holding = PaperCommodityHolding.objects.create(
                user=user, commodity_id=commodity_id, quantity=quantity, avg_price_usd=price,
            )

        paper_wallet.balance -= total_debit
        paper_wallet.save(update_fields=['balance'])
        _write_ledger(
            user, paper_wallet, entry_type='BUY', amount=-total_debit,
            description=f'Buy commodity {quote.get("name", commodity_id)} × {quantity}',
        )

    return build_paper_commodity_order_payload(order, quote, holding)


@transaction.atomic
def exit_paper_commodity_position(user, *, commodity_id: str) -> dict:
    commodity_id = commodity_id.upper().strip()
    holding = PaperCommodityHolding.objects.filter(user=user, commodity_id=commodity_id).first()
    if not holding:
        raise PaperCommodityTradingError('No open position for this commodity.')
    return place_paper_commodity_order(user, commodity_id=commodity_id, side='SELL', quantity=holding.quantity)
