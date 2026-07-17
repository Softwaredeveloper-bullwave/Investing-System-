"""Fetch live NSE quotes via Yahoo Finance (free, no API key)."""

import logging
from datetime import date, timedelta

import yfinance as yf
from django.core.cache import cache

logger = logging.getLogger('bullwave.market')

QUOTE_CACHE_SECONDS = 600  # 10 minutes
DIVIDEND_CACHE_SECONDS = 3600


def _yahoo_ticker(nse_symbol):
    if nse_symbol.startswith('^'):
        return nse_symbol
    if '=' in nse_symbol:
        return nse_symbol
    return f'{nse_symbol}.NS'


def fetch_quote(nse_symbol):
    """Single symbol quote. nse_symbol can be RELIANCE or ^NSEI."""
    cache_key = f'yahoo_quote:{nse_symbol}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    ticker = _yahoo_ticker(nse_symbol)
    try:
        t = yf.Ticker(ticker)
        info = t.info or {}
        hist = t.history(period='5d', interval='1d')
    except Exception as exc:
        logger.warning('Yahoo quote failed for %s: %s', nse_symbol, exc)
        return None

    if hist.empty and not info.get('regularMarketPrice'):
        return None

    ltp = info.get('regularMarketPrice') or info.get('currentPrice')
    prev = info.get('regularMarketPreviousClose') or info.get('previousClose')
    if ltp is None and not hist.empty:
        ltp = float(hist['Close'].iloc[-1])
        prev = float(hist['Close'].iloc[-2]) if len(hist) > 1 else ltp
    if ltp is None:
        return None

    ltp = float(ltp)
    prev = float(prev or ltp)
    change = ltp - prev
    change_pct = (change / prev * 100) if prev else 0

    quote = {
        'symbol': nse_symbol.replace('^', ''),
        'name': info.get('longName') or info.get('shortName') or nse_symbol,
        'ltp': ltp,
        'change': change,
        'change_percent': change_pct,
        'open': float(info.get('regularMarketOpen') or info.get('open') or ltp),
        'high': float(info.get('regularMarketDayHigh') or info.get('dayHigh') or ltp),
        'low': float(info.get('regularMarketDayLow') or info.get('dayLow') or ltp),
        'previous_close': prev,
        'volume': int(info.get('regularMarketVolume') or info.get('volume') or 0),
        'market_cap_cr': float((info.get('marketCap') or 0) / 1e7),
        'pe': float(info.get('trailingPE') or 0),
        'eps': float(info.get('trailingEps') or 0),
        'week52_high': float(info.get('fiftyTwoWeekHigh') or ltp),
        'week52_low': float(info.get('fiftyTwoWeekLow') or ltp),
        'roe': float((info.get('returnOnEquity') or 0) * 100),
        'debt_to_equity': float(info.get('debtToEquity') or 0),
        'revenue_growth': float((info.get('revenueGrowth') or 0) * 100),
        'sector': info.get('sector') or 'General',
        'industry': info.get('industry') or '',
    }
    cache.set(cache_key, quote, QUOTE_CACHE_SECONDS)
    return quote


def fetch_batch_quotes(nse_symbols):
    """Fetch quotes for multiple NSE symbols (uses cache per symbol)."""
    results = {}
    for sym in nse_symbols:
        q = fetch_quote(sym)
        if q:
            results[sym] = q
    return results


def fetch_underlying_spot(symbol):
    """Spot price for index or stock (used by F&O chain)."""
    from .market_symbols import FNO_INDICES

    yahoo = FNO_INDICES.get(symbol.upper())
    if yahoo:
        q = fetch_quote(yahoo)
        return q['ltp'] if q else None
    q = fetch_quote(symbol.upper())
    return q['ltp'] if q else None


def fetch_dividends(nse_symbol):
    """Dividend history + estimated upcoming payout via Yahoo Finance."""
    symbol = nse_symbol.upper().strip()
    cache_key = f'yahoo_dividends:{symbol}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    rows = []
    try:
        t = yf.Ticker(_yahoo_ticker(symbol))
        divs = t.dividends
        if not divs.empty:
            for ts, amount in divs.tail(8).items():
                ex_date = ts.date() if hasattr(ts, 'date') else ts.to_pydatetime().date()
                amt = float(amount)
                if amt <= 0:
                    continue
                rows.append(
                    {
                        'amount_per_share': amt,
                        'ex_date': ex_date,
                        'payment_date': ex_date,
                    }
                )

        if not rows:
            info = t.info or {}
            rate = float(info.get('dividendRate') or info.get('trailingAnnualDividendRate') or 0)
            if rate > 0:
                upcoming = date.today() + timedelta(days=45)
                rows.append(
                    {
                        'amount_per_share': rate,
                        'ex_date': upcoming,
                        'payment_date': upcoming + timedelta(days=21),
                    }
                )
        elif rows:
            last = rows[-1]
            last_ex = last['ex_date']
            if last_ex < date.today():
                try:
                    next_ex = last_ex.replace(year=last_ex.year + 1)
                except ValueError:
                    next_ex = last_ex + timedelta(days=365)
                if next_ex > date.today():
                    rows.append(
                        {
                            'amount_per_share': last['amount_per_share'],
                            'ex_date': next_ex,
                            'payment_date': next_ex + timedelta(days=21),
                        }
                    )
    except Exception as exc:
        logger.warning('Yahoo dividends failed for %s: %s', symbol, exc)

    cache.set(cache_key, rows, DIVIDEND_CACHE_SECONDS)
    return rows
