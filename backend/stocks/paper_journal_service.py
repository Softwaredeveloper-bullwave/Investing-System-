"""Paper-trading journal — CRUD for `PaperJournalEntry`."""

from __future__ import annotations

from .models import PaperJournalEntry, PaperTrade


class JournalError(Exception):
    pass


def build_journal_payload(entry: PaperJournalEntry) -> dict:
    return {
        'id': str(entry.id),
        'tradeId': str(entry.trade_id) if entry.trade_id else None,
        'symbol': entry.symbol,
        'title': entry.title,
        'notes': entry.notes,
        'lessonLearned': entry.lesson_learned,
        'mood': entry.mood,
        'rating': entry.rating,
        'createdAt': entry.created_at.isoformat(),
        'updatedAt': entry.updated_at.isoformat(),
    }


def list_journal(user, limit: int = 100) -> list[dict]:
    entries = PaperJournalEntry.objects.filter(user=user).select_related('trade')[:limit]
    return [build_journal_payload(e) for e in entries]


def create_journal_entry(
    user,
    *,
    title: str,
    notes: str = '',
    symbol: str = '',
    trade_id=None,
    lesson_learned: str = '',
    mood: str = '',
    rating=None,
) -> dict:
    if not title or not title.strip():
        raise JournalError('Title is required.')
    if rating is not None and not (1 <= int(rating) <= 5):
        raise JournalError('Rating must be between 1 and 5.')

    trade = None
    if trade_id:
        trade = PaperTrade.objects.filter(id=trade_id, user=user).first()
        if not trade:
            raise JournalError('Trade not found.')
        symbol = symbol or trade.stock.symbol

    entry = PaperJournalEntry.objects.create(
        user=user,
        trade=trade,
        symbol=(symbol or '').upper().strip(),
        title=title.strip(),
        notes=notes,
        lesson_learned=lesson_learned,
        mood=mood,
        rating=rating,
    )
    return build_journal_payload(entry)


def update_journal_entry(user, entry_id, **fields) -> dict:
    entry = PaperJournalEntry.objects.filter(id=entry_id, user=user).first()
    if not entry:
        raise JournalError('Journal entry not found.')

    if 'title' in fields and fields['title'] is not None:
        if not fields['title'].strip():
            raise JournalError('Title is required.')
        entry.title = fields['title'].strip()
    if 'notes' in fields and fields['notes'] is not None:
        entry.notes = fields['notes']
    if 'lesson_learned' in fields and fields['lesson_learned'] is not None:
        entry.lesson_learned = fields['lesson_learned']
    if 'mood' in fields and fields['mood'] is not None:
        entry.mood = fields['mood']
    if 'rating' in fields and fields['rating'] is not None:
        rating = int(fields['rating'])
        if not (1 <= rating <= 5):
            raise JournalError('Rating must be between 1 and 5.')
        entry.rating = rating

    entry.save()
    return build_journal_payload(entry)


def delete_journal_entry(user, entry_id) -> None:
    deleted, _ = PaperJournalEntry.objects.filter(id=entry_id, user=user).delete()
    if not deleted:
        raise JournalError('Journal entry not found.')
