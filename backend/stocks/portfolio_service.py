from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

from .market_data_service import refresh_stocks
from .models import StockHolding
from .trading_service import list_recent_trades


def _active_holdings(user):
    return (
        StockHolding.objects.filter(user=user, quantity__gt=0)
        .select_related('stock')
        .order_by('-quantity')
    )


def _holding_row(holding: StockHolding) -> dict[str, Any]:
    stock = holding.stock
    qty = holding.quantity
    avg = float(holding.avg_price)
    ltp = float(stock.ltp)
    change = float(stock.change)
    change_pct = float(stock.change_percent)
    invested = qty * avg
    current = qty * ltp
    pnl = current - invested
    day_pnl = qty * change
    return {
        'symbol': stock.symbol,
        'name': stock.name,
        'sector': stock.sector,
        'exchange': stock.exchange,
        'quantity': qty,
        'avg_price': round(avg, 2),
        'ltp': round(ltp, 2),
        'change': round(change, 2),
        'change_percent': round(change_pct, 2),
        'invested': round(invested, 2),
        'current_value': round(current, 2),
        'pnl': round(pnl, 2),
        'pnl_percent': round((pnl / invested * 100) if invested else 0, 2),
        'day_pnl': round(day_pnl, 2),
    }


def get_stock_portfolio(user, refresh: bool = False) -> dict[str, Any]:
    holdings = list(_active_holdings(user))
    if refresh and holdings:
        symbols = [h.stock.symbol for h in holdings]
        try:
            refresh_stocks(symbols)
            holdings = list(_active_holdings(user))
        except Exception:
            # Never block portfolio on live quote refresh failures/timeouts.
            pass

    rows = [_holding_row(h) for h in holdings]
    rows.sort(key=lambda row: row['current_value'], reverse=True)

    total_invested = sum(row['invested'] for row in rows)
    total_value = sum(row['current_value'] for row in rows)
    total_pnl = total_value - total_invested
    day_pnl = sum(row['day_pnl'] for row in rows)
    prev_value = total_value - day_pnl

    sectors: dict[str, float] = {}
    for row in rows:
        sectors[row['sector']] = sectors.get(row['sector'], 0) + row['current_value']

    sector_colors = [0xFF1B3A6B, 0xFF10B981, 0xFF2E5090, 0xFFF59E0B, 0xFF6366F1, 0xFFEC4899]
    sector_allocation = [
        {
            'label': sector,
            'value': round(value, 2),
            'percentage': round(value / total_value * 100, 1) if total_value else 0,
            'color_value': sector_colors[idx % len(sector_colors)],
        }
        for idx, (sector, value) in enumerate(
            sorted(sectors.items(), key=lambda item: item[1], reverse=True)
        )
    ]

    summary = {
        'total_invested': round(total_invested, 2),
        'current_value': round(total_value, 2),
        'total_pnl': round(total_pnl, 2),
        'total_pnl_percent': round((total_pnl / total_invested * 100) if total_invested else 0, 2),
        'day_pnl': round(day_pnl, 2),
        'day_pnl_percent': round((day_pnl / prev_value * 100) if prev_value else 0, 2),
        'holdings_count': len(rows),
    }

    try:
        recent_trades = list_recent_trades(user, limit=8)
    except Exception:
        recent_trades = []

    return {
        'summary': summary,
        'holdings': rows,
        'sector_allocation': sector_allocation,
        'updated_at': datetime.now(timezone.utc).isoformat(),
        'recent_trades': recent_trades,
    }


def get_stock_summary(user, refresh: bool = False) -> dict[str, Any]:
    """Lightweight totals for F&O / wallet checks — skips trade history."""
    holdings = list(_active_holdings(user))
    if refresh and holdings:
        symbols = [h.stock.symbol for h in holdings]
        try:
            refresh_stocks(symbols)
            holdings = list(_active_holdings(user))
        except Exception:
            pass

    rows = [_holding_row(h) for h in holdings]
    total_invested = sum(row['invested'] for row in rows)
    total_value = sum(row['current_value'] for row in rows)
    total_pnl = total_value - total_invested
    day_pnl = sum(row['day_pnl'] for row in rows)
    prev_value = total_value - day_pnl
    return {
        'total_invested': round(total_invested, 2),
        'current_value': round(total_value, 2),
        'total_pnl': round(total_pnl, 2),
        'total_pnl_percent': round((total_pnl / total_invested * 100) if total_invested else 0, 2),
        'day_pnl': round(day_pnl, 2),
        'day_pnl_percent': round((day_pnl / prev_value * 100) if prev_value else 0, 2),
        'holdings_count': len(rows),
    }
