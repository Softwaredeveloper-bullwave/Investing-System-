"""Kotak Neo Trade API v2 — real-time NSE/BSE quotes (official broker feed)."""

import csv
import io
import logging
import threading
import urllib.parse
from datetime import date, timedelta, datetime, timezone as dt_timezone

import httpx
from django.conf import settings
from django.core.cache import cache

logger = logging.getLogger('bullwave.market')

DEFAULT_BASE_URL = 'https://mis.kotaksecurities.com'
PUBLIC_SCRIP_BASE = 'https://lapi.kotaksecurities.com/wso2-scripmaster/v1/prod'
QUOTES_PATH = '/script-details/1.0/quotes/neosymbol/{symbols}/{quote_type}'
SCRIP_MASTER_PATH = '/script-details/1.0/masterscrip/file-paths'
SCRIP_CACHE_KEY = 'kotak:scrip:nse_cm:v2'
AUTH_FAILED_KEY = 'kotak:auth_failed'

KOTAK_INDEX_TOKENS = {
    'NIFTY50': ('nse_cm', 'Nifty 50'),
    'BANKNIFTY': ('nse_cm', 'Nifty Bank'),
    'SENSEX': ('bse_cm', 'SENSEX'),
    'NIFTY': ('nse_cm', 'Nifty 50'),
}

SYMBOL_OVERRIDES = {
    'M&M': 'M&M',
    'TATAMOTORS': 'TMPV',
}

_scrip_lock = threading.Lock()
_scrip_loading = False


class KotakNeoError(Exception):
    pass


def _access_token():
    token = _normalize_access_token(
        (getattr(settings, 'KOTAK_NEO_ACCESS_TOKEN', '') or '').strip()
    )
    if not token:
        raise KotakNeoError(
            'KOTAK_NEO_ACCESS_TOKEN is required. Kotak Neo app → More → TradeAPI → '
            'API Dashboard → copy **Access Token** (not Consumer Key) → backend/.env'
        )
    return token


def _normalize_access_token(token):
    """Fix common copy-paste issues (trailing space, extra character in UUID)."""
    token = (token or '').strip().strip('"').strip("'")
    parts = token.split('-')
    if len(parts) == 5 and len(parts[4]) == 13 and parts[4][-1].isdigit():
        token = '-'.join(parts[:4] + [parts[4][:12]])
    return token


def _base_url():
    return (getattr(settings, 'KOTAK_NEO_BASE_URL', '') or DEFAULT_BASE_URL).rstrip('/')


def _auth_failed_message(status_code, body):
    body_lower = (body or '').lower()
    if 'consumer key' in body_lower and 'invalid' in body_lower:
        return (
            'Kotak Neo consumer key is invalid or expired. Kotak Neo app → More → '
            'TradeAPI → API Dashboard → regenerate your token and update '
            'KOTAK_NEO_ACCESS_TOKEN in backend/.env'
        )
    if 'consumer key' in body_lower:
        return (
            'Invalid Kotak credential: use the token from TradeAPI → API Dashboard '
            '(consumer key) in KOTAK_NEO_ACCESS_TOKEN.'
        )
    if status_code in (401, 403, 424):
        return (
            'Kotak Neo access token is invalid or expired. Regenerate **Access Token** from '
            'Kotak Neo → TradeAPI → API Dashboard and update KOTAK_NEO_ACCESS_TOKEN in .env'
        )
    return f'Kotak Neo error ({status_code}): {(body or "")[:200]}'


def _mark_auth_failed(reason):
    cache.set(AUTH_FAILED_KEY, reason, 900)
    logger.error('Kotak Neo disabled for 15 min: %s', reason)


def kotak_auth_ok():
    if not is_configured():
        return False
    return cache.get(AUTH_FAILED_KEY) is None


def _cache_seconds():
    return getattr(settings, 'KOTAK_NEO_QUOTE_CACHE_SECONDS', 15)


def _quote_cache_key(key):
    return f'kotak:quote:{key.upper().replace(" ", "_")}'


def _is_fault(payload):
    return isinstance(payload, dict) and 'fault' in payload


def _auth_headers():
    token = _access_token()
    return {
        # Kotak Neo v2 SDK: plain consumer key in Authorization (no Bearer prefix).
        'Authorization': token,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
    }


