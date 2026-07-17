"""Live market news from free Indian financial RSS feeds (+ optional Finnhub)."""

import hashlib
import html
import logging
import re
from datetime import datetime, timedelta, timezone as dt_timezone
from email.utils import parsedate_to_datetime
from zoneinfo import ZoneInfo

import feedparser
import httpx
from django.conf import settings
from django.core.cache import cache
from django.utils import timezone

from .models import Stock

logger = logging.getLogger('bullwave.news')

IST = ZoneInfo('Asia/Kolkata')

# Free RSS feeds — real Indian stock market news, no API key required.
INDIAN_MARKET_FEEDS = (
    ('Economic Times', 'https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms'),
    ('ET Stocks', 'https://economictimes.indiatimes.com/markets/stocks/rssfeeds/2146842.cms'),
    ('Livemint Markets', 'https://www.livemint.com/rss/markets'),
    ('Moneycontrol', 'https://www.moneycontrol.com/rss/latestnews.xml'),
    ('Business Standard', 'https://www.business-standard.com/rss/markets-106.rss'),
)

RSS_HEADERS = {
    'User-Agent': (
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    ),
    'Accept': 'application/rss+xml, application/xml, text/xml, */*',
}

CACHE_TTL_SECONDS = getattr(settings, 'NEWS_CACHE_MINUTES', 15) * 60


def _stable_id(url, title):
    raw = (url or title).encode('utf-8', errors='ignore')
    return hashlib.sha256(raw).hexdigest()[:32]


def _parse_published(entry):
    if getattr(entry, 'published_parsed', None):
        try:
            dt = datetime(*entry.published_parsed[:6], tzinfo=IST)
            return dt.astimezone(dt_timezone.utc)
        except (TypeError, ValueError):
            pass
    if getattr(entry, 'updated_parsed', None):
        try:
            dt = datetime(*entry.updated_parsed[:6], tzinfo=IST)
            return dt.astimezone(dt_timezone.utc)
        except (TypeError, ValueError):
            pass
    published = getattr(entry, 'published', '') or getattr(entry, 'updated', '')
    if published:
        try:
            return parsedate_to_datetime(published)
        except (TypeError, ValueError):
            pass
    return timezone.now()


