"""User-configurable paper-trading risk limits — daily loss cap and max
single-position sizing. Purely advisory: never blocks an order, only powers
dashboard warnings so learners build risk discipline. Distinct from the
existing `paper_risk_service.py`, which scores 0-100 "risk meter" factors —
this module is the user's own configured limits + breach checks.
"""

from __future__ import annotations

from decimal import Decimal

from django.utils import timezone

from .models import PaperCommodityHolding, PaperEquitySnapshot, PaperOptionHolding, PaperRiskLimit, StockHolding
from .paper_analytics_service import _current_holdings_value
from .trading_service import get_or_create_paper_wallet


def _round2(value) -> float:
    return round(float(value), 2)


def build_risk_limit_payload(limit: PaperRiskLimit) -> dict:
    return {
        'maxDailyLoss': _round2(limit.max_daily_loss) if limit.max_daily_loss is not None else None,
        'maxPositionSizePercent': _round2(limit.max_position_size_percent),
        'isActive': limit.is_active,
    }


def get_risk_limit(user) -> PaperRiskLimit:
    return PaperRiskLimit.get_or_create_for(user)


def update_risk_limit(user, *, max_daily_loss=None, max_position_size_percent=None, is_active=None) -> dict:
    limit = get_risk_limit(user)
    if max_daily_loss is not None:
        limit.max_daily_loss = Decimal(str(max_daily_loss)) if max_daily_loss != '' else None
    if max_position_size_percent is not None:
        limit.max_position_size_percent = Decimal(str(max_position_size_percent))
    if is_active is not None:
        limit.is_active = bool(is_active)
    limit.save()
    return build_risk_limit_payload(limit)


def check_risk_warnings(user) -> dict:
    """Returns today's daily-loss status and any position-sizing breaches."""
    limit = get_risk_limit(user)
    wallet = get_or_create_paper_wallet(user)
    holdings_value = _current_holdings_value(user)
    current_equity = wallet.balance + holdings_value

    today = timezone.localdate()
    yesterday_snapshot = (
        PaperEquitySnapshot.objects.filter(user=user, date__lt=today).order_by('-date').first()
    )
    baseline_equity = yesterday_snapshot.equity if yesterday_snapshot else wallet.starting_balance
    daily_pnl = current_equity - baseline_equity
    daily_loss = -daily_pnl if daily_pnl < 0 else Decimal('0')

    daily_loss_breached = bool(
        limit.is_active and limit.max_daily_loss and daily_loss > limit.max_daily_loss
    )

    position_breaches = []
    if limit.is_active and current_equity > 0:
        for h in StockHolding.objects.filter(user=user, quantity__gt=0).select_related('stock'):
            value = Decimal(h.quantity) * Decimal(h.stock.ltp)
            pct = float(value / current_equity * 100)
            if pct > float(limit.max_position_size_percent):
                position_breaches.append({
                    'symbol': h.stock.symbol,
                    'positionPercent': round(pct, 2),
                    'limitPercent': _round2(limit.max_position_size_percent),
                })
        from .options_service import estimate_option_premium

        for h in PaperOptionHolding.objects.filter(user=user, quantity__gt=0):
            premium = estimate_option_premium(h.underlying, h.strike, h.option_type, h.expiry, asset_class=h.asset_class)
            mark = Decimal(str(premium)) if premium is not None else Decimal(h.avg_premium)
            value = Decimal(h.quantity) * Decimal(h.lot_size) * mark
            pct = float(value / current_equity * 100)
            if pct > float(limit.max_position_size_percent):
                position_breaches.append({
                    'symbol': f'{h.underlying} {float(h.strike):g} {h.option_type}',
                    'positionPercent': round(pct, 2),
                    'limitPercent': _round2(limit.max_position_size_percent),
                })
        commodity_holdings = list(PaperCommodityHolding.objects.filter(user=user, quantity__gt=0))
        if commodity_holdings:
            from .commodity_trading_service import get_usd_inr_rate
            usd_inr_rate = get_usd_inr_rate()
        for h in commodity_holdings:
            value = Decimal(h.quantity) * Decimal(h.avg_price_usd) * usd_inr_rate
            pct = float(value / current_equity * 100)
            if pct > float(limit.max_position_size_percent):
                position_breaches.append({
                    'symbol': h.commodity_id,
                    'positionPercent': round(pct, 2),
                    'limitPercent': _round2(limit.max_position_size_percent),
                })

    return {
        'limit': build_risk_limit_payload(limit),
        'dailyPnl': _round2(daily_pnl),
        'dailyLoss': _round2(daily_loss),
        'dailyLossBreached': daily_loss_breached,
        'positionBreaches': position_breaches,
        'currentEquity': _round2(current_equity),
    }
