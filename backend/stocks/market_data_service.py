"""Real-time market data — Kotak Neo primary, Finnhub/Yahoo fallback."""

import logging
import threading
from datetime import datetime, timezone as dt_timezone
from decimal import Decimal

from django.conf import settings
from django.core.cache import cache
from django.utils import timezone

from engagement.models import MarketIndex

from .market_symbols import FNO_INDICES, NIFTY_50, SECTOR_MAP
from .models import Stock, StockCandle
from .quote_provider import (
    FinnhubError,
    INDEX_SYMBOLS,
    active_provider,
    get_candles,
    get_metrics,
    get_profile,
    get_quote,
    get_quote_with_fallback,
    provider_label,
)

logger = logging.getLogger('bullwave.market')

SNAPSHOT_CACHE_KEY = 'market:snapshot:v1'
REFRESH_LOCK_KEY = 'market:refresh_lock'

INTERVAL_MAP = {
    '1m': ('1', StockCandle.Interval.M1, 2),
    '5m': ('5', StockCandle.Interval.M5, 5),
    '30m': ('30', StockCandle.Interval.M30, 30),
    '1h': ('60', StockCandle.Interval.H1, 30),
    '1d': ('D', StockCandle.Interval.D1, 60),
    '90d': ('D', StockCandle.Interval.D90, 180),
}


def _quote_cache_seconds():
    provider = active_provider()
    if provider == 'kotak_neo':
        return getattr(settings, 'KOTAK_NEO_QUOTE_CACHE_SECONDS', 15)
    if provider == 'alphavantage':
        return getattr(settings, 'ALPHA_VANTAGE_QUOTE_CACHE_SECONDS', 120)
    return getattr(settings, 'MARKET_QUOTE_CACHE_SECONDS', 30)


def _universe_cache_seconds():
    provider = active_provider()
    if provider == 'kotak_neo':
        return getattr(settings, 'KOTAK_NEO_UNIVERSE_CACHE_SECONDS', 15)
    return getattr(settings, 'MARKET_UNIVERSE_CACHE_SECONDS', 60)


def _normalize_sector(sector):
    return SECTOR_MAP.get(sector, sector or 'General')[:60]


def _stock_defaults(symbol, quote, profile=None, metrics=None):
    profile = profile or {}
    metrics = metrics or {}
    sector = _normalize_sector(profile.get('sector', 'General'))
    defaults = {
        'name': (profile.get('name') or quote.get('name') or symbol)[:120],
        'exchange': profile.get('exchange', 'NSE')[:10],
        'sector': sector,
        'ltp': Decimal(str(round(quote['ltp'], 2))),
        'change': Decimal(str(round(quote['change'], 2))),
        'change_percent': Decimal(str(round(quote['change_percent'], 2))),
        'open_price': Decimal(str(round(quote['open'], 2))),
        'high': Decimal(str(round(quote['high'], 2))),
        'low': Decimal(str(round(quote['low'], 2))),
        'previous_close': Decimal(str(round(quote['previous_close'], 2))),
        'volume': quote.get('volume') or 0,
    }
    if metrics:
        defaults.update(
            {
                'market_cap_cr': Decimal(str(round(metrics.get('market_cap_cr') or 0, 2))),
                'pe': Decimal(str(round(metrics.get('pe') or 0, 2))),
                'eps': Decimal(str(round(metrics.get('eps') or 0, 2))),
                'week52_high': Decimal(str(round(metrics.get('week52_high') or quote['high'], 2))),
                'week52_low': Decimal(str(round(metrics.get('week52_low') or quote['low'], 2))),
                'roe': Decimal(str(round(metrics.get('roe') or 0, 2))),
                'debt_to_equity': Decimal(str(round(metrics.get('debt_to_equity') or 0, 2))),
                'revenue_growth': Decimal(str(round(metrics.get('revenue_growth') or 0, 2))),
            }
        )
    return defaults


def upsert_stock_from_live(symbol, quote, profile=None, metrics=None):
    defaults = _stock_defaults(symbol, quote, profile, metrics)
    stock, _ = Stock.objects.update_or_create(symbol=symbol.upper(), defaults=defaults)
    return stock


_STOCK_LIVE_FIELDS = [
    'name', 'exchange', 'sector', 'ltp', 'change', 'change_percent',
    'open_price', 'high', 'low', 'previous_close', 'volume',
]


