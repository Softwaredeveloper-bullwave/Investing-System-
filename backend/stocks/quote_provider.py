"""Unified market quote provider — Kotak Neo primary, Finnhub/Yahoo fallback."""

import logging

from django.conf import settings

from .alphavantage_client import AlphaVantageError, INDEX_YAHOO_SYMBOLS, get_candles as av_candles
from .alphavantage_client import get_metrics as av_metrics
from .alphavantage_client import get_profile as av_profile
from .alphavantage_client import get_quote as av_quote
from .finnhub_client import FinnhubError, INDEX_SYMBOLS, get_candles as fh_candles
from .finnhub_client import get_dividends, get_metrics as fh_metrics
from .finnhub_client import get_profile as fh_profile
from .finnhub_client import get_quote as fh_quote

logger = logging.getLogger('bullwave.market')

MarketDataError = FinnhubError


def _kotak_available():
    from .kotak_neo_client import is_configured, kotak_auth_ok
    return is_configured() and kotak_auth_ok()


def _finnhub_available():
    return bool((getattr(settings, 'FINNHUB_API_KEY', '') or '').strip())


def _alphavantage_available():
    return bool((getattr(settings, 'ALPHA_VANTAGE_API_KEY', '') or '').strip())


def active_provider():
    explicit = (getattr(settings, 'MARKET_DATA_PROVIDER', 'auto') or 'auto').lower().strip()
    if _kotak_available() and explicit in ('auto', 'kotak_neo'):
        return 'kotak_neo'
    if explicit not in ('auto', 'kotak_neo', ''):
        return explicit
    if _alphavantage_available():
        return 'alphavantage'
    if _finnhub_available():
        return 'finnhub'
    return 'yahoo'


def provider_label():
    labels = {
        'kotak_neo': 'Kotak Neo',
        'alphavantage': 'Alpha Vantage',
        'finnhub': 'Finnhub',
        'yahoo': 'Yahoo Finance',
    }
    effective = active_provider()
    label = labels.get(effective, effective)
    from .kotak_neo_client import is_configured, kotak_auth_ok

    if (
        (getattr(settings, 'MARKET_DATA_PROVIDER', '') or '').lower().strip() == 'kotak_neo'
        and is_configured()
        and not kotak_auth_ok()
        and effective != 'kotak_neo'
    ):
        return f'{label} (fix Kotak Access Token for live broker feed)'
    return label


def _is_index_symbol(symbol):
    sym = (symbol or '').upper().strip()
    return sym.startswith('^') or sym in INDEX_SYMBOLS or sym in INDEX_YAHOO_SYMBOLS


def _yahoo_symbol(symbol):
    sym = (symbol or '').upper().strip()
    from .kotak_neo_client import SYMBOL_OVERRIDES
    from .market_symbols import FNO_INDICES

    sym = SYMBOL_OVERRIDES.get(sym, sym)
    if sym.startswith('^'):
        return sym
    if sym in FNO_INDICES:
        return FNO_INDICES[sym]
    if sym in INDEX_YAHOO_SYMBOLS:
        return INDEX_YAHOO_SYMBOLS[sym]
    if sym in INDEX_SYMBOLS:
        return INDEX_SYMBOLS[sym]
    return sym


def _yahoo_quote(symbol):
    from .yahoo_client import fetch_quote

    try:
        yahoo = fetch_quote(_yahoo_symbol(symbol))
        if not yahoo:
            return None
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
            'name': yahoo.get('name') or '',
        }
    except Exception as exc:
        logger.debug('Yahoo quote failed for %s: %s', symbol, exc)
        return None


def _enrich_volume(quote, symbol):
    if quote and not quote.get('volume'):
        yahoo = _yahoo_quote(symbol)
        if yahoo and yahoo.get('volume'):
            quote['volume'] = yahoo['volume']
    return quote


def _kotak_quote(symbol):
    from .kotak_neo_client import KotakNeoError, get_quote as kn_quote

    try:
        return kn_quote(symbol)
    except KotakNeoError as exc:
        logger.warning('Kotak Neo quote failed for %s: %s', symbol, exc)
        return None


