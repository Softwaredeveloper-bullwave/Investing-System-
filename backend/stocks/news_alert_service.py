"""News alert matching against live market headlines."""

import logging
from datetime import timedelta

from django.utils import timezone

from engagement.models import Notification

from .models import NewsAlert
from .news_service import fetch_market_news

logger = logging.getLogger('bullwave.news')

DEDUPE_HOURS = 6


def process_news_alerts() -> int:
    """Match active news alerts to recent headlines; notify users. Returns count triggered."""
    alerts = list(NewsAlert.objects.filter(is_active=True).select_related('user'))
    if not alerts:
        return 0

    try:
        news = fetch_market_news(limit=40)
    except Exception as exc:
        logger.warning('News alert scan skipped: %s', exc)
        return 0

    if not news:
        return 0

    triggered = 0
    cutoff = timezone.now() - timedelta(hours=DEDUPE_HOURS)

    for alert in alerts:
        keyword = (alert.keyword or '').strip().upper()
        if not keyword:
            continue

        if alert.last_matched_at and alert.last_matched_at >= cutoff:
            continue

        match = None
        for item in news:
            title = (item.get('title') or '') if isinstance(item, dict) else ''
            summary = (item.get('summary') or '') if isinstance(item, dict) else ''
            symbols = [str(s).upper() for s in (item.get('related_symbols') or [])] if isinstance(item, dict) else []
            haystack = f'{title} {summary}'.upper()
            if keyword in haystack or keyword in symbols:
                match = item
                break

        if match is None:
            continue

        title = (match.get('title') or 'Market news')[:300]
        source = match.get('source') or 'Markets'

        if alert.last_matched_title and alert.last_matched_title == title:
            continue

        alert.last_matched_at = timezone.now()
        alert.last_matched_title = title
        alert.save(update_fields=['last_matched_at', 'last_matched_title'])

        Notification.objects.create(
            user=alert.user,
            title=f'News Alert: {alert.keyword}',
            message=f'{title} — via {source}',
            type='news',
        )
        triggered += 1

    return triggered
