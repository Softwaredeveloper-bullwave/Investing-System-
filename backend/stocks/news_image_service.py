"""Proxy remote news images so Flutter web can load them (avoids hotlink/CORS blocks)."""

from __future__ import annotations

import logging
from typing import Optional, Tuple
from urllib.parse import urlparse

import httpx
from django.core.cache import cache
from django.http import HttpResponse

from .news_service import RSS_HEADERS

logger = logging.getLogger('bullwave.news')

ALLOWED_IMAGE_HOST_SUFFIXES = (
    'etimg.com',
    'indiatimes.com',
    'livemint.com',
    'moneycontrol.com',
    'business-standard.com',
    'finnhub.net',
    'finnhub.io',
    'reuters.com',
    'bloomberg.com',
)


def _host_allowed(hostname: str) -> bool:
    host = (hostname or '').lower()
    if not host:
        return False
    return any(host == suffix or host.endswith(f'.{suffix}') for suffix in ALLOWED_IMAGE_HOST_SUFFIXES)


def fetch_news_image(url: str) -> Optional[Tuple[bytes, str]]:
    parsed = urlparse(url)
    if parsed.scheme not in ('http', 'https') or not _host_allowed(parsed.hostname):
        return None

    cache_key = f'news_img:v1:{url}'
    cached = cache.get(cache_key)
    if cached:
        return cached

    referer = f'{parsed.scheme}://{parsed.hostname}/'
    headers = {
        **RSS_HEADERS,
        'Referer': referer,
        'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    }

    try:
        with httpx.Client(timeout=12, follow_redirects=True) as client:
            response = client.get(url, headers=headers)
            response.raise_for_status()
            content_type = response.headers.get('content-type', 'image/jpeg').split(';')[0].strip()
            if not content_type.startswith('image/'):
                return None
            payload = (response.content, content_type)
            cache.set(cache_key, payload, 3600)
            return payload
    except Exception as exc:
        logger.warning('News image proxy failed for %s: %s', url, exc)
        return None
