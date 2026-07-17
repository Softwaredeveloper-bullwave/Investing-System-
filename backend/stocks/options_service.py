"""F&O option chain derived from live underlying prices (Finnhub spot + synthetic premiums)."""

import logging
import math
import uuid
from datetime import date, timedelta
from decimal import Decimal

from django.core.cache import cache
from django.utils import timezone

from .commodity_service import COMMODITY_CATALOG, get_commodity_detail
from .market_data_service import get_underlying_spot
from .market_symbols import FNO_INDICES, FNO_STOCKS, NIFTY_50
from .models import Stock

logger = logging.getLogger('bullwave.market')

OPTIONS_CACHE_SECONDS = 300

# Used when live market APIs are slow/unavailable so the chain still loads.
FALLBACK_SPOTS = {
    'NIFTY': 24500.0,
    'BANKNIFTY': 52000.0,
    'FINNIFTY': 23800.0,
    'SENSEX': 80500.0,
    'MIDCPNIFTY': 12850.0,
    'BANKEX': 58200.0,
}

COMMODITY_SYMBOLS = set(COMMODITY_CATALOG.keys())

COMMODITY_STRIKE_STEPS = {
    'GOLD': 50,
    'SILVER': 1,
    'PLATINUM': 20,
    'CRUDE_OIL': 2,
    'BRENT_OIL': 2,
    'NATURAL_GAS': 0.25,
    'COPPER': 0.05,
    'ALUMINUM': 25,
}

COMMODITY_FALLBACK_SPOTS = {
    'GOLD': 3342.50,
    'SILVER': 38.72,
    'PLATINUM': 1024.00,
    'CRUDE_OIL': 78.45,
    'BRENT_OIL': 82.10,
    'NATURAL_GAS': 2.84,
    'COPPER': 4.52,
    'ALUMINUM': 2485.00,
}


def _is_index(symbol):
    return symbol.upper() in FNO_INDICES


def _strike_step(spot, symbol):
    sym = symbol.upper()
    if sym in ('NIFTY', 'FINNIFTY', 'MIDCPNIFTY'):
        return 50
    if sym in ('BANKNIFTY', 'BANKEX'):
        return 100
    if sym == 'SENSEX':
        return 100
    if spot >= 5000:
        return 100
    if spot >= 2000:
        return 50
    if spot >= 1000:
        return 20
    if spot >= 500:
        return 10
    return 5


def _round_strike(spot, step):
    return round(spot / step) * step


def _expiry_weekday(symbol):
    """NSE F&O weekly expiry day (Mon=0 … Sun=6). Updated per NSE 2024 schedule."""
    sym = symbol.upper()
    if sym == 'BANKNIFTY':
        return 2  # Wednesday
    if sym in ('NIFTY', 'FINNIFTY', 'MIDCPNIFTY'):
        return 1  # Tuesday
    if sym in ('SENSEX', 'BANKEX'):
        return 3  # Thursday (BSE index F&O)
    return 3  # Thursday for stock F&O


def _next_expiries(count=4, symbol='NIFTY'):
    """Next weekly expiry dates per NSE F&O schedule for the symbol."""
    target = _expiry_weekday(symbol)
    today = date.today()
    expiries = []
    d = today
    while len(expiries) < count and (d - today).days <= 60:
        if d.weekday() == target and d >= today:
            expiries.append(d)
        d += timedelta(days=1)
    if not expiries:
        days_ahead = (target - today.weekday()) % 7 or 7
        expiries.append(today + timedelta(days=days_ahead))
    return expiries[:count]


def _build_contracts(symbol, spot, expiry, num_strikes=21):
    step = _strike_step(spot, symbol)
    atm = _round_strike(spot, step)
    half = num_strikes // 2
    strikes = [atm + (i - half) * step for i in range(num_strikes)]
    days = max((expiry - date.today()).days, 1)
    vol_factor = 0.018 if _is_index(symbol) else 0.025

    contracts = []
    for strike in strikes:
        if strike <= 0:
            continue
        moneyness = abs(spot - strike) / spot
        base_oi = int(800000 * math.exp(-moneyness * 6)) if _is_index(symbol) else int(120000 * math.exp(-moneyness * 5))
        for opt_type in ('CE', 'PE'):
            intrinsic_call = max(0.0, spot - strike)
            intrinsic_put = max(0.0, strike - spot)
            intrinsic = intrinsic_call if opt_type == 'CE' else intrinsic_put
            time_val = spot * vol_factor * math.sqrt(days / 365) * math.exp(-moneyness * 4)
            ltp = max(round(intrinsic + time_val, 2), 0.05)
            change = round(ltp * 0.02 * (1 if opt_type == 'CE' else -1), 2)
            contracts.append(
                {
                    'id': str(uuid.uuid4()),
                    'symbol': symbol.upper(),
                    'strike': Decimal(str(strike)),
                    'type': opt_type,
                    'ltp': Decimal(str(ltp)),
                    'change': Decimal(str(change)),
                    'oi': base_oi + (50000 if strike == atm else 0),
                    'volume': int(base_oi * 0.15),
                    'expiry': expiry,
                }
            )
    return contracts


def _resolve_spot(symbol, *, fast=False):
    """Live spot with DB/fallback defaults so F&O chain always loads."""
    symbol = symbol.upper()
    stock = Stock.objects.filter(symbol=symbol).first()
    if stock and stock.ltp:
        return float(stock.ltp), 'db_ltp'

    if not fast:
        spot = get_underlying_spot(symbol)
        if spot is not None and spot > 0:
            return float(spot), 'live'

    if symbol in FALLBACK_SPOTS:
        return FALLBACK_SPOTS[symbol], 'fallback_index'

    if stock and stock.ltp:
        return float(stock.ltp), 'db_ltp'

    return 1000.0, 'fallback_default'


