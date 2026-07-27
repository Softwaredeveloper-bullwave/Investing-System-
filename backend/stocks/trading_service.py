"""Paper trading — order placement with P&L tracking."""

from __future__ import annotations

from decimal import Decimal

from django.db import transaction

from .finnhub_client import FinnhubError
from .market_data_service import refresh_stock
from .models import PaperTrade, PaperWallet, Stock, StockHolding


class TradingError(Exception):
    pass


def _round2(value) -> float:
    return round(float(value), 2)


def build_trade_payload(
    trade: PaperTrade,
    stock: Stock,
    holding: StockHolding | None = None,
    paper_wallet: PaperWallet | None = None,
) -> dict:
    order_value = float(trade.quantity * trade.price)
    payload = {
        'id': str(trade.id),
        'symbol': stock.symbol,
        'stockName': stock.name,
        'side': trade.side,
        'quantity': trade.quantity,
        'price': _round2(trade.price),
        'time': trade.created_at.isoformat(),
        'status': trade.status,
        'orderValue': _round2(order_value),
        'ltp': _round2(stock.ltp),
    }
    if trade.avg_cost is not None:
        payload['avgCost'] = _round2(trade.avg_cost)
    if trade.realized_pnl is not None:
        cost_basis = float(trade.avg_cost or 0) * trade.quantity
        payload['realizedPnl'] = _round2(trade.realized_pnl)
        payload['realizedPnlPercent'] = _round2(
            (float(trade.realized_pnl) / cost_basis * 100) if cost_basis else 0
        )
    if holding and holding.quantity > 0:
        payload['holdingQty'] = holding.quantity
        payload['holdingAvgPrice'] = _round2(holding.avg_price)
        current = float(holding.quantity * stock.ltp)
        invested = float(holding.quantity * holding.avg_price)
        payload['unrealizedPnl'] = _round2(current - invested)
    if paper_wallet is not None:
        payload['virtualBalance'] = _round2(paper_wallet.balance)
        payload['virtualStartingBalance'] = _round2(paper_wallet.starting_balance)
    return payload


def _write_ledger(user, paper_wallet, *, entry_type, amount, description, order=None):
    """Best-effort ledger row — never blocks a fill if this fails for some
    reason (e.g. mid-migration), the wallet balance itself is the source of
    truth for trading; the ledger is the human-readable audit trail on top."""
    from .models import PaperLedgerEntry

    try:
        PaperLedgerEntry.objects.create(
            user=user,
            entry_type=entry_type,
            amount=amount,
            balance_after=paper_wallet.balance,
            description=description,
            order=order,
        )
    except Exception:
        pass


@transaction.atomic
def apply_fill(
    user,
    stock: Stock,
    side: str,
    quantity: int,
    price,
    *,
    charges=Decimal('0'),
    order=None,
) -> tuple[PaperTrade, StockHolding | None, PaperWallet]:
    """Single source of truth for turning a fill (market execution, or a
    matched limit/stop order) into a `PaperTrade` + updated `StockHolding` +
    updated `PaperWallet` + `PaperLedgerEntry` rows.

    Used by both `place_paper_order` (legacy market-only endpoint) and
    `paper_order_service` (market/limit/SL-M/SL order book), so avg-cost and
    realized-P&L accounting only exists in one place.
    """
    side = side.upper().strip()
    quantity = int(quantity)
    price = Decimal(price)
    charges = Decimal(charges)

    holding = StockHolding.objects.filter(user=user, stock=stock).first()
    paper_wallet = PaperWallet.objects.select_for_update().get_or_create(
        user=user,
        defaults={
            'balance': PaperWallet.DEFAULT_STARTING_BALANCE,
            'starting_balance': PaperWallet.DEFAULT_STARTING_BALANCE,
        },
    )[0]
    order_value = Decimal(quantity) * price

    if side == 'SELL':
        if not holding or holding.quantity < quantity:
            available = holding.quantity if holding else 0
            raise TradingError(f'Insufficient shares. You hold {available} {stock.symbol}.')
        avg_cost = holding.avg_price
        realized_pnl = (price - avg_cost) * Decimal(quantity) - charges
        trade = PaperTrade.objects.create(
            user=user,
            stock=stock,
            side=side,
            quantity=quantity,
            price=price,
            avg_cost=avg_cost,
            realized_pnl=realized_pnl,
        )
        holding.quantity -= quantity
        if holding.quantity == 0:
            holding.delete()
            holding = None
        else:
            holding.save(update_fields=['quantity'])
        # Sale proceeds return to the learner's virtual buying power, net of charges.
        paper_wallet.balance += order_value - charges
        paper_wallet.save(update_fields=['balance', 'updated_at'])
        _write_ledger(
            user, paper_wallet, entry_type='SELL', amount=order_value,
            description=f'Sell {quantity} {stock.symbol} @ {price}', order=order,
        )
    else:
        total_debit = order_value + charges
        if total_debit > paper_wallet.balance:
            raise TradingError(
                f'Insufficient virtual balance. This order needs '
                f'₹{total_debit:,.2f} (incl. ₹{charges:,.2f} charges) but you only have '
                f'₹{paper_wallet.balance:,.2f} of practice capital. Sell a position or '
                f'reset your paper portfolio.'
            )
        trade = PaperTrade.objects.create(
            user=user,
            stock=stock,
            side=side,
            quantity=quantity,
            price=price,
        )
        if holding:
            total_cost = holding.quantity * holding.avg_price + Decimal(quantity) * price
            holding.quantity += quantity
            holding.avg_price = total_cost / holding.quantity
            holding.save()
        else:
            holding = StockHolding.objects.create(
                user=user,
                stock=stock,
                quantity=quantity,
                avg_price=price,
            )
        paper_wallet.balance -= total_debit
        paper_wallet.save(update_fields=['balance', 'updated_at'])
        _write_ledger(
            user, paper_wallet, entry_type='BUY', amount=-order_value,
            description=f'Buy {quantity} {stock.symbol} @ {price}', order=order,
        )

    if charges > 0:
        _write_ledger(
            user, paper_wallet, entry_type='CHARGE', amount=-charges,
            description=f'Estimated charges — {stock.symbol} {side}', order=order,
        )

    try:
        from .paper_competition_service import refresh_user_competitions

        refresh_user_competitions(user)
    except Exception:
        pass

    return trade, holding, paper_wallet


