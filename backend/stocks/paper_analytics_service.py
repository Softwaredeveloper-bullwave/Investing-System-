"""Paper-trading performance analytics — win rate, profit factor, drawdown,
and the equity curve behind it.

`record_daily_snapshot()` is called opportunistically from the analytics
endpoint (and available to the `--paper-orders` cron flag) to build up
`PaperEquitySnapshot` history day by day. Until enough real history exists,
`get_equity_curve()` falls back to reconstructing an approximate curve from
`PaperTrade` history so the chart is never just empty on day one.
"""

from __future__ import annotations

from datetime import date, timedelta
from decimal import Decimal

from django.utils import timezone

from .models import (
    PaperCommodityHolding,
    PaperCommodityOrder,
    PaperEquitySnapshot,
    PaperOptionHolding,
    PaperOptionOrder,
    PaperTrade,
    StockHolding,
)
from .trading_service import get_or_create_paper_wallet


def _round2(value) -> float:
    return round(float(value), 2)


def _option_holdings_value(user) -> Decimal:
    # Marks each open option position at a live estimated premium (same
    # intrinsic + time-value formula the option chain itself uses), not
    # stale cost basis — so unrealized option P&L is real, matching what
    # the chain UI would quote if the learner tried to exit right now.
    # Realized P&L (win rate, profit factor, etc.) is unaffected either way
    # since that's booked exactly at sell time.
    from .options_service import estimate_option_premium

    total = Decimal('0')
    for h in PaperOptionHolding.objects.filter(user=user, quantity__gt=0):
        premium = estimate_option_premium(
            h.underlying, h.strike, h.option_type, h.expiry, asset_class=h.asset_class,
        )
        mark = Decimal(str(premium)) if premium is not None else Decimal(h.avg_premium)
        total += Decimal(h.quantity) * Decimal(h.lot_size) * mark
    return total


def _commodity_holdings_value(user) -> Decimal:
    from .commodity_service import get_commodity_detail
    from .commodity_trading_service import get_usd_inr_rate

    total = Decimal('0')
    rate = None
    for h in PaperCommodityHolding.objects.filter(user=user, quantity__gt=0):
        quote = get_commodity_detail(h.commodity_id)
        if not quote:
            continue
        if rate is None:
            rate = get_usd_inr_rate()
        total += Decimal(h.quantity) * Decimal(str(quote['ltp'])) * rate
    return total


def _current_holdings_value(user) -> Decimal:
    total = Decimal('0')
    for h in StockHolding.objects.filter(user=user, quantity__gt=0).select_related('stock'):
        total += Decimal(h.quantity) * Decimal(h.stock.ltp)
    total += _option_holdings_value(user)
    total += _commodity_holdings_value(user)
    return total


def record_daily_snapshot(user, on_date: date | None = None) -> PaperEquitySnapshot:
    on_date = on_date or timezone.localdate()
    wallet = get_or_create_paper_wallet(user)
    holdings_value = _current_holdings_value(user)
    equity = wallet.balance + holdings_value
    snapshot, _created = PaperEquitySnapshot.objects.update_or_create(
        user=user, date=on_date,
        defaults={
            'balance': wallet.balance,
            'holdings_value': holdings_value,
            'equity': equity,
        },
    )
    return snapshot


def get_equity_curve(user, days: int = 180) -> list[dict]:
    record_daily_snapshot(user)  # make sure today's point exists
    since = timezone.localdate() - timedelta(days=days)
    snapshots = list(
        PaperEquitySnapshot.objects.filter(user=user, date__gte=since).order_by('date')
    )
    if len(snapshots) >= 2:
        return [{'date': s.date.isoformat(), 'equity': _round2(s.equity)} for s in snapshots]

    # Fallback reconstruction for accounts with little/no snapshot history yet:
    # walk realized P&L chronologically from the starting balance so the
    # chart isn't just a single flat point.
    wallet = get_or_create_paper_wallet(user)
    running = wallet.starting_balance
    curve = [{'date': None, 'equity': _round2(running)}]
    events = []
    for t in PaperTrade.objects.filter(user=user, side='SELL', realized_pnl__isnull=False):
        events.append((t.created_at, t.realized_pnl))
    for o in PaperOptionOrder.objects.filter(user=user, side='SELL', realized_pnl_inr__isnull=False):
        events.append((o.created_at, o.realized_pnl_inr))
    for o in PaperCommodityOrder.objects.filter(user=user, side='SELL', realized_pnl_inr__isnull=False):
        events.append((o.created_at, o.realized_pnl_inr))
    events.sort(key=lambda e: e[0])
    for created_at, pnl in events:
        running += pnl
        curve.append({'date': created_at.date().isoformat(), 'equity': _round2(running)})
    current_equity = wallet.balance + _current_holdings_value(user)
    curve.append({'date': timezone.localdate().isoformat(), 'equity': _round2(current_equity)})
    return curve


