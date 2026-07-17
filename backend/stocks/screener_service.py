"""Stock screener with live Finnhub fundamentals."""

from django.core.cache import cache
from django.db.models import Q

from .market_data_service import refresh_nifty50
from .market_symbols import NIFTY_50
from .models import Stock

SCREENER_CACHE_SECONDS = 60


def get_screener_results(
    sector=None,
    min_pe=None,
    max_pe=None,
    min_roe=None,
    max_de=None,
    sort='market_cap',
    limit=50,
):
    cache_key = f'screener:v3:{sector}:{min_pe}:{max_pe}:{min_roe}:{max_de}:{sort}:{limit}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached

    refresh_nifty50()

    qs = Stock.objects.filter(symbol__in=NIFTY_50)

    if sector and sector.lower() not in ('all', ''):
        qs = qs.filter(sector__iexact=sector)
    if min_pe is not None:
        qs = qs.filter(pe__gte=min_pe, pe__gt=0)
    if max_pe is not None:
        qs = qs.filter(Q(pe__lte=max_pe) | Q(pe=0))
    if min_roe is not None:
        qs = qs.filter(roe__gte=min_roe)
    if max_de is not None:
        qs = qs.filter(debt_to_equity__lte=max_de)

    sort_map = {
        'market_cap': '-market_cap_cr',
        'pe': 'pe',
        'roe': '-roe',
        'revenue_growth': '-revenue_growth',
        'change_percent': '-change_percent',
        'ltp': '-ltp',
    }
    results = list(qs.order_by(sort_map.get(sort, '-market_cap_cr'))[:limit])
    cache.set(cache_key, results, SCREENER_CACHE_SECONDS)
    return results


def get_screener_sectors():
    refresh_nifty50()
    return list(
        Stock.objects.filter(symbol__in=NIFTY_50)
        .values_list('sector', flat=True)
        .distinct()
        .order_by('sector')
    )
