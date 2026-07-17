"""Paper trading risk meter — how aggressively the user is practicing."""

from __future__ import annotations

from datetime import timedelta
from typing import Any

from django.utils import timezone

from .models import PaperTrade
from .portfolio_service import get_stock_portfolio


def _level(score: int) -> tuple[str, str]:
    """score = risk 0–100 (higher = riskier)."""
    if score >= 80:
        return 'extreme', 'Extreme risk'
    if score >= 60:
        return 'high', 'High risk'
    if score >= 35:
        return 'medium', 'Moderate risk'
    return 'low', 'Low risk'


def get_paper_risk_meter(user) -> dict[str, Any]:
    now = timezone.now()
    week_ago = now - timedelta(days=7)
    trades = PaperTrade.objects.filter(user=user).select_related('stock')
    recent = trades.filter(created_at__gte=week_ago)
    total_trades = trades.count()
    recent_count = recent.count()

    portfolio = get_stock_portfolio(user)
    holdings = portfolio.get('holdings') or []
    summary = portfolio.get('summary') or {}
    holdings_count = int(summary.get('holdings_count') or len(holdings))
    portfolio_value = float(summary.get('current_value') or 0)
    day_pnl_pct = float(summary.get('day_pnl_percent') or 0)

    score = 12  # baseline practice risk
    factors: list[dict[str, str]] = []

    # Trade frequency (max +28)
    if recent_count >= 20:
        score += 28
        factors.append({
            'key': 'frequency',
            'label': 'Very high trade frequency',
            'impact': 'negative',
            'detail': f'{recent_count} paper trades in 7 days — overtrading risk.',
        })
    elif recent_count >= 10:
        score += 18
        factors.append({
            'key': 'frequency',
            'label': 'Active trading week',
            'impact': 'negative',
            'detail': f'{recent_count} trades this week.',
        })
    elif recent_count >= 4:
        score += 8
        factors.append({
            'key': 'frequency',
            'label': 'Steady practice pace',
            'impact': 'positive',
            'detail': f'{recent_count} trades this week.',
        })
    else:
        factors.append({
            'key': 'frequency',
            'label': 'Light trading activity',
            'impact': 'positive',
            'detail': f'{recent_count} trades in the last 7 days.',
        })

    # Concentration (max +25)
    if holdings_count == 1:
        score += 25
        factors.append({
            'key': 'concentration',
            'label': 'Single-name concentration',
            'impact': 'negative',
            'detail': 'All paper exposure in one stock.',
        })
    elif holdings_count == 2:
        score += 16
        factors.append({
            'key': 'concentration',
            'label': 'Narrow book',
            'impact': 'negative',
            'detail': 'Only 2 holdings — add names to reduce risk.',
        })
    elif holdings_count >= 5:
        score += 4
        factors.append({
            'key': 'concentration',
            'label': 'Diversified practice book',
            'impact': 'positive',
            'detail': f'{holdings_count} holdings.',
        })
    elif holdings_count > 0:
        score += 10
        factors.append({
            'key': 'concentration',
            'label': 'Limited diversification',
            'impact': 'negative',
            'detail': f'{holdings_count} holdings.',
        })
    else:
        factors.append({
            'key': 'concentration',
            'label': 'No open positions',
            'impact': 'positive',
            'detail': 'Flat book — risk is mostly from future orders.',
        })

    # Largest position weight (max +20)
    if portfolio_value > 0 and holdings:
        top_weight = max(
            (float(h.get('current_value') or 0) / portfolio_value * 100) for h in holdings
        )
        if top_weight >= 45:
            score += 20
            factors.append({
                'key': 'size',
                'label': 'Oversized position',
                'impact': 'negative',
                'detail': f'Top holding is {top_weight:.0f}% of paper book.',
            })
        elif top_weight >= 30:
            score += 12
            factors.append({
                'key': 'size',
                'label': 'Large position weight',
                'impact': 'negative',
                'detail': f'Top holding is {top_weight:.0f}% of book.',
            })
        else:
            factors.append({
                'key': 'size',
                'label': 'Position sizing OK',
                'impact': 'positive',
                'detail': f'Top holding {top_weight:.0f}% of book.',
            })

    # Day volatility (max +15)
    if abs(day_pnl_pct) >= 4:
        score += 15
        factors.append({
            'key': 'volatility',
            'label': 'High day swing',
            'impact': 'negative',
            'detail': f'Day P&L {day_pnl_pct:+.1f}%.',
        })
    elif abs(day_pnl_pct) >= 2:
        score += 8
        factors.append({
            'key': 'volatility',
            'label': 'Elevated day move',
            'impact': 'negative',
            'detail': f'Day P&L {day_pnl_pct:+.1f}%.',
        })
    else:
        factors.append({
            'key': 'volatility',
            'label': 'Stable day P&L',
            'impact': 'positive',
            'detail': f'Day P&L {day_pnl_pct:+.1f}%.',
        })

    # Win rate on closed sells (max ±10)
    sells = trades.filter(side='SELL', realized_pnl__isnull=False)
    sell_count = sells.count()
    if sell_count >= 3:
        wins = sells.filter(realized_pnl__gt=0).count()
        win_rate = wins / sell_count * 100
        if win_rate < 40:
            score += 10
            factors.append({
                'key': 'edge',
                'label': 'Weak win rate',
                'impact': 'negative',
                'detail': f'{win_rate:.0f}% wins on closed paper trades.',
            })
        else:
            score -= 6
            factors.append({
                'key': 'edge',
                'label': 'Healthy win rate',
                'impact': 'positive',
                'detail': f'{win_rate:.0f}% wins on closed paper trades.',
            })

    score = int(max(0, min(100, round(score))))
    level, label = _level(score)

    if total_trades == 0 and holdings_count == 0:
        summary_text = 'Place practice trades to unlock a live risk reading.'
        score = 0
        level, label = 'low', 'No risk yet'
    else:
        summary_text = (
            'Risk meter blends trade pace, concentration, position size, and day swings '
            'from your paper book.'
        )

    return {
        'score': score,
        'level': level,
        'label': label,
        'summary': summary_text,
        'trades_count': total_trades,
        'recent_trades': recent_count,
        'holdings_count': holdings_count,
        'portfolio_value': portfolio_value,
        'day_pnl_percent': day_pnl_pct,
        'factors': factors[:5],
        'zones': [
            {'key': 'low', 'from': 0, 'to': 34, 'label': 'Low'},
            {'key': 'medium', 'from': 35, 'to': 59, 'label': 'Medium'},
            {'key': 'high', 'from': 60, 'to': 79, 'label': 'High'},
            {'key': 'extreme', 'from': 80, 'to': 100, 'label': 'Extreme'},
        ],
    }