def refresh_stock(symbol, include_fundamentals=False):
    symbol = symbol.upper().strip()
    cache_key = f'live_stock:{symbol}:{"full" if include_fundamentals else "q"}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    quote = get_quote_with_fallback(symbol)
    if not quote:
        raise FinnhubError(f'No live quote for {symbol}')

    existing = Stock.objects.filter(symbol=symbol).first()
    profile = (
        {'name': existing.name, 'sector': existing.sector, 'exchange': existing.exchange}
        if existing
        else get_profile(symbol)
    )
    if quote.get('name') and not existing:
        profile['name'] = quote['name']

    metrics = get_metrics(symbol) if include_fundamentals else {}
    stock = upsert_stock_from_live(symbol, quote, profile, metrics)
    ttl = 3600 if include_fundamentals else _quote_cache_seconds()
    cache.set(cache_key, stock, ttl)
    return stock


def refresh_stocks(symbols, include_fundamentals=False):
    symbols = [s.upper().strip() for s in symbols if s]
    updated = []

    def _parallel_fetch(target_symbols):
        from concurrent.futures import ThreadPoolExecutor, as_completed

        fetched = []

        def _fetch(sym):
            try:
                return refresh_stock(sym, include_fundamentals=include_fundamentals)
            except FinnhubError as exc:
                logger.debug('Skip %s: %s', sym, exc)
                return None

        if not target_symbols:
            return fetched

        workers = min(8, max(2, len(target_symbols)))
        with ThreadPoolExecutor(max_workers=workers) as pool:
            futures = [pool.submit(_fetch, sym) for sym in target_symbols]
            for fut in as_completed(futures):
                stock = fut.result()
                if stock:
                    fetched.append(stock)
        return fetched

    prefer_kotak = not include_fundamentals and (
        (getattr(settings, 'MARKET_DATA_PROVIDER', 'auto') or 'auto').lower().strip() in ('auto', 'kotak_neo')
    )

    kotak_quotes = {}
    if prefer_kotak:
        from .kotak_neo_client import KotakNeoError, get_quotes_batch, is_configured, kotak_auth_ok

        if is_configured() and kotak_auth_ok():
            try:
                batch_size = getattr(settings, 'KOTAK_NEO_BATCH_SIZE', 50)
                for i in range(0, len(symbols), batch_size):
                    chunk = symbols[i : i + batch_size]
                    kotak_quotes.update(get_quotes_batch(chunk))
            except KotakNeoError as exc:
                logger.warning('Kotak Neo batch refresh failed: %s', exc)

        if kotak_quotes:
            existing = {s.symbol: s for s in Stock.objects.filter(symbol__in=symbols)}
            to_create = []
            to_update = []

            for sym in symbols:
                quote = kotak_quotes.get(sym)
                if not quote:
                    continue
                existing_stock = existing.get(sym)
                profile = (
                    {'name': existing_stock.name, 'sector': existing_stock.sector, 'exchange': existing_stock.exchange}
                    if existing_stock
                    else {'name': quote.get('name') or sym, 'sector': 'General', 'exchange': 'NSE'}
                )
                defaults = _stock_defaults(sym, quote, profile, {})
                if existing_stock:
                    for field, value in defaults.items():
                        setattr(existing_stock, field, value)
                    to_update.append(existing_stock)
                else:
                    to_create.append(Stock(symbol=sym, **defaults))

            if to_create:
                Stock.objects.bulk_create(to_create, ignore_conflicts=True)
            if to_update:
                Stock.objects.bulk_update(to_update, fields=_STOCK_LIVE_FIELDS)

            refreshed = Stock.objects.filter(symbol__in=[s for s in symbols if s in kotak_quotes])
            for stock in refreshed:
                cache.set(f'live_stock:{stock.symbol}:q', stock, _quote_cache_seconds())
                updated.append(stock)

        missing = [s for s in symbols if s not in kotak_quotes]
        if missing:
            logger.info('Fetching %s symbols via fallback providers', len(missing))
            updated.extend(_parallel_fetch(missing))
        return updated

    return _parallel_fetch(symbols)


def refresh_nifty50(force=False):
    cache_key = 'live_universe:nifty50'
    qs = _ordered_nifty50()
    if cache.get(cache_key) and qs.exists():
        return qs

    if qs.exists() and not force:
        schedule_background_refresh()
        return qs

    refresh_stocks(NIFTY_50, include_fundamentals=False)

    if active_provider() != 'kotak_neo' and active_provider() != 'alphavantage':
        if not cache.get('nifty50_fundamentals'):
            for sym in NIFTY_50:
                try:
                    refresh_stock(sym, include_fundamentals=True)
                except FinnhubError as exc:
                    logger.warning('Fundamentals skip %s: %s', sym, exc)
            cache.set('nifty50_fundamentals', True, 3600)

    cache.set(cache_key, True, _universe_cache_seconds())
    return _ordered_nifty50()


