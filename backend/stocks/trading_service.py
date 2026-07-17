"""Paper trading — order placement with P&L tracking."""

from __future__ import annotations

from decimal import Decimal

from django.db import transaction

from .finnhub_client import FinnhubError
from .market_data_service import refresh_stock
from .models import PaperTrade, Stock, StockHolding


class TradingError(Exception):
    pass


def _round2(value) -> float:
    return round(float(value), 2)


def build_trade_payload(trade: PaperTrade, stock: Stock, holding: StockHolding | None = None) -> dict:
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
    return payload


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

    holding = StockHolding.objects.filter(user=user, stock=stock).first()

    if side == 'SELL':
        if not holding or holding.quantity < quantity:
            available = holding.quantity if holding else 0
            raise TradingError(f'Insufficient shares. You hold {available} {symbol}.')
        avg_cost = holding.avg_price
        realized_pnl = (price - avg_cost) * Decimal(quantity)
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
    else:
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

    try:
        from .paper_competition_service import refresh_user_competitions

        refresh_user_competitions(user)
    except Exception:
        pass

    return build_trade_payload(trade, stock, holding)


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
