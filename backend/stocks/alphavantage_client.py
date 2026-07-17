"""Alpha Vantage Global API — real-time quotes, daily/intraday candles, fundamentals."""

import logging
import time
from datetime import datetime, timezone as dt_timezone

import httpx
from django.conf import settings
from django.core.cache import cache

logger = logging.getLogger('bullwave.market')

BASE_URL = 'https://www.alphavantage.co/query'

# NSE index IDs → Yahoo-style tickers (Alpha Vantage does not serve NSE indices reliably)
INDEX_YAHOO_SYMBOLS = {
    'NIFTY50': '^NSEI',
    'NIFTY': '^NSEI',
    'SENSEX': '^BSESN',
    'BANKNIFTY': '^NSEBANK',
}


class AlphaVantageError(Exception):
    pass


def _api_key():
    key = (getattr(settings, 'ALPHA_VANTAGE_API_KEY', '') or '').strip()
    if not key:
        raise AlphaVantageError(
            'ALPHA_VANTAGE_API_KEY is required. Get a key at https://www.alphavantage.co/support/#api-key '
            'and add it to backend/.env'
        )
    return key


def _throttle():
    """Respect Alpha Vantage free tier (~5 calls/min)."""
    delay = getattr(settings, 'ALPHA_VANTAGE_REQUEST_DELAY_SECONDS', 12)
    lock_key = 'av:last_request_ts'
    last = cache.get(lock_key)
    if last is not None:
        elapsed = time.time() - last
        if elapsed < delay:
            time.sleep(delay - elapsed)
    cache.set(lock_key, time.time(), 120)


def _request(params):
    _throttle()
    params = dict(params)
    params['apikey'] = _api_key()
    try:
        with httpx.Client(timeout=25) as client:
            response = client.get(BASE_URL, params=params)
    except httpx.HTTPError as exc:
        raise AlphaVantageError(f'Alpha Vantage connection failed: {exc}') from exc

    if response.status_code == 429:
        raise AlphaVantageError('Alpha Vantage rate limit exceeded. Wait a minute or upgrade your plan.')

    try:
        data = response.json()
    except ValueError as exc:
        raise AlphaVantageError('Invalid Alpha Vantage response.') from exc

    if isinstance(data, dict):
        if data.get('Error Message'):
            raise AlphaVantageError(str(data['Error Message']))
        note = data.get('Note') or data.get('Information')
        if note and 'frequency' in str(note).lower():
            raise AlphaVantageError(str(note))

    return data


def symbol_candidates(nse_symbol):
    """Alpha Vantage formats for Indian NSE tickers (BSE suffix + NSE: prefix)."""
    sym = (nse_symbol or '').upper().strip()
    if not sym or sym.startswith('^'):
        return []
    if sym in INDEX_YAHOO_SYMBOLS:
        return []
    return [f'NSE:{sym}', f'{sym}.BSE', f'{sym}.NS']


def _cache_seconds():
    return getattr(settings, 'ALPHA_VANTAGE_QUOTE_CACHE_SECONDS', 120)


def resolve_av_symbol(nse_symbol):
    """Resolve and cache the Alpha Vantage symbol that returns data for an NSE ticker."""
    sym = (nse_symbol or '').upper().strip()
    cache_key = f'av:resolved:{sym}'
    resolved = cache.get(cache_key)
    if resolved:
        return resolved

    for candidate in symbol_candidates(sym):
        try:
            data = _request({'function': 'GLOBAL_QUOTE', 'symbol': candidate})
        except AlphaVantageError:
            continue
        gq = data.get('Global Quote') or {}
        if gq.get('05. price'):
            cache.set(cache_key, candidate, 86400 * 7)
            return candidate

    try:
        search = _request({'function': 'SYMBOL_SEARCH', 'keywords': sym})
        for match in search.get('bestMatches') or []:
            region = (match.get('4. region') or '').lower()
            av_sym = match.get('1. symbol') or ''
            if 'india' not in region or not av_sym:
                continue
            try:
                data = _request({'function': 'GLOBAL_QUOTE', 'symbol': av_sym})
                gq = data.get('Global Quote') or {}
                if gq.get('05. price'):
                    cache.set(cache_key, av_sym, 86400 * 7)
                    return av_sym
            except AlphaVantageError:
                continue
    except AlphaVantageError as exc:
        logger.debug('AV symbol search failed for %s: %s', sym, exc)

    return None


def _parse_global_quote(data):
    gq = data.get('Global Quote') or {}
    price_raw = gq.get('05. price')
    if not price_raw:
        return None

    ltp = float(price_raw)
    prev_raw = gq.get('08. previous close')
    prev = float(prev_raw) if prev_raw not in (None, '') else ltp

    change_raw = gq.get('09. change')
    if change_raw not in (None, ''):
        change = float(change_raw)
    else:
        change = ltp - prev

    pct_raw = gq.get('10. change percent') or ''
    if isinstance(pct_raw, str) and pct_raw.endswith('%'):
        pct_raw = pct_raw[:-1]
    change_pct = float(pct_raw) if pct_raw not in (None, '') else ((change / prev * 100) if prev else 0)

    volume_raw = gq.get('06. volume') or 0
    try:
        volume = int(float(volume_raw))
    except (TypeError, ValueError):
        volume = 0

    return {
        'ltp': ltp,
        'change': change,
        'change_percent': change_pct,
        'high': float(gq.get('03. high') or ltp),
        'low': float(gq.get('04. low') or ltp),
        'open': float(gq.get('02. open') or ltp),
        'previous_close': prev,
        'volume': volume,
        'timestamp': gq.get('07. latest trading day'),
    }


