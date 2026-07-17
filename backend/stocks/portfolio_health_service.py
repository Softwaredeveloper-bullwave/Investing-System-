"""Portfolio health score — diversification, concentration, and performance."""

from typing import Any

from .portfolio_service import get_stock_portfolio
from .rebalance_service import _drift_score


def _grade(score: int) -> str:
    if score >= 85:
        return 'Excellent'
    if score >= 70:
        return 'Good'
    if score >= 55:
        return 'Fair'
    if score >= 40:
        return 'Needs attention'
    return 'At risk'


def _grade_letter(score: int) -> str:
    if score >= 85:
        return 'A'
    if score >= 70:
        return 'B'
    if score >= 55:
        return 'C'
    if score >= 40:
        return 'D'
    return 'F'


def get_portfolio_health(user) -> dict[str, Any]:
    data = get_stock_portfolio(user)
    holdings = data.get('holdings') or []
    sectors = data.get('sector_allocation') or []
    summary = data.get('summary') or {}

    if not holdings:
        return {
            'score': 0,
            'grade': '—',
            'grade_letter': '—',
            'label': 'No holdings yet',
            'summary': 'Add stocks to unlock your portfolio health score.',
            'factors': [],
            'drift_score': 0,
            'holdings_count': 0,
            'portfolio_value': 0,
        }

    drift = _drift_score(sectors, holdings)
    pnl_pct = float(summary.get('total_pnl_percent') or 0)
    day_pnl_pct = float(summary.get('day_pnl_percent') or 0)
    holdings_count = int(summary.get('holdings_count') or len(holdings))

    score = 100.0
    factors: list[dict[str, str]] = []

    # Drift / concentration (max -35)
    drift_penalty = min(35, drift * 0.55)
    score -= drift_penalty
    if drift >= 40:
        factors.append({
            'key': 'concentration',
            'label': 'Concentration risk',
            'impact': 'negative',
            'detail': f'Sector or stock drift detected (drift {drift}/100).',
        })
    else:
        factors.append({
            'key': 'concentration',
            'label': 'Balanced allocation',
            'impact': 'positive',
            'detail': 'Sector and stock weights within guardrails.',
        })

    # Diversification bonus (max +15)
    div_bonus = min(15, holdings_count * 2.5)
    if holdings_count < 3:
        factors.append({
            'key': 'diversification',
            'label': 'Low diversification',
            'impact': 'negative',
            'detail': f'Only {holdings_count} holding(s) — add more names to reduce risk.',
        })
        score -= 8
    else:
        score += div_bonus
        factors.append({
            'key': 'diversification',
            'label': 'Diversification',
            'impact': 'positive',
            'detail': f'{holdings_count} holdings across {len(sectors)} sectors.',
        })

    # Performance (max ±12)
    if pnl_pct > 0:
        bonus = min(12, pnl_pct * 0.4)
        score += bonus
        factors.append({
            'key': 'returns',
            'label': 'Overall returns',
            'impact': 'positive',
            'detail': f'Total P&L {pnl_pct:+.1f}% on invested capital.',
        })
    elif pnl_pct < -3:
        penalty = min(12, abs(pnl_pct) * 0.35)
        score -= penalty
        factors.append({
            'key': 'returns',
            'label': 'Underwater portfolio',
            'impact': 'negative',
            'detail': f'Total P&L {pnl_pct:.1f}% — review weak positions.',
        })

    # Day volatility (max -8)
    if abs(day_pnl_pct) > 2.5:
        score -= min(8, abs(day_pnl_pct))
        factors.append({
            'key': 'volatility',
            'label': 'High day move',
            'impact': 'negative',
            'detail': f"Today's move {day_pnl_pct:+.1f}% — elevated short-term volatility.",
        })

    final_score = max(0, min(100, int(round(score))))
    grade = _grade(final_score)

    return {
        'score': final_score,
        'grade': grade,
        'grade_letter': _grade_letter(final_score),
        'label': grade,
        'summary': f'Health score {final_score}/100 — {grade.lower()} portfolio quality.',
        'factors': factors[:5],
        'drift_score': drift,
        'holdings_count': holdings_count,
        'portfolio_value': summary.get('current_value', 0),
        'total_pnl_percent': pnl_pct,
        'day_pnl_percent': day_pnl_pct,
    }