def get_market_risk_meter(user) -> dict[str, Any]:
    """Live portfolio risk for real Markets trading."""
    portfolio = get_stock_portfolio(user)
    holdings = portfolio.get('holdings') or []
    summary = portfolio.get('summary') or {}
    sectors = portfolio.get('sector_allocation') or []
    holdings_count = int(summary.get('holdings_count') or len(holdings))
    portfolio_value = float(summary.get('current_value') or 0)
    day_pnl_pct = float(summary.get('day_pnl_percent') or 0)
    total_pnl_pct = float(summary.get('total_pnl_percent') or 0)

    score = 18
    factors: list[dict[str, str]] = []

    if holdings_count == 0:
        return {
            'score': 0,
            'level': 'low',
            'label': 'No risk yet',
            'summary': 'Build a live portfolio to unlock your market risk meter.',
            'trades_count': 0,
            'recent_trades': 0,
            'holdings_count': 0,
            'portfolio_value': 0,
            'day_pnl_percent': 0,
            'factors': [],
            'zones': [
                {'key': 'low', 'from': 0, 'to': 34, 'label': 'Low'},
                {'key': 'medium', 'from': 35, 'to': 59, 'label': 'Medium'},
                {'key': 'high', 'from': 60, 'to': 79, 'label': 'High'},
                {'key': 'extreme', 'from': 80, 'to': 100, 'label': 'Extreme'},
            ],
        }

    # Concentration
    if holdings_count == 1:
        score += 28
        factors.append({
            'key': 'concentration',
            'label': 'Single-stock risk',
            'impact': 'negative',
            'detail': 'Entire live book is in one name.',
        })
    elif holdings_count <= 3:
        score += 16
        factors.append({
            'key': 'concentration',
            'label': 'Low diversification',
            'impact': 'negative',
            'detail': f'Only {holdings_count} holdings in the live portfolio.',
        })
    else:
        factors.append({
            'key': 'concentration',
            'label': 'Diversified book',
            'impact': 'positive',
            'detail': f'{holdings_count} holdings across {len(sectors)} sectors.',
        })

    # Top weight
    if portfolio_value > 0:
        top_weight = max(
            (float(h.get('current_value') or 0) / portfolio_value * 100) for h in holdings
        )
        if top_weight >= 40:
            score += 22
            factors.append({
                'key': 'size',
                'label': 'Position concentration',
                'impact': 'negative',
                'detail': f'Top holding is {top_weight:.0f}% of portfolio.',
            })
        elif top_weight >= 25:
            score += 12
            factors.append({
                'key': 'size',
                'label': 'Elevated single-name weight',
                'impact': 'negative',
                'detail': f'Top holding is {top_weight:.0f}% of portfolio.',
            })
        else:
            factors.append({
                'key': 'size',
                'label': 'Balanced position sizes',
                'impact': 'positive',
                'detail': f'Top holding {top_weight:.0f}% of portfolio.',
            })

    # Sector tilt
    if sectors:
        top_sector = max(sectors, key=lambda s: float(s.get('percentage') or s.get('value') or 0))
        sector_pct = float(top_sector.get('percentage') or 0)
        sector_name = top_sector.get('label') or top_sector.get('sector') or 'One sector'
        if sector_pct >= 50:
            score += 14
            factors.append({
                'key': 'sector',
                'label': 'Sector tilt',
                'impact': 'negative',
                'detail': f'{sector_name} is {sector_pct:.0f}% of book.',
            })
        else:
            factors.append({
                'key': 'sector',
                'label': 'Sector mix OK',
                'impact': 'positive',
                'detail': f'Largest sector {sector_pct:.0f}%.',
            })

    # Day volatility
    if abs(day_pnl_pct) >= 3.5:
        score += 16
        factors.append({
            'key': 'volatility',
            'label': 'High day volatility',
            'impact': 'negative',
            'detail': f'Today’s live P&L {day_pnl_pct:+.1f}%.',
        })
    elif abs(day_pnl_pct) >= 1.8:
        score += 8
        factors.append({
            'key': 'volatility',
            'label': 'Active day swing',
            'impact': 'negative',
            'detail': f'Today’s live P&L {day_pnl_pct:+.1f}%.',
        })
    else:
        factors.append({
            'key': 'volatility',
            'label': 'Stable session',
            'impact': 'positive',
            'detail': f'Today’s live P&L {day_pnl_pct:+.1f}%.',
        })

    # Underwater book
    if total_pnl_pct <= -12:
        score += 12
        factors.append({
            'key': 'drawdown',
            'label': 'Deep unrealized loss',
            'impact': 'negative',
            'detail': f'Overall P&L {total_pnl_pct:.1f}%.',
        })
    elif total_pnl_pct >= 8:
        score -= 5
        factors.append({
            'key': 'returns',
            'label': 'Positive cushion',
            'impact': 'positive',
            'detail': f'Overall P&L {total_pnl_pct:+.1f}%.',
        })

    score = int(max(0, min(100, round(score))))
    level, label = _level(score)
    return {
        'score': score,
        'level': level,
        'label': label,
        'summary': (
            'Live market risk from concentration, sector tilt, position size, '
            'and today’s P&L swings on your real holdings.'
        ),
        'trades_count': 0,
        'recent_trades': 0,
        'holdings_count': holdings_count,
        'portfolio_value': portfolio_value,
        'day_pnl_percent': day_pnl_pct,
        'factors': factors[:5],
        'zones': [
            {'key': 'low', 'from': 0, 'to': 34, 'label': 'Low'},
            {'key': 'medium', 'from': 35, 'to': 59, 'label': 'Medium'},
            {'key': 'high', 'from': 60, 'to': 79, 'label': 'High'},
            {'key': 'extreme', 'from': 80, 'to': 100, 'label': 'Extreme'},
        ],
    }
