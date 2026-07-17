"""Finnhub.io client — real-time NSE quotes, candles, fundamentals (paid API key)."""

import logging
import time

import httpx
from django.conf import settings

logger = logging.getLogger('bullwave.market')

BASE_URL = 'https://finnhub.io/api/v1'

# NSE index symbols on Finnhub
INDEX_SYMBOLS = {
    'NIFTY50': '^NSEI',
    'NIFTY': '^NSEI',
    'SENSEX': '^BSESN',
    'BANKNIFTY': '^NSEBANK',
}


class FinnhubError(Exception):
    pass


def _api_key():
    key = (getattr(settings, 'FINNHUB_API_KEY', '') or '').strip()
    if not key:
        raise FinnhubError(
            'FINNHUB_API_KEY is required. Get a key at https://finnhub.io/register '
            'and add it to backend/.env'
        )
    return key


def _get(path, params=None):
    params = dict(params or {})
    params['token'] = _api_key()
    try:
        with httpx.Client(timeout=20) as client:
            response = client.get(f'{BASE_URL}{path}', params=params)
    except httpx.HTTPError as exc:
        raise FinnhubError(f'Finnhub connection failed: {exc}') from exc

    if response.status_code == 401:
        raise FinnhubError('Invalid FINNHUB_API_KEY. Check backend/.env')
    if response.status_code == 429:
        raise FinnhubError('Finnhub rate limit exceeded. Upgrade plan or wait a minute.')
    if response.is_error:
        raise FinnhubError(f'Finnhub error ({response.status_code}): {response.text[:200]}')

    return response.json()


def to_finnhub_symbol(nse_symbol):
    sym = (nse_symbol or '').upper().strip()
    if sym.startswith('^') or ':' in sym:
        return sym
    return f'{sym}.NS'


def from_finnhub_symbol(finnhub_symbol):
    sym = finnhub_symbol.upper()
    if sym.endswith('.NS'):
        return sym[:-3]
    return sym.replace('^', '')


def get_quote(nse_symbol):
    """
    Real-time quote. Returns dict with ltp, change, change_percent, high, low, open, previous_close, volume, timestamp.
    """
    data = _get('/quote', {'symbol': to_finnhub_symbol(nse_symbol)})
    if not data or data.get('c') in (None, 0):
        return None

    ltp = float(data['c'])
    prev = float(data.get('pc') or ltp)
    change = float(data.get('d') if data.get('d') is not None else ltp - prev)
    change_pct = float(data.get('dp') if data.get('dp') is not None else (change / prev * 100 if prev else 0))
    volume = 0

    return {
        'ltp': ltp,
        'change': change,
        'change_percent': change_pct,
        'high': float(data.get('h') or ltp),
        'low': float(data.get('l') or ltp),
        'open': float(data.get('o') or ltp),
        'previous_close': prev,
        'volume': volume,
        'timestamp': data.get('t'),
    }


def get_quote_with_fallback(nse_symbol):
    """Finnhub quote with Yahoo fallback for volume and missing data."""
    quote = get_quote(nse_symbol)
    if quote and quote.get('volume'):
        return quote
    if quote:
        try:
            from .yahoo_client import fetch_quote
            yahoo = fetch_quote(nse_symbol)
            if yahoo and yahoo.get('volume'):
                quote['volume'] = yahoo['volume']
                return quote
        except Exception:
            pass
        return quote
    try:
        from .yahoo_client import fetch_quote
        yahoo = fetch_quote(nse_symbol)
        if yahoo:
            return {
                'ltp': yahoo['ltp'],
                'change': yahoo['change'],
                'change_percent': yahoo['change_percent'],
                'high': yahoo['high'],
                'low': yahoo['low'],
                'open': yahoo['open'],
                'previous_close': yahoo['previous_close'],
                'volume': yahoo.get('volume') or 0,
                'timestamp': None,
            }
    except Exception:
        pass
    return None