def _request(method, path, params=None):
    if not kotak_auth_ok():
        reason = cache.get(AUTH_FAILED_KEY) or 'Kotak Neo auth previously failed'
        raise KotakNeoError(reason)

    url = f'{_base_url()}{path}'
    try:
        with httpx.Client(timeout=30) as client:
            response = client.request(
                method, url, headers=_auth_headers(), params=params
            )
    except httpx.HTTPError as exc:
        raise KotakNeoError(f'Kotak Neo connection failed: {exc}') from exc

    if response.status_code in (401, 403, 424):
        msg = _auth_failed_message(response.status_code, response.text)
        _mark_auth_failed(msg)
        raise KotakNeoError(msg)
    if response.status_code == 429:
        raise KotakNeoError('Kotak Neo rate limit. Wait a moment and retry.')
    if response.status_code >= 400:
        raise KotakNeoError(_auth_failed_message(response.status_code, response.text))

    try:
        payload = response.json()
    except ValueError as exc:
        raise KotakNeoError('Invalid JSON from Kotak Neo.') from exc

    if _is_fault(payload):
        fault = payload.get('fault') or {}
        msg = fault.get('message') or fault.get('description') or str(fault)
        if '401' in str(fault.get('code', '')) or 'credential' in msg.lower() or 'invalid' in msg.lower():
            auth_msg = _auth_failed_message(response.status_code, msg)
            _mark_auth_failed(auth_msg)
            raise KotakNeoError(auth_msg)
        raise KotakNeoError(f'Kotak Neo API fault: {msg}')

    return payload


def _trading_symbol(nse_symbol):
    sym = (nse_symbol or '').upper().strip()
    return SYMBOL_OVERRIDES.get(sym, sym)


def _parse_scrip_csv(text):
    candidates = {}
    reader = csv.DictReader(io.StringIO(text))
    for row in reader:
        token = (row.get('pSymbol') or '').strip()
        if not token or not token.isdigit():
            continue

        trd = (row.get('pTrdSymbol') or '').strip().upper()
        name = (row.get('pSymbolName') or '').strip().upper()

        if trd.endswith('-BE') or trd.endswith('-BL') or trd.endswith('-BZ'):
            priority = 1
        elif trd.endswith('-EQ') or trd.endswith('-EQN'):
            priority = 3
        elif trd:
            priority = 2
        else:
            priority = 1

        keys = set()
        if trd:
            keys.add(trd)
            keys.add(trd.split('-')[0])
        if name:
            keys.add(name)

        for key in keys:
            if not key:
                continue
            prev = candidates.get(key)
            if not prev or priority >= prev[1]:
                candidates[key] = (token, priority)

    return {key: val[0] for key, val in candidates.items()}


def _download_public_scrip_csv():
    """Kotak publishes NSE scrip CSV publicly — no API token needed for symbol mapping."""
    for days_ago in range(8):
        day = (date.today() - timedelta(days=days_ago)).isoformat()
        url = f'{PUBLIC_SCRIP_BASE}/{day}/transformed/nse_cm.csv'
        try:
            with httpx.Client(timeout=120) as client:
                response = client.get(url)
            if response.status_code == 200 and len(response.text) > 1000:
                return response.text
        except httpx.HTTPError as exc:
            logger.debug('Public scrip CSV %s failed: %s', day, exc)
    return None


def _download_scrip_via_api():
    if not is_configured() or not kotak_auth_ok():
        return None
    try:
        data = _request('GET', SCRIP_MASTER_PATH)
    except KotakNeoError:
        return None

    files = None
    if isinstance(data.get('data'), dict):
        files = data['data'].get('filesPaths')
    if not files:
        files = data.get('filesPaths') or []

    nse_url = next((u for u in files if 'nse_cm' in str(u).lower()), None)
    if not nse_url:
        return None

    try:
        with httpx.Client(timeout=120) as client:
            response = client.get(nse_url)
        response.raise_for_status()
        return response.text
    except httpx.HTTPError:
        return None


def _load_scrip_master(force=False):
    if not force:
        cached = cache.get(SCRIP_CACHE_KEY)
        if cached:
            return cached

    csv_text = _download_public_scrip_csv()
    source = 'public'
    if not csv_text:
        csv_text = _download_scrip_via_api()
        source = 'api'

    if not csv_text:
        logger.warning('Could not load Kotak NSE scrip master from public or API sources')
        return {}

    mapping = _parse_scrip_csv(csv_text)
    if mapping:
        cache.set(SCRIP_CACHE_KEY, mapping, 86400)
        logger.info('Kotak scrip master loaded (%s): %s NSE symbols', source, len(mapping))
    return mapping