def _apply_index_quote(index_id, quote):
    if not quote:
        return None
    try:
        idx = MarketIndex.objects.get(id=index_id)
    except MarketIndex.DoesNotExist:
        return None

    idx.value = Decimal(str(round(quote['ltp'], 2)))
    idx.change = Decimal(str(round(quote['change'], 2)))
    idx.change_percent = Decimal(str(round(quote['change_percent'], 2)))
    idx.save(update_fields=['value', 'change', 'change_percent'])
    return idx


def refresh_index(index_id):
    quote = None
    if active_provider() == 'kotak_neo':
        from .kotak_neo_client import get_index_quote

        quote = get_index_quote(index_id)

    if not quote:
        yahoo_sym = INDEX_SYMBOLS.get(index_id)
        if yahoo_sym:
            quote = get_quote_with_fallback(yahoo_sym)

    return _apply_index_quote(index_id, quote)


def refresh_all_indices():
    if active_provider() == 'kotak_neo':
        from .kotak_neo_client import KOTAK_INDEX_TOKENS, KotakNeoError, get_quotes_batch

        refreshed = []
        nse_batch = []
        nse_ids = []
        for index_id in INDEX_SYMBOLS:
            if index_id not in KOTAK_INDEX_TOKENS:
                continue
            segment, token = KOTAK_INDEX_TOKENS[index_id]
            if segment == 'nse_cm':
                nse_batch.append(token)
                nse_ids.append((index_id, token))

        if nse_batch:
            try:
                quotes = get_quotes_batch(nse_batch, segment='nse_cm', raw_tokens=True)
            except KotakNeoError:
                quotes = {}
            for index_id, token in nse_ids:
                idx = _apply_index_quote(index_id, quotes.get(token))
                if idx:
                    refreshed.append(idx)

        refreshed_ids = {i.id for i in refreshed}
        for index_id in INDEX_SYMBOLS:
            if index_id in refreshed_ids:
                continue
            idx = refresh_index(index_id)
            if idx:
                refreshed.append(idx)
        return refreshed

    refreshed = []
    for index_id in INDEX_SYMBOLS:
        idx = refresh_index(index_id)
        if idx:
            refreshed.append(idx)
    return refreshed


def get_live_candles(symbol, interval='1d', fast=False):
    """Historical candles from Finnhub/Yahoo. Does not refresh live quote (too slow)."""
    symbol = symbol.upper()
    mapped = INTERVAL_MAP.get(interval)
    if mapped:
        resolution, db_interval, days = mapped
    else:
        resolution, db_interval, days = 'D', StockCandle.Interval.D1, 60

    cache_key = f'live_candles:{symbol}:{interval}'
    cached = cache.get(cache_key)
    if cached:
        return cached

    try:
        stock = Stock.objects.get(symbol=symbol)
    except Stock.DoesNotExist:
        raise Stock.DoesNotExist(f'Stock matching query does not exist: {symbol}')

    candle_limit = 180 if interval == '90d' else (90 if interval == '1d' else 120)
    db_candles = list(stock.candles.filter(interval=db_interval).order_by('time')[:candle_limit])
    if fast:
        return db_candles

    raw = get_candles(symbol, resolution=resolution, days=days)
    if not raw:
        if db_candles:
            cache.set(cache_key, db_candles, 300)
        return db_candles

    StockCandle.objects.filter(stock=stock, interval=db_interval).delete()
    batch = []
    for c in raw[-candle_limit:]:
        batch.append(
            StockCandle(
                stock=stock,
                time=datetime.fromtimestamp(c['time'], tz=dt_timezone.utc),
                open_price=Decimal(str(round(c['open'], 2))),
                high=Decimal(str(round(c['high'], 2))),
                low=Decimal(str(round(c['low'], 2))),
                close=Decimal(str(round(c['close'], 2))),
                volume=c['volume'],
                interval=db_interval,
            )
        )
    StockCandle.objects.bulk_create(batch)
    candles = list(stock.candles.filter(interval=db_interval).order_by('time'))
    cache.set(cache_key, candles, 300)
    return candles


