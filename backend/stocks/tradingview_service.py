"""TradingView chart integration — symbol mapping and client config."""

from django.conf import settings

# NSE/BSE equity → TradingView symbol (EXCHANGE:SYMBOL)
NSE_SYMBOL_OVERRIDES = {
    'M&M': 'NSE:M&M',
}

# Commodity id → TradingView continuous symbol
COMMODITY_TV_SYMBOLS = {
    'GOLD': 'TVC:GOLD',
    'SILVER': 'TVC:SILVER',
    'PLATINUM': 'TVC:PLATINUM',
    'CRUDE_OIL': 'TVC:USOIL',
    'BRENT_OIL': 'TVC:UKOIL',
    'NATURAL_GAS': 'TVC:NATURALGAS',
    'COPPER': 'COMEX:HG1!',
    'ALUMINUM': 'TVC:ALUMINUM',
}

# App interval key → TradingView widget interval token
INTERVAL_MAP = {
    '1m': '1',
    '5m': '5',
    '30m': '30',
    '1h': '60',
    '1H': '60',
    '1d': 'D',
    '1D': 'D',
    '90d': 'D',
    '1M': 'M',
}


def resolve_stock_symbol(symbol: str, exchange: str = 'NSE') -> str:
    sym = (symbol or '').upper().strip()
    if sym in NSE_SYMBOL_OVERRIDES:
        return NSE_SYMBOL_OVERRIDES[sym]
    ex = (exchange or 'NSE').upper().strip()
    if ':' in sym:
        return sym
    return f'{ex}:{sym}'


def resolve_commodity_symbol(commodity_id: str) -> str:
    key = (commodity_id or '').upper().strip()
    return COMMODITY_TV_SYMBOLS.get(key, f'TVC:{key}')


def resolve_interval(interval: str) -> str:
    key = (interval or '1d').strip()
    return INTERVAL_MAP.get(key, INTERVAL_MAP.get(key.lower(), 'D'))


def tradingview_config() -> dict:
    api_key = (getattr(settings, 'TRADINGVIEW_API_KEY', '') or '').strip()
    library_url = (getattr(settings, 'TRADINGVIEW_CHARTING_LIBRARY_URL', '') or '').strip()
    udf_base = (getattr(settings, 'TRADINGVIEW_UDF_BASE_URL', '') or '').strip()
    default_exchange = (getattr(settings, 'TRADINGVIEW_DEFAULT_EXCHANGE', '') or 'NSE').strip()

    use_charting_library = bool(library_url)
    return {
        'enabled': True,
        'provider': 'charting_library' if use_charting_library else 'widget_embed',
        'apiKeyConfigured': bool(api_key),
        'chartingLibraryUrl': library_url,
        'udfBaseUrl': udf_base,
        'defaultExchange': default_exchange,
        'timezone': 'Asia/Kolkata',
        'theme': 'dark',
        'chartStyle': 'candles',
        'intervalMap': INTERVAL_MAP,
        'commoditySymbols': COMMODITY_TV_SYMBOLS,
    }
