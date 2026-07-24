"""Read-side of the virtual funds transaction ledger.

Writes happen inline in `trading_service.apply_fill()`/`reset_paper_portfolio()`
(one row per credit/debit) — this module is just the query/formatting layer
for the ledger screen.
"""

from __future__ import annotations

from .models import PaperLedgerEntry


def _round2(value) -> float:
    return round(float(value), 2)


def build_ledger_payload(entry: PaperLedgerEntry) -> dict:
    return {
        'id': str(entry.id),
        'entryType': entry.entry_type,
        'amount': _round2(entry.amount),
        'balanceAfter': _round2(entry.balance_after),
        'description': entry.description,
        'orderId': str(entry.order_id) if entry.order_id else None,
        'createdAt': entry.created_at.isoformat(),
    }


def list_ledger(user, limit: int = 100) -> list[dict]:
    entries = PaperLedgerEntry.objects.filter(user=user).order_by('-created_at')[:limit]
    return [build_ledger_payload(e) for e in entries]