def get_underlying_spot(symbol):
    symbol = symbol.upper()

    # F&O index symbols (NIFTY, BANKNIFTY, FINNIFTY) → Yahoo/Finnhub tickers
    if symbol in FNO_INDICES:
        quote = get_quote(FNO_INDICES[symbol])
        if quote:
            return quote['ltp']
        db_id = {'NIFTY': 'NIFTY50', 'BANKNIFTY': 'BANKNIFTY'}.get(symbol, symbol)
        try:
            return float(MarketIndex.objects.get(id=db_id).value)
        except MarketIndex.DoesNotExist:
            return None

    if symbol in INDEX_SYMBOLS:
        quote = get_quote(INDEX_SYMBOLS[symbol])
        if quote:
            return quote['ltp']
        try:
            idx = MarketIndex.objects.get(id=symbol)
            return float(idx.value)
        except MarketIndex.DoesNotExist:
            return None

    stock = Stock.objects.filter(symbol=symbol).first()
    if stock and stock.ltp:
        return float(stock.ltp)

    try:
        return float(refresh_stock(symbol).ltp)
    except FinnhubError:
        return None


def _ordered_nifty50():
    return Stock.objects.filter(symbol__in=NIFTY_50).order_by('-market_cap_cr')


def _db_indices():
    return list(MarketIndex.objects.filter(id__in=INDEX_SYMBOLS.keys()))


def _cache_snapshot(stocks, indices):
    cache.set(
        SNAPSHOT_CACHE_KEY,
        {
            'symbols': [s.symbol for s in stocks],
            'index_ids': [i.id for i in indices],
            'updated_at': timezone.now().isoformat(),
            'provider': provider_label(),
        },
        getattr(settings, 'MARKET_SNAPSHOT_CACHE_SECONDS', 15),
    )


def _snapshot_from_cache():
    meta = cache.get(SNAPSHOT_CACHE_KEY)
    if not meta:
        return None
    sym_order = {sym: i for i, sym in enumerate(meta['symbols'])}
    stocks = list(Stock.objects.filter(symbol__in=meta['symbols']))
    stocks.sort(key=lambda s: sym_order.get(s.symbol, 999))
    indices = list(MarketIndex.objects.filter(id__in=meta['index_ids']))
    if not stocks:
        return None
    return {
        'stocks': stocks,
        'indices': indices,
        'updated_at': meta['updated_at'],
        'provider': meta['provider'],
    }


def _full_market_refresh():
    try:
        refresh_stocks(NIFTY_50, include_fundamentals=False)
    except Exception as exc:
        logger.warning('Stock refresh error: %s', exc)
    try:
        indices = refresh_all_indices()
    except Exception as exc:
        logger.warning('Index refresh error: %s', exc)
        indices = _db_indices()
    stocks = list(_ordered_nifty50())
    if not stocks:
        raise FinnhubError('No market data available. Check KOTAK_NEO_ACCESS_TOKEN or fallback APIs.')
    _cache_snapshot(stocks, indices)
    cache.set('live_universe:nifty50', True, _universe_cache_seconds())
    return {
        'stocks': stocks,
        'indices': indices,
        'updated_at': timezone.now().isoformat(),
        'provider': provider_label(),
    }


def schedule_background_refresh():
    if cache.get(REFRESH_LOCK_KEY):
        return

    def _task():
        cache.set(REFRESH_LOCK_KEY, True, 60)
        try:
            _full_market_refresh()
        except Exception as exc:
            logger.warning('Background market refresh failed: %s', exc)
        finally:
            cache.delete(REFRESH_LOCK_KEY)

    threading.Thread(target=_task, daemon=True).start()


def get_market_snapshot(fast=False, force_refresh=False):
    if not force_refresh:
        cached = _snapshot_from_cache()
        if cached:
            return cached

    db_stocks = list(_ordered_nifty50())
    db_indices = _db_indices()

    if fast and db_stocks:
        schedule_background_refresh()
        return {
            'stocks': db_stocks,
            'indices': db_indices,
            'updated_at': timezone.now().isoformat(),
            'provider': provider_label(),
        }

    if db_stocks and not force_refresh:
        result_holder = {}

        def _worker():
            try:
                result_holder['snapshot'] = _full_market_refresh()
            except Exception as exc:
                result_holder['error'] = exc

        thread = threading.Thread(target=_worker, daemon=True)
        thread.start()
        max_wait = getattr(settings, 'MARKET_LIVE_MAX_WAIT_SECONDS', 4.0)
        thread.join(timeout=max_wait)

        if 'snapshot' in result_holder:
            return result_holder['snapshot']

        return {
            'stocks': db_stocks,
            'indices': db_indices,
            'updated_at': timezone.now().isoformat(),
            'provider': provider_label(),
        }

    if force_refresh:
        try:
            return _full_market_refresh()
        except Exception as exc:
            logger.warning('Force market refresh failed: %s', exc)
            if db_stocks:
                return {
                    'stocks': db_stocks,
                    'indices': db_indices,
                    'updated_at': timezone.now().isoformat(),
                    'provider': provider_label(),
                }
            raise FinnhubError(str(exc)) from exc

    return _full_market_refresh()