def get_quote(symbol):
    sym = (symbol or '').upper().strip()
    provider = active_provider()

    if provider == 'kotak_neo' and _kotak_available():
        if sym in INDEX_SYMBOLS:
            from .kotak_neo_client import get_index_quote

            quote = get_index_quote(sym)
            if quote:
                return quote
        else:
            quote = _kotak_quote(sym)
            if quote:
                return quote

    if _is_index_symbol(sym):
        return _yahoo_quote(sym)

    if _finnhub_available():
        try:
            quote = fh_quote(sym)
            if quote:
                return _enrich_volume(quote, sym)
        except FinnhubError as exc:
            logger.debug('Finnhub quote failed for %s: %s', sym, exc)

    if provider == 'alphavantage' and _alphavantage_available():
        try:
            quote = av_quote(sym)
            if quote:
                return _enrich_volume(quote, sym)
        except AlphaVantageError as exc:
            logger.warning('Alpha Vantage quote failed for %s: %s', sym, exc)

    return _yahoo_quote(sym)


def get_quote_with_fallback(symbol):
    return get_quote(symbol)


def get_candles(symbol, resolution='D', days=90):
    sym = (symbol or '').upper().strip()

    if _finnhub_available():
        try:
            candles = fh_candles(sym, resolution=resolution, days=days)
            if candles:
                return candles
        except FinnhubError:
            pass

    if _alphavantage_available() and not _is_index_symbol(sym):
        try:
            candles = av_candles(sym, resolution=resolution, days=days)
            if candles:
                return candles
        except AlphaVantageError:
            pass

    return _yahoo_candles(sym, days, resolution)


def _yahoo_candles(symbol, days=90, resolution='D'):
    import yfinance as yf

    ticker = _yahoo_symbol(symbol)
    if not ticker.startswith('^') and not ticker.endswith('.NS'):
        ticker = f'{ticker}.NS'
    try:
        t = yf.Ticker(ticker)
        intraday = {
            '1': ('1m', 7),
            '5': ('5m', 60),
            '15': ('15m', 60),
            '30': ('30m', 60),
            '60': ('60m', 60),
        }
        if resolution in intraday:
            yf_interval, max_days = intraday[resolution]
            period = min(days, max_days)
            hist = t.history(period=f'{period}d', interval=yf_interval)
        else:
            hist = t.history(period=f'{min(days, 365)}d', interval='1d')
        candles = []
        for idx, row in hist.iterrows():
            candles.append(
                {
                    'time': int(idx.timestamp()),
                    'open': float(row['Open']),
                    'high': float(row['High']),
                    'low': float(row['Low']),
                    'close': float(row['Close']),
                    'volume': int(row['Volume']),
                }
            )
        return candles
    except Exception as exc:
        logger.debug('Yahoo candles failed for %s: %s', symbol, exc)
        return []


def get_metrics(symbol):
    sym = (symbol or '').upper().strip()

    if _finnhub_available():
        try:
            return fh_metrics(sym)
        except FinnhubError:
            pass

    if _alphavantage_available() and not _is_index_symbol(sym):
        try:
            metrics = av_metrics(sym)
            if metrics:
                return metrics
        except AlphaVantageError:
            pass

    from .yahoo_client import fetch_quote

    full = fetch_quote(_yahoo_symbol(sym))
    if full:
        return {
            'pe': full.get('pe', 0),
            'eps': full.get('eps', 0),
            'roe': full.get('roe', 0),
            'debt_to_equity': full.get('debt_to_equity', 0),
            'revenue_growth': full.get('revenue_growth', 0),
            'market_cap_cr': full.get('market_cap_cr', 0),
            'week52_high': full.get('week52_high', 0),
            'week52_low': full.get('week52_low', 0),
        }
    return {}


def get_profile(symbol):
    sym = (symbol or '').upper().strip()

    if _finnhub_available():
        try:
            return fh_profile(sym)
        except FinnhubError:
            pass

    if _alphavantage_available() and not _is_index_symbol(sym):
        try:
            profile = av_profile(sym)
            if profile.get('name') and profile['name'] != sym:
                return profile
        except AlphaVantageError:
            pass

    from .yahoo_client import fetch_quote

    full = fetch_quote(_yahoo_symbol(sym))
    if full:
        return {
            'name': full.get('name') or sym,
            'sector': full.get('sector') or 'General',
            'exchange': 'NSE',
        }
    return {'name': sym, 'sector': 'General', 'exchange': 'NSE'}


__all__ = [
    'MarketDataError',
    'FinnhubError',
    'get_quote',
    'get_quote_with_fallback',
    'get_candles',
    'get_metrics',
    'get_profile',
    'get_dividends',
    'active_provider',
    'provider_label',
    'INDEX_SYMBOLS',
]
