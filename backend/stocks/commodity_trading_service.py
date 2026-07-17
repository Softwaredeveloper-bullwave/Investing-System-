"""Commodity buy/sell with wallet settlement (USD quote → INR debit/credit)."""

from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP

from django.db import transaction

from finance.models import Transaction, Wallet, WalletTransaction

from .commodity_service import COMMODITY_CATALOG, get_commodity_detail
from .models import CommodityHolding, CommodityTrade

DEFAULT_USD_INR = Decimal('83.50')


class CommodityTradingError(Exception):
    pass


def _round2(value) -> float:
    return round(float(value), 2)


def get_usd_inr_rate() -> Decimal:
    try:
        from .yahoo_client import fetch_quote

        quote = fetch_quote('INR=X')
        if quote and float(quote.get('ltp', 0)) > 0:
            return Decimal(str(quote['ltp'])).quantize(Decimal('0.01'))
    except Exception:
        pass
    return DEFAULT_USD_INR


def _inr_from_usd(usd_amount: Decimal, rate: Decimal) -> Decimal:
    return (usd_amount * rate).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


def _holding_payload(holding: CommodityHolding, quote: dict, rate: Decimal) -> dict:
    ltp = Decimal(str(quote['ltp']))
    invested_inr = _inr_from_usd(holding.avg_price_usd * holding.quantity, rate)
    current_inr = _inr_from_usd(ltp * holding.quantity, rate)
    pnl_inr = current_inr - invested_inr
    meta = COMMODITY_CATALOG.get(holding.commodity_id, {})
    return {
        'commodity_id': holding.commodity_id,
        'name': meta.get('name', holding.commodity_id),
        'short_name': meta.get('short_name', holding.commodity_id),
        'unit': meta.get('unit', ''),
        'quantity': holding.quantity,
        'avg_price_usd': _round2(holding.avg_price_usd),
        'ltp_usd': _round2(ltp),
        'invested_inr': _round2(invested_inr),
        'current_value_inr': _round2(current_inr),
        'pnl_inr': _round2(pnl_inr),
        'pnl_percent': _round2(
            (float(pnl_inr) / float(invested_inr) * 100) if invested_inr else 0
        ),
    }


def list_commodity_holdings(user) -> list[dict]:
    rate = get_usd_inr_rate()
    rows = []
    for holding in CommodityHolding.objects.filter(user=user):
        quote = get_commodity_detail(holding.commodity_id)
        if not quote:
            continue
        rows.append(_holding_payload(holding, quote, rate))
    return rows


def build_trade_payload(
    trade: CommodityTrade,
    quote: dict,
    holding: CommodityHolding | None = None,
) -> dict:
    meta = COMMODITY_CATALOG.get(trade.commodity_id, {})
    payload = {
        'id': str(trade.id),
        'commodityId': trade.commodity_id,
        'name': meta.get('name', trade.commodity_id),
        'shortName': meta.get('short_name', trade.commodity_id),
        'unit': meta.get('unit', ''),
        'side': trade.side,
        'quantity': trade.quantity,
        'priceUsd': _round2(trade.price_usd),
        'amountInr': _round2(trade.amount_inr),
        'usdInrRate': _round2(trade.usd_inr_rate),
        'time': trade.created_at.isoformat(),
        'status': trade.status,
        'orderValueUsd': _round2(trade.price_usd * trade.quantity),
        'ltpUsd': _round2(quote['ltp']),
    }
    if trade.avg_cost_usd is not None:
        payload['avgCostUsd'] = _round2(trade.avg_cost_usd)
    if trade.realized_pnl_inr is not None:
        payload['realizedPnlInr'] = _round2(trade.realized_pnl_inr)
    if holding and holding.quantity > 0:
        payload['holdingQty'] = holding.quantity
        payload['holdingAvgPriceUsd'] = _round2(holding.avg_price_usd)
    return payload