def get_quote(nse_symbol):
    sym = (nse_symbol or '').upper().strip()
    cache_key = f'av:quote:{sym}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    av_symbol = resolve_av_symbol(sym)
    if not av_symbol:
        return None

    try:
        data = _request({'function': 'GLOBAL_QUOTE', 'symbol': av_symbol})
    except AlphaVantageError:
        return None

    quote = _parse_global_quote(data)
    if quote:
        cache.set(cache_key, quote, _cache_seconds())
    return quote


def get_candles(nse_symbol, resolution='D', days=90):
    sym = (nse_symbol or '').upper().strip()
    cache_key = f'av:candles:{sym}:{resolution}:{days}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    av_symbol = resolve_av_symbol(sym)
    if not av_symbol:
        return []

    if resolution in ('5', '15', '30', '60'):
        interval_map = {'5': '5min', '15': '15min', '30': '30min', '60': '60min'}
        params = {
            'function': 'TIME_SERIES_INTRADAY',
            'symbol': av_symbol,
            'interval': interval_map.get(resolution, '60min'),
            'outputsize': 'compact',
        }
        series_key = f'Time Series ({interval_map.get(resolution, "60min")})'
    else:
        params = {
            'function': 'TIME_SERIES_DAILY',
            'symbol': av_symbol,
            'outputsize': 'compact' if days <= 120 else 'full',
        }
        series_key = 'Time Series (Daily)'

    try:
        data = _request(params)
    except AlphaVantageError as exc:
        logger.warning('AV candles failed for %s: %s', sym, exc)
        return []

    series = data.get(series_key) or {}
    candles = []
    for ts_str, row in series.items():
        try:
            if resolution in ('5', '15', '30', '60'):
                dt = datetime.strptime(ts_str, '%Y-%m-%d %H:%M:%S').replace(tzinfo=dt_timezone.utc)
                unix_ts = int(dt.timestamp())
            else:
                dt = datetime.strptime(ts_str, '%Y-%m-%d').replace(tzinfo=dt_timezone.utc)
                unix_ts = int(dt.timestamp())
            candles.append(
                {
                    'time': unix_ts,
                    'open': float(row['1. open']),
                    'high': float(row['2. high']),
                    'low': float(row['3. low']),
                    'close': float(row['4. close']),
                    'volume': int(float(row.get('5. volume') or 0)),
                }
            )
        except (KeyError, ValueError):
            continue

    candles.sort(key=lambda c: c['time'])
    if days and resolution == 'D':
        cutoff = int(time.time()) - days * 86400
        candles = [c for c in candles if c['time'] >= cutoff]

    cache.set(cache_key, candles, 600)
    return candles


def get_overview(nse_symbol):
    sym = (nse_symbol or '').upper().strip()
    cache_key = f'av:overview:{sym}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    av_symbol = resolve_av_symbol(sym)
    if not av_symbol:
        return {}

    try:
        data = _request({'function': 'OVERVIEW', 'symbol': av_symbol})
    except AlphaVantageError:
        return {}

    if not data or not data.get('Symbol'):
        return {}

    def _f(key):
        val = data.get(key)
        if val in (None, '', 'None', '-'):
            return 0
        try:
            return float(val)
        except (TypeError, ValueError):
            return 0

    market_cap = _f('MarketCapitalization')
    overview = {
        'name': data.get('Name') or sym,
        'sector': data.get('Sector') or data.get('Industry') or 'General',
        'exchange': data.get('Exchange') or 'NSE',
        'pe': _f('PERatio'),
        'eps': _f('EPS'),
        'roe': _f('ReturnOnEquityTTM') * (100 if abs(_f('ReturnOnEquityTTM')) < 1 else 1),
        'debt_to_equity': _f('DebtToEquity'),
        'revenue_growth': _f('QuarterlyRevenueGrowthYOY') * 100,
        'market_cap_cr': market_cap / 1e7 if market_cap else 0,
        'week52_high': _f('52WeekHigh'),
        'week52_low': _f('52WeekLow'),
    }
    cache.set(cache_key, overview, 3600)
    return overview


def get_metrics(nse_symbol):
    ov = get_overview(nse_symbol)
    if not ov:
        return {}
    return {
        'pe': ov.get('pe', 0),
        'eps': ov.get('eps', 0),
        'roe': ov.get('roe', 0),
        'debt_to_equity': ov.get('debt_to_equity', 0),
        'revenue_growth': ov.get('revenue_growth', 0),
        'market_cap_cr': ov.get('market_cap_cr', 0),
        'week52_high': ov.get('week52_high', 0),
        'week52_low': ov.get('week52_low', 0),
    }


def get_profile(nse_symbol):
    ov = get_overview(nse_symbol)
    if not ov:
        sym = (nse_symbol or '').upper().strip()
        return {'name': sym, 'sector': 'General', 'exchange': 'NSE'}
    return {
        'name': ov.get('name') or nse_symbol,
        'sector': ov.get('sector') or 'General',
        'exchange': ov.get('exchange') or 'NSE',
    }