@transaction.atomic
def place_paper_order(user, *, symbol: str, side: str, quantity: int) -> dict:
    symbol = symbol.upper().strip()
    side = side.upper().strip()
    if side not in ('BUY', 'SELL'):
        raise TradingError('Invalid order side.')
    if quantity < 1:
        raise TradingError('Quantity must be at least 1.')

    stock = Stock.objects.filter(symbol=symbol).first()
    if not stock:
        try:
            stock = refresh_stock(symbol)
        except FinnhubError as exc:
            raise TradingError(str(exc)) from exc

    price = stock.ltp
    if price <= 0:
        raise TradingError('Live price unavailable for this stock. Try again shortly.')

    trade, holding, paper_wallet = apply_fill(user, stock, side, quantity, price)
    return build_trade_payload(trade, stock, holding, paper_wallet)


def get_or_create_paper_wallet(user) -> PaperWallet:
    return PaperWallet.get_or_create_for(user)


@transaction.atomic
def reset_paper_portfolio(user) -> dict:
    """Wipe all paper positions/orders and restore the starting virtual balance.

    Equity paper trading is the only writer of StockHolding/PaperTrade/
    PaperOrder/PaperLedgerEntry/PaperEquitySnapshot, so this is a safe full
    reset for the learner — nothing real-money-related lives in any of them.
    Journal entries are deliberately kept — they're personal reflection, not
    trading state, and stay useful across a reset.
    """
    from .models import (
        PaperCommodityHolding,
        PaperCommodityOrder,
        PaperEquitySnapshot,
        PaperLedgerEntry,
        PaperOptionHolding,
        PaperOptionOrder,
        PaperOrder,
    )

    StockHolding.objects.filter(user=user).delete()
    PaperTrade.objects.filter(user=user).delete()
    PaperOrder.objects.filter(user=user).delete()
    PaperOptionHolding.objects.filter(user=user).delete()
    PaperOptionOrder.objects.filter(user=user).delete()
    PaperCommodityHolding.objects.filter(user=user).delete()
    PaperCommodityOrder.objects.filter(user=user).delete()
    PaperLedgerEntry.objects.filter(user=user).delete()
    PaperEquitySnapshot.objects.filter(user=user).delete()
    paper_wallet = PaperWallet.objects.select_for_update().get_or_create(
        user=user,
        defaults={
            'balance': PaperWallet.DEFAULT_STARTING_BALANCE,
            'starting_balance': PaperWallet.DEFAULT_STARTING_BALANCE,
        },
    )[0]
    paper_wallet.balance = paper_wallet.starting_balance
    paper_wallet.save(update_fields=['balance', 'updated_at'])
    _write_ledger(
        user, paper_wallet, entry_type='RESET', amount=paper_wallet.starting_balance,
        description='Paper portfolio reset — starting virtual capital restored.',
    )
    return {
        'virtualBalance': _round2(paper_wallet.balance),
        'virtualStartingBalance': _round2(paper_wallet.starting_balance),
    }


def list_recent_trades(user, limit: int = 20) -> list[dict]:
    trades = (
        PaperTrade.objects.filter(user=user)
        .select_related('stock')
        .order_by('-created_at')[:limit]
    )
    rows = []
    for trade in trades:
        holding = StockHolding.objects.filter(user=user, stock=trade.stock).first()
        rows.append(build_trade_payload(trade, trade.stock, holding))
    return rows