def _max_drawdown(curve: list[dict]) -> dict:
    peak = None
    max_dd_amount = Decimal('0')
    max_dd_percent = 0.0
    for point in curve:
        equity = Decimal(str(point['equity']))
        if peak is None or equity > peak:
            peak = equity
        if peak and peak > 0:
            dd = peak - equity
            dd_pct = float(dd / peak * 100)
            if dd > max_dd_amount:
                max_dd_amount = dd
            if dd_pct > max_dd_percent:
                max_dd_percent = dd_pct
    return {
        'maxDrawdownAmount': _round2(max_dd_amount),
        'maxDrawdownPercent': round(max_dd_percent, 2),
    }


def compute_performance_analytics(user) -> dict:
    equity_pnls = [
        t.realized_pnl
        for t in PaperTrade.objects.filter(user=user, side='SELL', realized_pnl__isnull=False)
    ]
    option_pnls = [
        o.realized_pnl_inr
        for o in PaperOptionOrder.objects.filter(user=user, side='SELL', realized_pnl_inr__isnull=False)
    ]
    commodity_pnls = [
        o.realized_pnl_inr
        for o in PaperCommodityOrder.objects.filter(user=user, side='SELL', realized_pnl_inr__isnull=False)
    ]
    closed_pnls = equity_pnls + option_pnls + commodity_pnls

    total_trades = (
        PaperTrade.objects.filter(user=user).count()
        + PaperOptionOrder.objects.filter(user=user, status='EXECUTED').count()
        + PaperCommodityOrder.objects.filter(user=user, status='EXECUTED').count()
    )
    wins = [p for p in closed_pnls if p > 0]
    losses = [p for p in closed_pnls if p < 0]

    win_rate = (len(wins) / len(closed_pnls) * 100) if closed_pnls else 0.0
    gross_profit = sum(wins, Decimal('0'))
    gross_loss = abs(sum(losses, Decimal('0')))
    profit_factor = float(gross_profit / gross_loss) if gross_loss > 0 else (
        float(gross_profit) if gross_profit > 0 else 0.0
    )
    avg_win = float(gross_profit / len(wins)) if wins else 0.0
    avg_loss = float(gross_loss / len(losses)) if losses else 0.0
    total_realized_pnl = sum(closed_pnls, Decimal('0'))
    best_trade = max(closed_pnls, default=Decimal('0'))
    worst_trade = min(closed_pnls, default=Decimal('0'))

    curve = get_equity_curve(user)
    drawdown = _max_drawdown(curve)

    wallet = get_or_create_paper_wallet(user)
    current_equity = wallet.balance + _current_holdings_value(user)
    total_return_percent = (
        float((current_equity - wallet.starting_balance) / wallet.starting_balance * 100)
        if wallet.starting_balance else 0.0
    )

    return {
        'totalTrades': total_trades,
        'closedTrades': len(closed_pnls),
        'winCount': len(wins),
        'lossCount': len(losses),
        'winRatePercent': round(win_rate, 2),
        'profitFactor': round(profit_factor, 2),
        'avgWin': _round2(avg_win),
        'avgLoss': _round2(avg_loss),
        'bestTrade': _round2(best_trade),
        'worstTrade': _round2(worst_trade),
        'totalRealizedPnl': _round2(total_realized_pnl),
        'currentEquity': _round2(current_equity),
        'startingBalance': _round2(wallet.starting_balance),
        'totalReturnPercent': round(total_return_percent, 2),
        'maxDrawdownAmount': drawdown['maxDrawdownAmount'],
        'maxDrawdownPercent': drawdown['maxDrawdownPercent'],
        'equityCurve': curve,
    }
