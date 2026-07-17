"""Sync dividend records for user holdings — Finnhub with Yahoo Finance fallback."""

from datetime import date

from .finnhub_client import FinnhubError, get_dividends
from .models import DividendRecord, StockHolding
from .yahoo_client import fetch_dividends as yahoo_dividends


def _dividend_rows(symbol):
    try:
        rows = get_dividends(symbol)
        if rows:
            return rows
    except FinnhubError:
        pass
    return yahoo_dividends(symbol)


def sync_user_dividends(user) -> list[DividendRecord]:
    holdings = StockHolding.objects.filter(user=user, quantity__gt=0).select_related('stock')
    synced = []

    for holding in holdings:
        symbol = holding.stock.symbol
        rows = _dividend_rows(symbol)
        if not rows:
            continue

        seen_dates = set()
        for row in rows:
            if not row.get('ex_date'):
                continue
            ex_date = row['ex_date']
            if ex_date in seen_dates:
                continue
            seen_dates.add(ex_date)

            payment_date = row.get('payment_date') or ex_date
            status = (
                DividendRecord.Status.PAID
                if payment_date <= date.today()
                else DividendRecord.Status.UPCOMING
            )
            record, _ = DividendRecord.objects.update_or_create(
                user=user,
                stock=holding.stock,
                ex_date=ex_date,
                defaults={
                    'amount_per_share': row['amount_per_share'],
                    'payment_date': payment_date,
                    'shares_held': holding.quantity,
                    'status': status,
                },
            )
            synced.append(record)

    return synced