@transaction.atomic
def place_commodity_order(user, *, commodity_id: str, side: str, quantity: int) -> dict:
    commodity_id = commodity_id.upper().strip()
    side = side.upper().strip()
    if side not in ('BUY', 'SELL'):
        raise CommodityTradingError('Invalid order side.')
    if quantity < 1:
        raise CommodityTradingError('Quantity must be at least 1.')

    quote = get_commodity_detail(commodity_id)
    if not quote:
        raise CommodityTradingError('Commodity not found.')

    price = Decimal(str(quote['ltp']))
    if price <= 0:
        raise CommodityTradingError('Live price unavailable. Try again shortly.')

    rate = get_usd_inr_rate()
    order_usd = price * quantity
    order_inr = _inr_from_usd(order_usd, rate)
    holding = CommodityHolding.objects.filter(user=user, commodity_id=commodity_id).first()
    wallet = Wallet.objects.select_for_update().get_or_create(user=user)[0]

    if side == 'SELL':
        if not holding or holding.quantity < quantity:
            available = holding.quantity if holding else 0
            raise CommodityTradingError(f'Insufficient units. You hold {available}.')
        avg_cost = holding.avg_price_usd
        cost_basis_inr = _inr_from_usd(avg_cost * quantity, rate)
        realized_pnl_inr = order_inr - cost_basis_inr
        trade = CommodityTrade.objects.create(
            user=user,
            commodity_id=commodity_id,
            side=side,
            quantity=quantity,
            price_usd=price,
            amount_inr=order_inr,
            usd_inr_rate=rate,
            avg_cost_usd=avg_cost,
            realized_pnl_inr=realized_pnl_inr,
        )
        holding.quantity -= quantity
        if holding.quantity == 0:
            holding.delete()
            holding = None
        else:
            holding.save(update_fields=['quantity'])
        wallet.balance += order_inr
        wallet.save(update_fields=['balance'])
        WalletTransaction.objects.create(
            wallet=wallet,
            type=WalletTransaction.TxType.DEPOSIT,
            amount=order_inr,
            status=WalletTransaction.Status.COMPLETED,
        )
    else:
        if wallet.balance < order_inr:
            raise CommodityTradingError(
                f'Insufficient wallet balance. Need ₹{order_inr:,.2f}, have ₹{wallet.balance:,.2f}.'
            )
        trade = CommodityTrade.objects.create(
            user=user,
            commodity_id=commodity_id,
            side=side,
            quantity=quantity,
            price_usd=price,
            amount_inr=order_inr,
            usd_inr_rate=rate,
        )
        if holding:
            total_cost = holding.quantity * holding.avg_price_usd + Decimal(quantity) * price
            holding.quantity += quantity
            holding.avg_price_usd = total_cost / holding.quantity
            holding.save()
        else:
            holding = CommodityHolding.objects.create(
                user=user,
                commodity_id=commodity_id,
                quantity=quantity,
                avg_price_usd=price,
            )
        wallet.balance -= order_inr
        wallet.save(update_fields=['balance'])
        WalletTransaction.objects.create(
            wallet=wallet,
            type=WalletTransaction.TxType.WITHDRAWAL,
            amount=order_inr,
            status=WalletTransaction.Status.COMPLETED,
        )
        Transaction.objects.create(
            user=user,
            reference_id=f'CMD-{trade.id}',
            type=Transaction.TxType.INVESTMENT,
            status=Transaction.Status.COMPLETED,
            amount=order_inr,
            description=f'Commodity purchase: {quote["name"]} × {quantity}',
        )

    return build_trade_payload(trade, quote, holding)


def list_recent_commodity_trades(user, limit: int = 30) -> list[dict]:
    trades = CommodityTrade.objects.filter(user=user).order_by('-created_at')[:limit]
    rows = []
    for trade in trades:
        quote = get_commodity_detail(trade.commodity_id) or {'ltp': trade.price_usd}
        holding = CommodityHolding.objects.filter(user=user, commodity_id=trade.commodity_id).first()
        rows.append(build_trade_payload(trade, quote, holding))
    return rows