def _scrip_map():
    mapping = _load_scrip_master()
    if not mapping:
        with _scrip_lock:
            mapping = _load_scrip_master(force=True)
    return mapping or {}


def warm_scrip_master(force=False):
    with _scrip_lock:
        if force:
            cache.delete(SCRIP_CACHE_KEY)
        mapping = _load_scrip_master(force=force)
    return len(mapping or {})


def _schedule_scrip_warm():
    global _scrip_loading
    if _scrip_loading:
        return

    def _task():
        global _scrip_loading
        _scrip_loading = True
        try:
            warm_scrip_master()
        finally:
            _scrip_loading = False

    threading.Thread(target=_task, daemon=True).start()


def _instrument_token(nse_symbol):
    sym = _trading_symbol(nse_symbol)
    master = _scrip_map()
    token = master.get(sym) or master.get(f'{sym}-EQ')
    if not token:
        for key, val in master.items():
            if key.startswith(sym) and ('-EQ' in key or '-' not in key):
                return val
    return token


def _parse_quote_item(item):
    if not isinstance(item, dict):
        return None

    def _num(*keys, default=0):
        for k in keys:
            val = item.get(k)
            if val not in (None, '', '-', 'None'):
                try:
                    return float(str(val).replace(',', '').replace('%', ''))
                except (TypeError, ValueError):
                    continue
        return default

    def _num_from_dict(d, *keys, default=0):
        if not isinstance(d, dict):
            return default
        for k in keys:
            val = d.get(k)
            if val not in (None, '', '-', 'None'):
                try:
                    return float(str(val).replace(',', '').replace('%', ''))
                except (TypeError, ValueError):
                    continue
        return default

    ohlc = item.get('ohlc') if isinstance(item.get('ohlc'), dict) else {}

    ltp = _num('last_traded_price', 'ltp', 'iv', 'LTP')
    if ltp <= 0:
        ltp = _num_from_dict(ohlc, 'close', default=0)
    if ltp <= 0:
        return None

    prev = _num('c', 'close', 'prev_day_close', 'ic', 'previous_close')
    if prev <= 0:
        prev = _num_from_dict(ohlc, 'close', default=0)
    if prev <= 0:
        prev = ltp - _num('change', 'cng')

    change = _num('change', 'cng')
    if change == 0 and prev:
        change = ltp - prev

    change_pct = _num('per_change', 'net_change_percentage', 'nc', 'change_percent')
    if change_pct == 0 and prev:
        change_pct = (change / prev * 100) if prev else 0

    name = (
        item.get('display_symbol')
        or item.get('trading_symbol')
        or item.get('ts')
        or item.get('pSymbol')
        or item.get('pTrdSymbol')
        or ''
    )

    open_px = _num('op', 'open', 'openingPrice')
    if open_px <= 0:
        open_px = _num_from_dict(ohlc, 'open', default=ltp)
    high = _num('h', 'high', 'highPrice')
    if high <= 0:
        high = _num_from_dict(ohlc, 'high', default=ltp)
    low = _num('lo', 'low', 'lowPrice')
    if low <= 0:
        low = _num_from_dict(ohlc, 'low', default=ltp)

    return {
        'ltp': ltp,
        'change': change,
        'change_percent': change_pct,
        'high': high,
        'low': low,
        'open': open_px,
        'previous_close': prev if prev > 0 else ltp - change,
        'volume': int(_num('last_volume', 'volume', 'v')),
        'timestamp': item.get('lstup_time') or item.get('last_traded_time') or item.get('ltt')
        or datetime.now(tz=dt_timezone.utc).isoformat(),
        'name': name,
        'instrument_token': str(item.get('exchange_token') or item.get('instrument_token') or ''),
    }


