"""Block deal and dark pool trackers."""

from __future__ import annotations

from django.db.models import Q

from .models import BlockDeal, DarkPoolPrint


def _round2(value) -> float:
    return round(float(value), 2)


def serialize_block_deal(deal: BlockDeal) -> dict:
    return {
        'id': str(deal.id),
        'symbol': deal.symbol,
        'company_name': deal.company_name,
        'exchange': deal.exchange,
        'deal_type': deal.deal_type,
        'side': deal.side,
        'price': _round2(deal.price),
        'quantity': deal.quantity,
        'value_cr': _round2(deal.value_cr),
        'ltp': _round2(deal.ltp),
        'premium_percent': _round2(deal.premium_percent),
        'client_name': deal.client_name,
        'counterparty': deal.counterparty,
        'traded_at': deal.traded_at.isoformat(),
    }


def serialize_dark_pool(print_: DarkPoolPrint) -> dict:
    return {
        'id': str(print_.id),
        'symbol': print_.symbol,
        'company_name': print_.company_name,
        'venue': print_.venue,
        'price': _round2(print_.price),
        'quantity': print_.quantity,
        'value_cr': _round2(print_.value_cr),
        'vwap': _round2(print_.vwap),
        'vs_vwap_percent': _round2(print_.vs_vwap_percent),
        'bias': print_.bias,
        'print_time': print_.print_time.isoformat(),
        'note': print_.note,
    }


def list_block_deals(*, deal_type=None, side=None, q=None, limit=50):
    qs = BlockDeal.objects.all()
    if deal_type in ('block', 'bulk'):
        qs = qs.filter(deal_type=deal_type)
    if side in ('BUY', 'SELL'):
        qs = qs.filter(side=side.upper())
    if q:
        qs = qs.filter(Q(symbol__icontains=q) | Q(company_name__icontains=q) | Q(client_name__icontains=q))
    rows = [serialize_block_deal(d) for d in qs[:limit]]
    buy_value = sum(r['value_cr'] for r in rows if r['side'] == 'BUY')
    sell_value = sum(r['value_cr'] for r in rows if r['side'] == 'SELL')
    return {
        'deals': rows,
        'count': len(rows),
        'summary': {
            'buy_value_cr': round(buy_value, 2),
            'sell_value_cr': round(sell_value, 2),
            'net_value_cr': round(buy_value - sell_value, 2),
            'block_count': sum(1 for r in rows if r['deal_type'] == 'block'),
            'bulk_count': sum(1 for r in rows if r['deal_type'] == 'bulk'),
        },
    }


def list_dark_pool_prints(*, bias=None, q=None, limit=50):
    qs = DarkPoolPrint.objects.all()
    if bias in ('buy', 'sell', 'mixed'):
        qs = qs.filter(bias=bias)
    if q:
        qs = qs.filter(Q(symbol__icontains=q) | Q(company_name__icontains=q) | Q(venue__icontains=q))
    rows = [serialize_dark_pool(p) for p in qs[:limit]]
    return {
        'prints': rows,
        'count': len(rows),
        'summary': {
            'total_value_cr': round(sum(r['value_cr'] for r in rows), 2),
            'buy_biased': sum(1 for r in rows if r['bias'] == 'buy'),
            'sell_biased': sum(1 for r in rows if r['bias'] == 'sell'),
            'avg_vs_vwap': round(
                (sum(r['vs_vwap_percent'] for r in rows) / len(rows)) if rows else 0,
                2,
            ),
        },
    }