def _is_commodity(symbol):
    return symbol.upper() in COMMODITY_SYMBOLS


def _commodity_strike_step(symbol, spot):
    sym = symbol.upper()
    if sym in COMMODITY_STRIKE_STEPS:
        return float(COMMODITY_STRIKE_STEPS[sym])
    if spot >= 1000:
        return 50
    if spot >= 100:
        return 10
    if spot >= 10:
        return 1
    return 0.25


def _resolve_commodity_spot(commodity_id):
    commodity_id = commodity_id.upper()
    quote = get_commodity_detail(commodity_id)
    if quote and float(quote.get('ltp', 0)) > 0:
        return float(quote['ltp']), 'commodity_live'
    return COMMODITY_FALLBACK_SPOTS.get(commodity_id, 100.0), 'commodity_fallback'


def get_commodity_option_chain(commodity_id, expiry=None, fast=False):
    """MCX-style commodity options chain (synthetic premiums from live spot)."""
    commodity_id = commodity_id.upper().strip()
    if commodity_id not in COMMODITY_CATALOG:
        return None

    cache_key = f'commodity_option_chain:v1:{commodity_id}:{expiry or "nearest"}'
    cached = cache.get(cache_key)
    if cached is not None and not fast:
        return cached

    spot, source = _resolve_commodity_spot(commodity_id)
    if spot <= 0:
        return None

    expiries = _next_expiries(4, symbol='GOLD')  # Friday weekly-style
    selected = expiry
    if selected:
        try:
            selected = date.fromisoformat(str(selected))
        except ValueError:
            selected = expiries[0]
    else:
        selected = expiries[0]

    step = _commodity_strike_step(commodity_id, spot)
    atm = round(spot / step) * step
    half = 10
    strikes = [atm + (i - half) * step for i in range(21)]
    days = max((selected - date.today()).days, 1)
    vol_factor = 0.022

    contracts = []
    for strike in strikes:
        if strike <= 0:
            continue
        moneyness = abs(spot - strike) / spot
        base_oi = int(250000 * math.exp(-moneyness * 5))
        for opt_type in ('CE', 'PE'):
            intrinsic_call = max(0.0, spot - strike)
            intrinsic_put = max(0.0, strike - spot)
            intrinsic = intrinsic_call if opt_type == 'CE' else intrinsic_put
            time_val = spot * vol_factor * math.sqrt(days / 365) * math.exp(-moneyness * 4)
            ltp = max(round(intrinsic + time_val, 2), 0.05)
            change = round(ltp * 0.02 * (1 if opt_type == 'CE' else -1), 2)
            contracts.append(
                {
                    'id': str(uuid.uuid4()),
                    'symbol': commodity_id,
                    'strike': Decimal(str(round(strike, 4))),
                    'type': opt_type,
                    'ltp': Decimal(str(ltp)),
                    'change': Decimal(str(change)),
                    'oi': base_oi + (30000 if abs(strike - atm) < step / 2 else 0),
                    'volume': int(base_oi * 0.12),
                    'expiry': selected,
                }
            )

    meta = COMMODITY_CATALOG[commodity_id]
    result = {
        'symbol': commodity_id,
        'name': meta['name'],
        'unit': meta['unit'],
        'currency': meta['currency'],
        'underlying_value': round(spot, 2),
        'expiry_dates': [e.isoformat() for e in expiries],
        'selected_expiry': selected.isoformat(),
        'contracts': contracts,
        'updated_at': timezone.now().isoformat(),
        'source': source,
        'asset_class': 'commodity',
    }
    if not fast:
        cache.set(cache_key, result, OPTIONS_CACHE_SECONDS)
    return result


def get_option_chain(symbol, expiry=None, fast=False):
    """
    Build F&O chain from live underlying (Finnhub, Yahoo fallback).
    Returns dict with metadata + contract list.
    """
    symbol = symbol.upper().strip()
    if _is_commodity(symbol):
        return get_commodity_option_chain(symbol, expiry=expiry, fast=fast)

    allowed = set(FNO_INDICES) | set(FNO_STOCKS) | set(NIFTY_50)
    if symbol not in allowed and not Stock.objects.filter(symbol=symbol).exists():
        return None

    cache_key = f'option_chain:v3:{symbol}:{expiry or "nearest"}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached
    if fast:
        spot, source = _resolve_spot(symbol, fast=True)
        expiries = _next_expiries(4, symbol=symbol)
        selected = expiries[0] if expiries else date.today()
        contracts = _build_contracts(symbol, spot, selected, num_strikes=11)
        return {
            'symbol': symbol,
            'underlying_value': round(spot, 2),
            'expiry_dates': [e.isoformat() for e in expiries],
            'selected_expiry': selected.isoformat(),
            'contracts': contracts,
            'updated_at': timezone.now().isoformat(),
            'source': f'{source}_fast',
        }

    spot, source = _resolve_spot(symbol, fast=False)
    if spot <= 0:
        return None

    expiries = _next_expiries(4, symbol=symbol)
    selected = expiry
    if selected:
        try:
            selected = date.fromisoformat(str(selected))
        except ValueError:
            selected = expiries[0]
    else:
        selected = expiries[0]

    contracts = _build_contracts(symbol, spot, selected)

    result = {
        'symbol': symbol,
        'underlying_value': round(spot, 2),
        'expiry_dates': [e.isoformat() for e in expiries],
        'selected_expiry': selected.isoformat(),
        'contracts': contracts,
        'updated_at': timezone.now().isoformat(),
        'source': source,
    }
    cache.set(cache_key, result, OPTIONS_CACHE_SECONDS)
    return result
