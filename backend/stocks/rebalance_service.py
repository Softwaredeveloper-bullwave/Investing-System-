"""AI portfolio rebalancing — drift detection and in-app notification automation."""

import logging
from datetime import timedelta
from typing import Any

from django.utils import timezone

from engagement.models import Notification

from .portfolio_service import get_stock_portfolio

logger = logging.getLogger('bullwave.finance')

# Balanced Indian equity portfolio guardrails (automation targets).
MAX_SECTOR_PCT = 30.0
MAX_STOCK_PCT = 22.0
MIN_SECTORS = 3
DRIFT_NOTIFY_THRESHOLD = 55  # 0–100; notify when drift score exceeds this

NOTIFICATION_TYPE = 'rebalance'
DEDUPE_DAYS = 3


def _drift_score(sector_allocation: list[dict], holdings: list[dict]) -> int:
    """Higher score = more drift from balanced targets."""
    if not holdings:
        return 0

    score = 0.0
    total_value = sum(h['current_value'] for h in holdings) or 1.0

    # Sector concentration penalty
    for item in sector_allocation:
        pct = float(item.get('percentage') or 0)
        if pct > MAX_SECTOR_PCT:
            score += (pct - MAX_SECTOR_PCT) * 1.8

    sector_count = len([s for s in sector_allocation if float(s.get('percentage') or 0) >= 5])
    if sector_count < MIN_SECTORS:
        score += (MIN_SECTORS - sector_count) * 12

    # Single-stock concentration penalty
    for row in holdings:
        weight = row['current_value'] / total_value * 100
        if weight > MAX_STOCK_PCT:
            score += (weight - MAX_STOCK_PCT) * 2.2

    return min(100, int(round(score)))


def _build_suggestion(sector_allocation: list[dict], holdings: list[dict], drift: int) -> dict[str, Any]:
    total_value = sum(h['current_value'] for h in holdings) or 0
    actions: list[dict[str, str]] = []

    if sector_allocation:
        top_sector = max(sector_allocation, key=lambda s: float(s.get('percentage') or 0))
        top_pct = float(top_sector.get('percentage') or 0)
        if top_pct > MAX_SECTOR_PCT:
            trim_value = (top_pct - MAX_SECTOR_PCT) / 100 * total_value
            actions.append({
                'type': 'trim_sector',
                'label': f"Reduce {top_sector['label']} exposure",
                'detail': f"Currently {top_pct:.1f}% — target ≤{MAX_SECTOR_PCT:.0f}% (~₹{trim_value:,.0f} trim).",
            })

        light_sectors = [s for s in sector_allocation if float(s.get('percentage') or 0) < 8]
        if light_sectors:
            pick = light_sectors[0]
            actions.append({
                'type': 'add_sector',
                'label': f"Increase {pick['label']} allocation",
                'detail': f"Underweight at {float(pick.get('percentage') or 0):.1f}% — add via SIP or lump sum.",
            })

    if holdings:
        top_holding = max(holdings, key=lambda h: h['current_value'])
        weight = top_holding['current_value'] / total_value * 100 if total_value else 0
        if weight > MAX_STOCK_PCT:
            actions.append({
                'type': 'trim_stock',
                'label': f"Trim {top_holding['symbol']} position",
                'detail': f"{weight:.1f}% of portfolio — consider partial profit booking.",
            })

    if not actions:
        actions.append({
            'type': 'hold',
            'label': 'Portfolio looks balanced',
            'detail': 'No major sector or concentration drift detected.',
        })

    headline = (
        f'AI drift score {drift}/100 — rebalance recommended.'
        if drift >= DRIFT_NOTIFY_THRESHOLD
        else f'AI drift score {drift}/100 — portfolio within guardrails.'
    )

    message_parts = [headline]
    for action in actions[:3]:
        message_parts.append(f"• {action['label']}: {action['detail']}")

    return {
        'drift_score': drift,
        'needs_rebalance': drift >= DRIFT_NOTIFY_THRESHOLD,
        'headline': headline,
        'message': ' '.join(message_parts[:2]) if drift < DRIFT_NOTIFY_THRESHOLD else '\n'.join(message_parts),
        'actions': actions,
        'sector_allocation': sector_allocation,
        'top_holdings': holdings[:5],
    }


def _recent_rebalance_notification(user) -> bool:
    cutoff = timezone.now() - timedelta(days=DEDUPE_DAYS)
    return user.notifications.filter(type=NOTIFICATION_TYPE, created_at__gte=cutoff).exists()


def analyze_portfolio_rebalance(user, *, create_notification: bool = False) -> dict[str, Any]:
    """Compute AI rebalancing suggestion for a user portfolio."""
    data = get_stock_portfolio(user)
    holdings = data.get('holdings') or []
    sectors = data.get('sector_allocation') or []
    summary = data.get('summary') or {}

    if not holdings:
        return {
            'drift_score': 0,
            'needs_rebalance': False,
            'headline': 'Start investing to enable AI rebalancing',
            'message': 'Add holdings to your portfolio — automation will monitor sector drift and concentration.',
            'actions': [],
            'notification_created': False,
            'automation_enabled': True,
            'holdings_count': 0,
            'portfolio_value': 0,
        }

    drift = _drift_score(sectors, holdings)
    suggestion = _build_suggestion(sectors, holdings, drift)
    notification_created = False

    if create_notification and suggestion['needs_rebalance'] and not _recent_rebalance_notification(user):
        Notification.objects.create(
            user=user,
            title='AI Portfolio Rebalancing',
            message=suggestion['message'][:500],
            type=NOTIFICATION_TYPE,
        )
        notification_created = True
        logger.info('Rebalance notification created for user %s (drift=%s)', user.pk, drift)

    return {
        'drift_score': drift,
        'needs_rebalance': suggestion['needs_rebalance'],
        'headline': suggestion['headline'],
        'message': suggestion['message'],
        'actions': suggestion['actions'],
        'notification_created': notification_created,
        'automation_enabled': True,
        'holdings_count': summary.get('holdings_count', len(holdings)),
        'portfolio_value': summary.get('current_value', 0),
        'sector_allocation': sectors,
    }


def process_portfolio_rebalance_automation() -> int:
    """Scheduled job — scan users with stock holdings and notify on drift."""
    from django.contrib.auth import get_user_model
    from .models import StockHolding

    User = get_user_model()
    user_ids = (
        StockHolding.objects.filter(quantity__gt=0)
        .values_list('user_id', flat=True)
        .distinct()
    )
    created = 0
    for user in User.objects.filter(pk__in=user_ids):
        result = analyze_portfolio_rebalance(user, create_notification=True)
        if result.get('notification_created'):
            created += 1
    return created
