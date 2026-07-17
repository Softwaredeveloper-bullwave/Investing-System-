"""IPO apply (subscribe) and sell with wallet settlement."""

from decimal import Decimal, ROUND_HALF_UP

from django.db import transaction

from finance.models import Transaction, Wallet, WalletTransaction

from .ipo_service import _effective_status, listing_price_val
from .models import IpoEvent, IpoHolding, IpoTrade


class IpoTradingError(Exception):
    pass


def _round2(value) -> float:
    return round(float(value), 2)


def listing_price(ipo: IpoEvent) -> Decimal:
    return listing_price_val(ipo)


def _holding_payload(holding: IpoHolding, ipo: IpoEvent, today) -> dict:
    status = _effective_status(ipo, today)
    ltp = listing_price(ipo) if status == IpoEvent.Status.LISTED else holding.avg_price
    invested = holding.quantity * holding.avg_price
    current = holding.quantity * ltp
    pnl = current - invested
    return {
        'ipoId': ipo.id,
        'companyName': ipo.company_name,
        'symbol': ipo.symbol,
        'sector': ipo.sector,
        'ipoStatus': status,
        'lots': holding.lots,
        'quantity': holding.quantity,
        'avgPrice': _round2(holding.avg_price),
        'ltp': _round2(ltp),
        'investedInr': _round2(invested),
        'currentValueInr': _round2(current),
        'pnlInr': _round2(pnl),
        'pnlPercent': _round2((float(pnl) / float(invested) * 100) if invested else 0),
        'canSell': status == IpoEvent.Status.LISTED,
    }


def list_ipo_holdings(user) -> list[dict]:
    from django.utils import timezone

    today = timezone.localdate()
    rows = []
    for holding in IpoHolding.objects.filter(user=user).select_related('ipo'):
        rows.append(_holding_payload(holding, holding.ipo, today))
    return rows


def build_trade_payload(trade: IpoTrade) -> dict:
    ipo = trade.ipo
    return {
        'id': str(trade.id),
        'ipoId': ipo.id,
        'companyName': ipo.company_name,
        'symbol': ipo.symbol,
        'side': trade.side,
        'lots': trade.lots,
        'quantity': trade.quantity,
        'price': _round2(trade.price),
        'amountInr': _round2(trade.amount_inr),
        'time': trade.created_at.isoformat(),
        'status': trade.status,
    }


def list_ipo_trades(user, limit: int = 30) -> list[dict]:
    trades = (
        IpoTrade.objects.filter(user=user)
        .select_related('ipo')
        .order_by('-created_at')[:limit]
    )
    return [build_trade_payload(t) for t in trades]


@transaction.atomic
def place_ipo_order(user, *, ipo_id: str, side: str, lots: int) -> dict:
    from django.utils import timezone

    side = side.upper().strip()
    if side not in ('APPLY', 'SELL', 'BUY'):
        raise IpoTradingError('Invalid order side. Use APPLY or SELL.')
    if lots < 1:
        raise IpoTradingError('Lots must be at least 1.')

    if side == 'BUY':
        side = IpoTrade.Side.APPLY

    try:
        ipo = IpoEvent.objects.get(pk=ipo_id)
    except IpoEvent.DoesNotExist:
        raise IpoTradingError('IPO not found.') from None

    today = timezone.localdate()
    effective = _effective_status(ipo, today)
    quantity = lots * ipo.lot_size
    wallet = Wallet.objects.select_for_update().get_or_create(user=user)[0]

    if side == IpoTrade.Side.APPLY:
        if effective != IpoEvent.Status.OPEN:
            raise IpoTradingError('IPO subscription is only open during the bidding window.')
        price = ipo.price_band_max
        amount = (Decimal(quantity) * price).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
        if wallet.balance < amount:
            raise IpoTradingError(
                f'Insufficient wallet balance. Need ₹{amount:,.2f}, have ₹{wallet.balance:,.2f}.'
            )
        trade = IpoTrade.objects.create(
            user=user,
            ipo=ipo,
            side=IpoTrade.Side.APPLY,
            lots=lots,
            quantity=quantity,
            price=price,
            amount_inr=amount,
        )
        holding = IpoHolding.objects.filter(user=user, ipo=ipo).first()
        if holding:
            total_cost = holding.quantity * holding.avg_price + amount
            holding.quantity += quantity
            holding.lots += lots
            holding.avg_price = total_cost / holding.quantity
            holding.save()
        else:
            holding = IpoHolding.objects.create(
                user=user,
                ipo=ipo,
                lots=lots,
                quantity=quantity,
                avg_price=price,
            )
        wallet.balance -= amount
        wallet.save(update_fields=['balance'])
        WalletTransaction.objects.create(
            wallet=wallet,
            type=WalletTransaction.TxType.WITHDRAWAL,
            amount=amount,
            status=WalletTransaction.Status.COMPLETED,
        )
        Transaction.objects.create(
            user=user,
            reference_id=f'IPO-{trade.id}',
            type=Transaction.TxType.INVESTMENT,
            status=Transaction.Status.COMPLETED,
            amount=amount,
            description=f'IPO application: {ipo.company_name} × {lots} lot(s)',
        )
    else:
        if effective != IpoEvent.Status.LISTED:
            raise IpoTradingError('You can sell only after the IPO is listed.')
        holding = IpoHolding.objects.filter(user=user, ipo=ipo).first()
        if not holding or holding.lots < lots:
            available = holding.lots if holding else 0
            raise IpoTradingError(f'Insufficient lots. You hold {available} lot(s).')
        price = listing_price(ipo)
        sell_qty = lots * ipo.lot_size
        amount = (Decimal(sell_qty) * price).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
        cost_basis = holding.avg_price * sell_qty
        trade = IpoTrade.objects.create(
            user=user,
            ipo=ipo,
            side=IpoTrade.Side.SELL,
            lots=lots,
            quantity=sell_qty,
            price=price,
            amount_inr=amount,
        )
        holding.lots -= lots
        holding.quantity -= sell_qty
        if holding.lots <= 0:
            holding.delete()
        else:
            holding.save()
        wallet.balance += amount
        wallet.save(update_fields=['balance'])
        WalletTransaction.objects.create(
            wallet=wallet,
            type=WalletTransaction.TxType.DEPOSIT,
            amount=amount,
            status=WalletTransaction.Status.COMPLETED,
        )
        Transaction.objects.create(
            user=user,
            reference_id=f'IPO-{trade.id}',
            type=Transaction.TxType.PROFIT,
            status=Transaction.Status.COMPLETED,
            amount=amount,
            description=f'IPO sell: {ipo.company_name} × {lots} lot(s)',
        )

    payload = build_trade_payload(trade)
    if side == IpoTrade.Side.APPLY:
        holding = IpoHolding.objects.filter(user=user, ipo=ipo).first()
        if holding:
            payload['holding'] = _holding_payload(holding, ipo, today)
    return payload