def get_candles(nse_symbol, resolution='D', days=90):
    """OHLCV candles from Finnhub. resolution: 5, 60, D, W, M"""
    now = int(time.time())
    start = now - days * 86400
    data = _get(
        '/stock/candle',
        {
            'symbol': to_finnhub_symbol(nse_symbol),
            'resolution': resolution,
            'from': start,
            'to': now,
        },
    )
    if data.get('s') != 'ok':
        return []

    candles = []
    times = data.get('t') or []
    for i, ts in enumerate(times):
        candles.append(
            {
                'time': ts,
                'open': float(data['o'][i]),
                'high': float(data['h'][i]),
                'low': float(data['l'][i]),
                'close': float(data['c'][i]),
                'volume': int(data['v'][i]) if data.get('v') else 0,
            }
        )
    return candles


def get_metrics(nse_symbol):
    """Fundamental metrics (PE, ROE, etc.) when available."""
    try:
        data = _get('/stock/metric', {'symbol': to_finnhub_symbol(nse_symbol), 'metric': 'all'})
        metric = data.get('metric') or {}
        return {
            'pe': float(metric.get('peBasicExclExtraTTM') or metric.get('peTTM') or 0),
            'eps': float(metric.get('epsBasicExclExtraItemsTTM') or 0),
            'roe': float(metric.get('roeTTM') or 0) * (100 if abs(metric.get('roeTTM') or 0) < 1 else 1),
            'debt_to_equity': float(metric.get('totalDebt/totalEquityQuarterly') or 0),
            'revenue_growth': float(metric.get('revenueGrowthTTMYoy') or 0) * 100,
            'market_cap_cr': float(metric.get('marketCapitalization') or 0),
            'week52_high': float(metric.get('52WeekHigh') or 0),
            'week52_low': float(metric.get('52WeekLow') or 0),
        }
    except FinnhubError:
        return {}


def get_profile(nse_symbol):
    try:
        data = _get('/stock/profile2', {'symbol': to_finnhub_symbol(nse_symbol)})
        return {
            'name': data.get('name') or nse_symbol,
            'sector': data.get('finnhubIndustry') or data.get('gsector') or 'General',
            'exchange': data.get('exchange') or 'NSE',
        }
    except FinnhubError:
        return {'name': nse_symbol, 'sector': 'General', 'exchange': 'NSE'}


def get_dividends(nse_symbol, from_date=None, to_date=None):
    """Dividend history from Finnhub /stock/dividend2."""
    import time
    from datetime import date, timedelta

    params = {'symbol': to_finnhub_symbol(nse_symbol)}
    if from_date:
        params['from'] = str(from_date)
    else:
        params['from'] = str(date.today() - timedelta(days=730))
    if to_date:
        params['to'] = str(to_date)
    else:
        params['to'] = str(date.today() + timedelta(days=365))

    try:
        data = _get('/stock/dividend2', params)
    except FinnhubError:
        return []

    rows = []
    for item in data or []:
        amount = float(item.get('amount') or 0)
        if amount <= 0:
            continue
        ex_ts = item.get('exDate') or item.get('date')
        pay_ts = item.get('payDate') or ex_ts
        rows.append(
            {
                'amount_per_share': amount,
                'ex_date': _parse_finnhub_date(ex_ts),
                'payment_date': _parse_finnhub_date(pay_ts),
                'currency': item.get('currency', 'INR'),
            }
        )
    return rows


def _parse_finnhub_date(value):
    from datetime import date, datetime

    if not value:
        return date.today()
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value).date()
    try:
        return date.fromisoformat(str(value)[:10])
    except ValueError:
        return date.today()


def get_company_news(nse_symbol, limit=10):
    try:
        from datetime import date, timedelta
        data = _get(
            '/company-news',
            {
                'symbol': to_finnhub_symbol(nse_symbol),
                'from': str(date.today() - timedelta(days=7)),
                'to': str(date.today()),
            },
        )
        return (data or [])[:limit]
    except FinnhubError:
        return []