def _clean_html(text):
    if not text:
        return ''
    text = re.sub(r'<[^>]+>', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def _summary(entry, title):
    raw = (
        getattr(entry, 'summary', '')
        or getattr(entry, 'description', '')
        or getattr(entry, 'subtitle', '')
    )
    summary = _clean_html(raw)
    if not summary or summary.lower() == title.lower():
        return title
    if len(summary) > 280:
        return summary[:277].rsplit(' ', 1)[0] + '...'
    return summary


def _extract_image(entry):
    """Best-effort image URL from RSS media tags or embedded HTML."""
    thumbs = getattr(entry, 'media_thumbnail', None) or []
    if thumbs:
        url = thumbs[0].get('url') if isinstance(thumbs[0], dict) else getattr(thumbs[0], 'url', '')
        if url:
            return url

    media = getattr(entry, 'media_content', None) or []
    for item in media:
        url = item.get('url') if isinstance(item, dict) else getattr(item, 'url', '')
        media_type = item.get('type', '') if isinstance(item, dict) else getattr(item, 'type', '')
        if url and (not media_type or media_type.startswith('image/')):
            return url

    for link in getattr(entry, 'links', []) or []:
        link_type = link.get('type', '') if isinstance(link, dict) else getattr(link, 'type', '')
        href = link.get('href', '') if isinstance(link, dict) else getattr(link, 'href', '')
        if href and link_type.startswith('image/'):
            return href

    for enc in getattr(entry, 'enclosures', []) or []:
        enc_type = enc.get('type', '') if isinstance(enc, dict) else getattr(enc, 'type', '')
        href = enc.get('href', '') if isinstance(enc, dict) else getattr(enc, 'href', '')
        if href and enc_type.startswith('image/'):
            return href

    raw = (
        getattr(entry, 'summary', '')
        or getattr(entry, 'description', '')
        or getattr(entry, 'content', [{}])[0].get('value', '')
        if getattr(entry, 'content', None)
        else ''
    )
    if raw:
        match = re.search(r'src=["\']([^"\']+\.(?:jpg|jpeg|png|webp|gif)[^"\']*)', raw, re.I)
        if match:
            return match.group(1)

    return ''


def _known_symbols():
    cached = cache.get('news_known_symbols')
    if cached is not None:
        return cached
    symbols = list(Stock.objects.values_list('symbol', flat=True))
    cache.set('news_known_symbols', symbols, 3600)
    return symbols


def _extract_symbols(text, known_symbols):
    if not text or not known_symbols:
        return []
    upper = text.upper()
    found = []
    for symbol in known_symbols:
        if len(symbol) < 3:
            continue
        if re.search(rf'\b{re.escape(symbol.upper())}\b', upper):
            found.append(symbol)
        if len(found) >= 5:
            break
    return found


def _categorize(title, summary):
    text = f'{title} {summary}'.lower()
    if any(w in text for w in ('nifty', 'sensex', 'nse', 'bse', 'index')):
        return 'indices'
    if any(w in text for w in ('result', 'earnings', 'quarter', 'profit', 'revenue')):
        return 'earnings'
    if any(w in text for w in ('ipo', 'listing', 'fpo')):
        return 'ipo'
    if any(w in text for w in ('rbi', 'sebi', 'fed', 'rate', 'inflation', 'gdp')):
        return 'economy'
    return 'market'


def _parse_rss_feed(source, url, known_symbols):
    items = []
    try:
        with httpx.Client(timeout=20, follow_redirects=True) as client:
            response = client.get(url, headers=RSS_HEADERS)
            response.raise_for_status()
            parsed = feedparser.parse(response.text)
    except Exception as exc:
        logger.warning('RSS fetch failed for %s: %s', source, exc)
        return items

    for entry in parsed.entries[:25]:
        title = html.unescape(_clean_html(getattr(entry, 'title', ''))).strip()
        if not title:
            continue
        link = getattr(entry, 'link', '') or ''
        summary = _summary(entry, title)
        related = _extract_symbols(f'{title} {summary}', known_symbols)
        items.append(
            {
                'id': _stable_id(link, title),
                'title': title,
                'summary': summary,
                'source': source,
                'published_at': _parse_published(entry),
                'related_symbols': related,
                'category': _categorize(title, summary),
                'url': link,
                'image_url': _extract_image(entry),
            }
        )
    return items


def _fetch_finnhub_company(symbol):
    api_key = (getattr(settings, 'FINNHUB_API_KEY', '') or '').strip()
    if not api_key:
        return []

    finnhub_symbol = symbol if '.' in symbol else f'{symbol.upper()}.NS'
    today = timezone.now().date()
    start = today - timedelta(days=7)

    try:
        with httpx.Client(timeout=15) as client:
            response = client.get(
                'https://finnhub.io/api/v1/company-news',
                params={
                    'symbol': finnhub_symbol,
                    'from': start.isoformat(),
                    'to': today.isoformat(),
                    'token': api_key,
                },
            )
            response.raise_for_status()
            data = response.json()
    except Exception as exc:
        logger.warning('Finnhub company news failed for %s: %s', symbol, exc)
        return []

    if not isinstance(data, list):
        return []

    items = []
    for article in data[:15]:
        title = (article.get('headline') or '').strip()
        if not title:
            continue
        ts = article.get('datetime') or 0
        published = datetime.fromtimestamp(ts, tz=dt_timezone.utc) if ts else timezone.now()
        summary = (article.get('summary') or title).strip()
        if len(summary) > 280:
            summary = summary[:277].rsplit(' ', 1)[0] + '...'
        url = article.get('url') or ''
        items.append(
            {
                'id': _stable_id(url, title),
                'title': title,
                'summary': summary,
                'source': article.get('source') or 'Finnhub',
                'published_at': published,
                'related_symbols': [symbol.upper()],
                'category': 'stock',
                'url': url,
                'image_url': article.get('image') or '',
            }
        )
    return items


def _dedupe_sort(items):
    seen = set()
    unique = []
    for item in sorted(items, key=lambda x: x['published_at'], reverse=True):
        key = item['title'].lower().strip()
        if key in seen:
            continue
        seen.add(key)
        unique.append(item)
    return unique


def _fetch_finnhub_market(limit=20):
    api_key = (getattr(settings, 'FINNHUB_API_KEY', '') or '').strip()
    if not api_key:
        return []

    try:
        with httpx.Client(timeout=15) as client:
            response = client.get(
                'https://finnhub.io/api/v1/news',
                params={'category': 'general', 'token': api_key},
            )
            response.raise_for_status()
            data = response.json()
    except Exception as exc:
        logger.warning('Finnhub market news failed: %s', exc)
        return []

    if not isinstance(data, list):
        return []

    items = []
    for article in data[:limit]:
        title = (article.get('headline') or '').strip()
        if not title:
            continue
        ts = article.get('datetime') or 0
        published = datetime.fromtimestamp(ts, tz=dt_timezone.utc) if ts else timezone.now()
        summary = (article.get('summary') or title).strip()
        if len(summary) > 280:
            summary = summary[:277].rsplit(' ', 1)[0] + '...'
        url = article.get('url') or ''
        items.append(
            {
                'id': _stable_id(url, title),
                'title': title,
                'summary': summary,
                'source': article.get('source') or 'Finnhub',
                'published_at': published,
                'related_symbols': [],
                'category': 'market',
                'url': url,
                'image_url': article.get('image') or '',
            }
        )
    return items


def fetch_market_news(limit=20, symbol=None):
    """
    Fetch live market news. Cached 15 minutes.
    Primary source: Indian financial RSS (free, no key).
    Optional: Finnhub company news when symbol is set and FINNHUB_API_KEY exists.
    """
    symbol = (symbol or '').strip().upper()
    cache_key = f'market_news:v2:{symbol or "all"}:{limit}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    known_symbols = _known_symbols()
    items = []

    for source, url in INDIAN_MARKET_FEEDS:
        items.extend(_parse_rss_feed(source, url, known_symbols))

    if symbol:
        symbol_matches = [
            item
            for item in items
            if symbol in item['related_symbols']
            or symbol in item['title'].upper()
            or symbol in item['summary'].upper()
        ]
        items.extend(_fetch_finnhub_company(symbol))
        items = _dedupe_sort(symbol_matches + items)
    else:
        items = _dedupe_sort(items)
        if len(items) < max(5, limit // 2):
            items = _dedupe_sort(items + _fetch_finnhub_market(limit=limit))

    result = items[:limit]
    cache.set(cache_key, result, CACHE_TTL_SECONDS)
    return result


def fetch_news_headlines(limit=5):
    """Home / Markets news cards — includes thumbnail when the source provides one."""
    headlines = []
    for item in fetch_market_news(limit=limit):
        published = item.get('published_at')
        if hasattr(published, 'isoformat'):
            time_label = published.astimezone(timezone.get_current_timezone()).strftime('%I:%M %p')
        else:
            time_label = 'Recent'
        headlines.append(
            {
                'title': item['title'],
                'subtitle': f"{item['source']} • {item['summary'][:100]}",
                'url': item.get('url', ''),
                'imageUrl': item.get('image_url') or '',
                'category': item.get('category') or 'Markets',
                'time': time_label,
                'source': item.get('source') or '',
            }
        )
    return headlines
