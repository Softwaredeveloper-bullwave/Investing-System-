"""Paper F&O / commodity-option trading — mirrors `option_trading_service.py`
exactly (same contract validation, lot sizing, avg-premium/realized-P&L
math) but settles against `PaperWallet` instead of `finance.Wallet`, and
never touches the real broker or `finance.Transaction` ledger.

Pricing is client-supplied (the `premium` the learner sees on the option
chain screen at the moment of placing the order) — identical to how the
real `place_option_order` works, since this app's option chain already
streams live premiums from `options_service.py` and there's no separate
"quote at fill time" step for options today.
"""

from __future__ import annotations

from datetime import date
from decimal import Decimal, ROUND_HALF_UP

from django.db import transaction

from .commodity_service import COMMODITY_CATALOG
from .commodity_trading_service import get_usd_inr_rate
from .models import PaperOptionHolding, PaperOptionOrder, PaperWallet
from .option_trading_service import LOT_SIZES
from .trading_service import _write_ledger

DEFAULT_OPTION_CHARGE_RATE = Decimal('0.0006')  # flat estimated brokerage+tax simulation for options


class PaperOptionTradingError(Exception):
    pass


def _round2(value) -> float:
    return round(float(value), 2)


def _lot_size(underlying: str, asset_class: str) -> int:
    if asset_class == PaperOptionHolding.AssetClass.COMMODITY:
        return 1
    return LOT_SIZES.get(underlying.upper(), 1)


def _inr_from_usd(usd_amount: Decimal, rate: Decimal) -> Decimal:
    return (usd_amount * rate).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


def _order_amount_inr(*, premium: Decimal, quantity: int, lot_size: int, asset_class: str, rate: Decimal) -> Decimal:
    total = premium * quantity * lot_size
    if asset_class == PaperOptionHolding.AssetClass.COMMODITY:
        return _inr_from_usd(total, rate)
    return total.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


def _contract_label(underlying: str, strike, option_type: str, expiry: date) -> str:
    return f'{underlying.upper()} {float(strike):g} {option_type} {expiry.isoformat()}'


def _holding_key(user, *, underlying, strike, option_type, expiry, asset_class):
    return PaperOptionHolding.objects.filter(
        user=user,
        underlying=underlying.upper(),
        strike=strike,
        option_type=option_type.upper(),
        expiry=expiry,
        asset_class=asset_class,
    ).first()


def build_option_order_payload(order: PaperOptionOrder, holding: PaperOptionHolding | None = None) -> dict:
    label = _contract_label(order.underlying, order.strike, order.option_type, order.expiry)
    payload = {
        'id': str(order.id),
        'underlying': order.underlying,
        'assetClass': order.asset_class,
        'strike': _round2(order.strike),
        'optionType': order.option_type,
        'expiry': order.expiry.isoformat(),
        'contractLabel': label,
        'side': order.side,
        'quantity': order.quantity,
        'premium': _round2(order.premium),
        'lotSize': order.lot_size,
        'amountInr': _round2(order.amount_inr),
        'charges': _round2(order.charges),
        'time': order.created_at.isoformat(),
        'status': order.status,
        'rejectReason': order.reject_reason,
        'orderValueInr': _round2(order.amount_inr),
    }
    if order.avg_premium is not None:
        payload['avgPremium'] = _round2(order.avg_premium)
    if order.realized_pnl_inr is not None:
        payload['realizedPnlInr'] = _round2(order.realized_pnl_inr)
    if holding and holding.quantity > 0:
        payload['holdingQty'] = holding.quantity
        payload['holdingAvgPremium'] = _round2(holding.avg_premium)
    return payload


