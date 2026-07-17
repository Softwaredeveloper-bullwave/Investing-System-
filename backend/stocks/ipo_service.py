"""IPO calendar — curated events with live status from dates."""

from __future__ import annotations

from datetime import date
from decimal import Decimal, ROUND_HALF_UP

from django.utils import timezone

from .models import IpoEvent


def _effective_status(ipo: IpoEvent, today: date) -> str:
    if ipo.status == IpoEvent.Status.LISTED:
        return IpoEvent.Status.LISTED
    if ipo.listing_date and today >= ipo.listing_date:
        return IpoEvent.Status.LISTED
    if ipo.open_date and ipo.close_date:
        if today < ipo.open_date:
            return IpoEvent.Status.UPCOMING
        if ipo.open_date <= today <= ipo.close_date:
            return IpoEvent.Status.OPEN
        if today > ipo.close_date:
            return IpoEvent.Status.CLOSED
    return ipo.status


def _serialize_ipo(ipo: IpoEvent, today: date) -> dict:
    status = _effective_status(ipo, today)
    return {
        'id': ipo.id,
        'companyName': ipo.company_name,
        'symbol': ipo.symbol,
        'sector': ipo.sector,
        'status': status,
        'openDate': ipo.open_date.isoformat() if ipo.open_date else None,
        'closeDate': ipo.close_date.isoformat() if ipo.close_date else None,
        'listingDate': ipo.listing_date.isoformat() if ipo.listing_date else None,
        'priceBandMin': float(ipo.price_band_min),
        'priceBandMax': float(ipo.price_band_max),
        'issueSizeCr': float(ipo.issue_size_cr),
        'lotSize': ipo.lot_size,
        'minInvestment': float(ipo.min_investment),
        'gmpPercent': float(ipo.gmp_percent) if ipo.gmp_percent is not None else None,
        'subscriptionTimes': ipo.subscription_times or None,
        'exchange': ipo.exchange,
        'isFeatured': ipo.is_featured,
        'description': ipo.description,
        'listingPrice': float(listing_price_val(ipo)),
    }


def listing_price_val(ipo: IpoEvent) -> Decimal:
    base = ipo.price_band_max
    if ipo.gmp_percent:
        multiplier = Decimal('1') + (ipo.gmp_percent / Decimal('100'))
        return (base * multiplier).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    return base


def list_ipo_calendar(*, status: str | None = None, limit: int | None = None) -> list[dict]:
    today = timezone.localdate()
    rows = list(IpoEvent.objects.all())
    payload = [_serialize_ipo(ipo, today) for ipo in rows]

    status_order = {
        IpoEvent.Status.OPEN: 0,
        IpoEvent.Status.UPCOMING: 1,
        IpoEvent.Status.CLOSED: 2,
        IpoEvent.Status.LISTED: 3,
    }
    payload.sort(
        key=lambda row: (
            status_order.get(row['status'], 9),
            row['openDate'] or row['listingDate'] or '9999-99-99',
        )
    )

    if status:
        normalized = status.lower().strip()
        payload = [row for row in payload if row['status'] == normalized]

    if limit:
        payload = payload[:limit]
    return payload