def _extract_quote_rows(payload):
    if isinstance(payload, list):
        return payload
    if not isinstance(payload, dict):
        return []

    if isinstance(payload.get('data'), list):
        return payload['data']
    if isinstance(payload.get('data'), dict):
        inner = payload['data']
        if isinstance(inner.get('data'), list):
            return inner['data']
        if isinstance(inner.get('quotes'), list):
            return inner['quotes']

    for key in ('quotes', 'result', 'fetched'):
        if isinstance(payload.get(key), list):
            return payload[key]

    return []


def _symbol_from_row(row, sym_to_token):
    inst = str(row.get('exchange_token') or row.get('instrument_token') or row.get('pToken') or '')
    if inst:
        for sym, token in sym_to_token.items():
            if str(token) == inst:
                return sym

    trd = (
        row.get('display_symbol')
        or row.get('trading_symbol')
        or row.get('ts')
        or row.get('pTrdSymbol')
        or ''
    ).upper()
    if trd:
        base = trd.split('-')[0]
        if base in sym_to_token:
            return base
        for sym in sym_to_token:
            if trd.startswith(sym):
                return sym
    return None


def get_quotes_batch(symbols, quote_type='all', segment='nse_cm', raw_tokens=False):
    """Fetch live quotes. Returns partial/empty dict on auth errors — never crashes callers."""
    if not symbols or not kotak_auth_ok():
        return {}

    if raw_tokens:
        uncached_keys = []
        uncached_raw = []
        results = {}
        for raw in symbols:
            ck = str(raw)
            hit = cache.get(_quote_cache_key(ck))
            if hit is not None:
                results[ck] = hit
            else:
                uncached_keys.append(ck)
                uncached_raw.append(str(raw))
        if not uncached_raw:
            return results
        sym_to_token = {k: k for k in uncached_keys}
        neo_parts = [f'{segment}|{raw}' for raw in uncached_raw]
    else:
        syms = [(s or '').upper().strip() for s in symbols if s]
        if not syms:
            return {}

        uncached = []
        results = {}
        for sym in syms:
            hit = cache.get(_quote_cache_key(sym))
            if hit is not None:
                results[sym] = hit
            else:
                uncached.append(sym)
        if not uncached:
            return results

        sym_to_token = {}
        neo_parts = []
        for sym in uncached:
            token = _instrument_token(sym)
            if not token:
                logger.debug('Kotak Neo: no instrument token for %s', sym)
                continue
            sym_to_token[sym] = token
            neo_parts.append(f'{segment}|{token}')

        uncached_keys = list(sym_to_token.keys())
        if not neo_parts:
            return results

    neo_str = ','.join(neo_parts)
    encoded = urllib.parse.quote(neo_str, safe='')
    path = QUOTES_PATH.format(symbols=encoded, quote_type=quote_type or 'all')

    try:
        payload = _request('GET', path)
    except KotakNeoError as exc:
        logger.warning('Kotak Neo quotes unavailable: %s', exc)
        return results

    rows = _extract_quote_rows(payload)

    for row in rows:
        quote = _parse_quote_item(row)
        if not quote:
            continue
        sym = _symbol_from_row(row, sym_to_token)
        if not sym and raw_tokens and len(uncached_keys) == 1:
            sym = uncached_keys[0]
        if sym:
            cache.set(_quote_cache_key(sym), quote, _cache_seconds())
            results[sym] = quote

    return results


def get_quote(nse_symbol, quote_type='all'):
    sym = (nse_symbol or '').upper().strip()
    if sym in KOTAK_INDEX_TOKENS:
        segment, token = KOTAK_INDEX_TOKENS[sym]
        batch = get_quotes_batch([token], quote_type=quote_type, segment=segment, raw_tokens=True)
        return batch.get(token)

    batch = get_quotes_batch([sym], quote_type=quote_type)
    return batch.get(sym)


def get_index_quote(index_id):
    if index_id not in KOTAK_INDEX_TOKENS:
        return None
    segment, token = KOTAK_INDEX_TOKENS[index_id]
    batch = get_quotes_batch([token], quote_type='all', segment=segment, raw_tokens=True)
    return batch.get(token)


def search_scrips(query, limit=30):
    q = (query or '').upper().strip()
    if len(q) < 1:
        return []
    master = _scrip_map()
    if not master:
        return []
    matches = sorted({sym.split('-')[0] for sym in master if q in sym})[:limit]
    return matches


def is_configured():
    return bool((getattr(settings, 'KOTAK_NEO_ACCESS_TOKEN', '') or '').strip())