def _holding_payload(holding: PaperOptionHolding) -> dict:
    label = _contract_label(holding.underlying, holding.strike, holding.option_type, holding.expiry)
    payload = {
        'underlying': holding.underlying,
        'assetClass': holding.asset_class,
        'strike': _round2(holding.strike),
        'optionType': holding.option_type,
        'expiry': holding.expiry.isoformat(),
        'contractLabel': label,
        'quantity': holding.quantity,
        'avgPremium': _round2(holding.avg_premium),
        'lotSize': holding.lot_size,
    }
    try:
        from .options_service import estimate_option_premium

        ltp = estimate_option_premium(
            holding.underlying, holding.strike, holding.option_type, holding.expiry,
            asset_class=holding.asset_class,
        )
        if ltp is not None:
            rate = Decimal('1')
            if holding.asset_class == PaperOptionHolding.AssetClass.COMMODITY:
                rate = get_usd_inr_rate()
            invested_inr = _order_amount_inr(
                premium=holding.avg_premium, quantity=holding.quantity, lot_size=holding.lot_size,
                asset_class=holding.asset_class, rate=rate,
            )
            current_inr = _order_amount_inr(
                premium=Decimal(str(ltp)), quantity=holding.quantity, lot_size=holding.lot_size,
                asset_class=holding.asset_class, rate=rate,
            )
            payload['ltpPremium'] = _round2(ltp)
            payload['currentValueInr'] = _round2(current_inr)
            payload['unrealizedPnlInr'] = _round2(current_inr - invested_inr)
    except Exception:
        pass
    return payload


def list_paper_option_holdings(user, *, asset_class: str | None = None) -> list[dict]:
    qs = PaperOptionHolding.objects.filter(user=user)
    if asset_class:
        qs = qs.filter(asset_class=asset_class)
    return [_holding_payload(h) for h in qs]


def list_paper_option_orders(user, limit: int = 50) -> list[dict]:
    orders = PaperOptionOrder.objects.filter(user=user).order_by('-created_at')[:limit]
    rows = []
    for order in orders:
        holding = _holding_key(
            user, underlying=order.underlying, strike=order.strike,
            option_type=order.option_type, expiry=order.expiry, asset_class=order.asset_class,
        )
        rows.append(build_option_order_payload(order, holding))
    return rows


