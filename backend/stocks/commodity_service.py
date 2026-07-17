"""Global commodity quotes — gold, silver, crude oil, etc. via Yahoo Finance."""

from __future__ import annotations

import logging
from concurrent.futures import ThreadPoolExecutor, as_completed

from django.utils import timezone

logger = logging.getLogger('bullwave.market')

COMMODITY_CATALOG = {
    'GOLD': {
        'name': 'Gold',
        'short_name': 'Gold',
        'category': 'Precious Metals',
        'unit': 'USD/oz',
        'currency': 'USD',
        'yahoo': 'GC=F',
        'icon': 'gold',
    },
    'SILVER': {
        'name': 'Silver',
        'short_name': 'Silver',
        'category': 'Precious Metals',
        'unit': 'USD/oz',
        'currency': 'USD',
        'yahoo': 'SI=F',
        'icon': 'silver',
    },
    'PLATINUM': {
        'name': 'Platinum',
        'short_name': 'Platinum',
        'category': 'Precious Metals',
        'unit': 'USD/oz',
        'currency': 'USD',
        'yahoo': 'PL=F',
        'icon': 'platinum',
    },
    'CRUDE_OIL': {
        'name': 'Crude Oil (WTI)',
        'short_name': 'Crude Oil',
        'category': 'Energy',
        'unit': 'USD/bbl',
        'currency': 'USD',
        'yahoo': 'CL=F',
        'icon': 'oil',
    },
    'BRENT_OIL': {
        'name': 'Brent Crude',
        'short_name': 'Brent',
        'category': 'Energy',
        'unit': 'USD/bbl',
        'currency': 'USD',
        'yahoo': 'BZ=F',
        'icon': 'oil',
    },
    'NATURAL_GAS': {
        'name': 'Natural Gas',
        'short_name': 'Nat. Gas',
        'category': 'Energy',
        'unit': 'USD/MMBtu',
        'currency': 'USD',
        'yahoo': 'NG=F',
        'icon': 'gas',
    },
    'COPPER': {
        'name': 'Copper',
        'short_name': 'Copper',
        'category': 'Industrial Metals',
        'unit': 'USD/lb',
        'currency': 'USD',
        'yahoo': 'HG=F',
        'icon': 'copper',
    },
    'ALUMINUM': {
        'name': 'Aluminum',
        'short_name': 'Aluminum',
        'category': 'Industrial Metals',
        'unit': 'USD/ton',
        'currency': 'USD',
        'yahoo': 'ALI=F',
        'icon': 'metal',
    },
}

# Fallback prices when Yahoo is unavailable (dev / offline).
_FALLBACK = {
    'GOLD': (3342.50, 18.40, 0.55),
    'SILVER': (38.72, 0.42, 1.10),
    'PLATINUM': (1024.00, -6.20, -0.60),
    'CRUDE_OIL': (78.45, 1.12, 1.45),
    'BRENT_OIL': (82.10, 0.95, 1.17),
    'NATURAL_GAS': (2.84, -0.06, -2.07),
    'COPPER': (4.52, 0.03, 0.67),
    'ALUMINUM': (2485.00, 12.00, 0.49),
}


def _quote_for_commodity(commodity_id: str, meta: dict) -> dict:
    from .yahoo_client import fetch_quote

    quote = None
    try:
        quote = fetch_quote(meta['yahoo'])
    except Exception as exc:
        logger.debug('Commodity quote skip %s: %s', commodity_id, exc)

    if quote:
        ltp = float(quote['ltp'])
        change = float(quote['change'])
        change_pct = float(quote['change_percent'])
    else:
        fb = _FALLBACK.get(commodity_id, (0, 0, 0))
        ltp, change, change_pct = fb

    return {
        'id': commodity_id,
        'name': meta['name'],
        'short_name': meta['short_name'],
        'category': meta['category'],
        'unit': meta['unit'],
        'currency': meta['currency'],
        'icon': meta['icon'],
        'ltp': round(ltp, 2),
        'change': round(change, 2),
        'change_percent': round(change_pct, 2),
        'high': round(float(quote.get('high', ltp)) if quote else ltp * 1.01, 2),
        'low': round(float(quote.get('low', ltp)) if quote else ltp * 0.99, 2),
        'previous_close': round(float(quote.get('previous_close', ltp - change)) if quote else ltp - change, 2),
    }


def get_commodity_quotes() -> list[dict]:
    rows = []
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {
            pool.submit(_quote_for_commodity, cid, meta): cid
            for cid, meta in COMMODITY_CATALOG.items()
        }
        for fut in as_completed(futures):
            try:
                rows.append(fut.result())
            except Exception as exc:
                logger.warning('Commodity fetch failed: %s', exc)

    order = {cid: i for i, cid in enumerate(COMMODITY_CATALOG)}
    rows.sort(key=lambda r: order.get(r['id'], 999))
    return rows


def get_commodity_snapshot() -> dict:
    from .commodity_trading_service import get_usd_inr_rate

    return {
        'commodities': get_commodity_quotes(),
        'updated_at': timezone.now().isoformat(),
        'provider': 'yahoo',
        'usd_inr_rate': float(get_usd_inr_rate()),
    }


def get_commodity_detail(commodity_id: str) -> dict | None:
    from .commodity_trading_service import get_usd_inr_rate

    meta = COMMODITY_CATALOG.get(commodity_id.upper())
    if not meta:
        return None
    row = _quote_for_commodity(commodity_id.upper(), meta)
    row['updated_at'] = timezone.now().isoformat()
    row['usd_inr_rate'] = float(get_usd_inr_rate())
    return row