@transaction.atomic
def place_paper_option_order(
    user,
    *,
    underlying: str,
    strike,
    option_type: str,
    expiry,
    side: str,
    quantity: int,
    premium,
    asset_class: str = PaperOptionHolding.AssetClass.EQUITY_FNO,
) -> dict:
    underlying = underlying.upper().strip()
    option_type = option_type.upper().strip()
    side = side.upper().strip()
    asset_class = (asset_class or PaperOptionHolding.AssetClass.EQUITY_FNO).strip().lower()

    if side not in ('BUY', 'SELL'):
        raise PaperOptionTradingError('Invalid order side.')
    if option_type not in ('CE', 'PE'):
        raise PaperOptionTradingError('Invalid option type.')
    if quantity < 1:
        raise PaperOptionTradingError('Quantity must be at least 1 lot.')

    if asset_class == PaperOptionHolding.AssetClass.COMMODITY:
        if underlying not in COMMODITY_CATALOG:
            raise PaperOptionTradingError('Commodity not found.')
    elif asset_class != PaperOptionHolding.AssetClass.EQUITY_FNO:
        raise PaperOptionTradingError('Invalid asset class.')

    if isinstance(expiry, str):
        expiry = date.fromisoformat(expiry[:10])

    premium = Decimal(str(premium))
    if premium <= 0:
        raise PaperOptionTradingError('Invalid option premium.')

    strike = Decimal(str(strike))
    lot_size = _lot_size(underlying, asset_class)
    rate = get_usd_inr_rate() if asset_class == PaperOptionHolding.AssetClass.COMMODITY else Decimal('1')
    order_inr = _order_amount_inr(
        premium=premium, quantity=quantity, lot_size=lot_size, asset_class=asset_class, rate=rate,
    )
    charges = (order_inr * DEFAULT_OPTION_CHARGE_RATE).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

    holding = _holding_key(
        user, underlying=underlying, strike=strike, option_type=option_type, expiry=expiry, asset_class=asset_class,
    )
    paper_wallet = PaperWallet.objects.select_for_update().get_or_create(
        user=user, defaults={
            'balance': PaperWallet.DEFAULT_STARTING_BALANCE,
            'starting_balance': PaperWallet.DEFAULT_STARTING_BALANCE,
        },
    )[0]
    label = _contract_label(underlying, strike, option_type, expiry)

    if side == 'SELL':
        if not holding or holding.quantity < quantity:
            available = holding.quantity if holding else 0
            order = PaperOptionOrder.objects.create(
                user=user, underlying=underlying, asset_class=asset_class, strike=strike,
                option_type=option_type, expiry=expiry, side=side, quantity=quantity,
                premium=premium, lot_size=lot_size, amount_inr=Decimal('0'),
                status=PaperOptionOrder.Status.REJECTED,
                reject_reason=f'Insufficient lots. You hold {available}.',
            )
            raise PaperOptionTradingError(order.reject_reason)

        avg_cost = holding.avg_premium
        buy_inr = _order_amount_inr(
            premium=avg_cost, quantity=quantity, lot_size=lot_size, asset_class=asset_class, rate=rate,
        )
        realized_pnl_inr = order_inr - buy_inr - charges
        order = PaperOptionOrder.objects.create(
            user=user, underlying=underlying, asset_class=asset_class, strike=strike,
            option_type=option_type, expiry=expiry, side=side, quantity=quantity,
            premium=premium, lot_size=lot_size, amount_inr=order_inr, avg_premium=avg_cost,
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
            description=f'Sell option {label} × {quantity} lot(s)',
        )
    else:
        total_debit = order_inr + charges
        if total_debit > paper_wallet.balance:
            order = PaperOptionOrder.objects.create(
                user=user, underlying=underlying, asset_class=asset_class, strike=strike,
                option_type=option_type, expiry=expiry, side=side, quantity=quantity,
                premium=premium, lot_size=lot_size, amount_inr=order_inr, charges=charges,
                status=PaperOptionOrder.Status.REJECTED,
                reject_reason=(
                    f'Insufficient virtual balance. Need ₹{total_debit:,.2f}, have '
                    f'₹{paper_wallet.balance:,.2f} of practice capital.'
                ),
            )
            raise PaperOptionTradingError(order.reject_reason)

        order = PaperOptionOrder.objects.create(
            user=user, underlying=underlying, asset_class=asset_class, strike=strike,
            option_type=option_type, expiry=expiry, side=side, quantity=quantity,
            premium=premium, lot_size=lot_size, amount_inr=order_inr, charges=charges,
        )
        if holding:
            total_cost = holding.quantity * holding.avg_premium + Decimal(quantity) * premium
            holding.quantity += quantity
            holding.avg_premium = total_cost / holding.quantity
            holding.save()
        else:
            holding = PaperOptionHolding.objects.create(
                user=user, underlying=underlying, asset_class=asset_class, strike=strike,
                option_type=option_type, expiry=expiry, quantity=quantity,
                avg_premium=premium, lot_size=lot_size,
            )

        paper_wallet.balance -= total_debit
        paper_wallet.save(update_fields=['balance'])
        _write_ledger(
            user, paper_wallet, entry_type='BUY', amount=-total_debit,
            description=f'Buy option {label} × {quantity} lot(s)',
        )

    return build_option_order_payload(order, holding)


@transaction.atomic
def exit_paper_option_position(user, *, underlying, strike, option_type, expiry, premium, asset_class=PaperOptionHolding.AssetClass.EQUITY_FNO) -> dict:
    """Sell an entire held option position at the given (current) premium."""
    if isinstance(expiry, str):
        expiry = date.fromisoformat(expiry[:10])
    holding = _holding_key(
        user, underlying=underlying.upper().strip(), strike=Decimal(str(strike)),
        option_type=option_type.upper().strip(), expiry=expiry,
        asset_class=(asset_class or PaperOptionHolding.AssetClass.EQUITY_FNO).strip().lower(),
    )
    if not holding:
        raise PaperOptionTradingError('No open position for this contract.')
    return place_paper_option_order(
        user, underlying=holding.underlying, strike=holding.strike, option_type=holding.option_type,
        expiry=holding.expiry, side='SELL', quantity=holding.quantity, premium=premium,
        asset_class=holding.asset_class,
    )
