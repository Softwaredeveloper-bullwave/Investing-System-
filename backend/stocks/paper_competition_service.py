"""Paper trading competitions with friends."""

from __future__ import annotations

import secrets
import string
from datetime import timedelta
from decimal import Decimal

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from .models import PaperCompetition, PaperCompetitionMember, PaperTrade, StockHolding


class CompetitionError(Exception):
    pass


def _code(length: int = 6) -> str:
    alphabet = string.ascii_uppercase + string.digits
    for _ in range(20):
        candidate = ''.join(secrets.choice(alphabet) for _ in range(length))
        if not PaperCompetition.objects.filter(invite_code=candidate).exists():
            return candidate
    raise CompetitionError('Could not generate invite code.')


def _display_name(user) -> str:
    name = (getattr(user, 'name', None) or '').strip()
    if name:
        return name
    phone = getattr(user, 'phone', '') or ''
    return f'Trader {phone[-4:]}' if phone else 'Trader'


def _round2(value) -> float:
    return round(float(value), 2)


def refresh_member_stats(member: PaperCompetitionMember) -> PaperCompetitionMember:
    """Score from paper trades after join + open holdings mark-to-market."""
    starting = Decimal(member.competition.starting_balance)
    trades = PaperTrade.objects.filter(
        user=member.user, created_at__gte=member.joined_at
    ).select_related('stock')
    trades_count = trades.count()
    realized = trades.filter(realized_pnl__isnull=False).aggregate(
        total=Sum('realized_pnl')
    )['total'] or Decimal('0')

    # Unrealized from current holdings (shared paper book approximation)
    unrealized = Decimal('0')
    for holding in StockHolding.objects.filter(user=member.user).select_related('stock'):
        unrealized += (holding.stock.ltp - holding.avg_price) * holding.quantity

    pnl = realized + unrealized
    equity = starting + pnl
    pnl_percent = (pnl / starting * 100) if starting else Decimal('0')

    member.trades_count = trades_count
    member.pnl = pnl
    member.equity = equity
    member.pnl_percent = pnl_percent
    member.save(update_fields=['trades_count', 'pnl', 'equity', 'pnl_percent', 'updated_at'])
    return member


def _maybe_end(competition: PaperCompetition) -> PaperCompetition:
    if competition.status != PaperCompetition.Status.ENDED and timezone.now() >= competition.ends_at:
        competition.status = PaperCompetition.Status.ENDED
        competition.save(update_fields=['status'])
    elif competition.status == PaperCompetition.Status.OPEN and competition.members.count() >= 2:
        competition.status = PaperCompetition.Status.ACTIVE
        competition.save(update_fields=['status'])
    return competition


def _serialize_member(member: PaperCompetitionMember, *, rank: int = 0, is_you: bool = False) -> dict:
    return {
        'id': str(member.id),
        'user_id': str(member.user_id),
        'display_name': member.display_name,
        'equity': _round2(member.equity),
        'pnl': _round2(member.pnl),
        'pnl_percent': _round2(member.pnl_percent),
        'trades_count': member.trades_count,
        'rank': rank,
        'is_you': is_you,
        'joined_at': member.joined_at.isoformat(),
    }


def _serialize_competition(comp: PaperCompetition, user=None) -> dict:
    comp = _maybe_end(comp)
    members = list(comp.members.select_related('user'))
    for m in members:
        refresh_member_stats(m)
    members = list(comp.members.select_related('user').order_by('-pnl_percent', '-equity'))
    standings = [
        _serialize_member(m, rank=i + 1, is_you=bool(user and m.user_id == user.id))
        for i, m in enumerate(members)
    ]
    you = next((s for s in standings if s['is_you']), None)
    return {
        'id': str(comp.id),
        'name': comp.name,
        'invite_code': comp.invite_code,
        'starting_balance': _round2(comp.starting_balance),
        'status': comp.status,
        'duration_days': comp.duration_days,
        'starts_at': comp.starts_at.isoformat(),
        'ends_at': comp.ends_at.isoformat(),
        'members_count': len(standings),
        'is_host': bool(user and comp.host_id == user.id),
        'you': you,
        'standings': standings,
        'share_message': (
            f'Join my BullWave paper trading competition "{comp.name}"! '
            f'Code: {comp.invite_code}. Starting capital ₹{comp.starting_balance:,.0f}.'
        ),
    }


def list_competitions(user):
    qs = (
        PaperCompetition.objects.filter(members__user=user)
        .distinct()
        .prefetch_related('members')
    )
    return [_serialize_competition(c, user) for c in qs]


def get_competition(competition_id, user) -> dict:
    try:
        comp = PaperCompetition.objects.get(pk=competition_id)
    except PaperCompetition.DoesNotExist as exc:
        raise CompetitionError('Competition not found.') from exc
    if not comp.members.filter(user=user).exists():
        raise CompetitionError('Join this competition to view standings.')
    return _serialize_competition(comp, user)


@transaction.atomic
def create_competition(user, *, name: str, starting_balance=100000, duration_days=7) -> dict:
    name = (name or '').strip() or f"{_display_name(user)}'s Arena"
    try:
        balance = Decimal(str(starting_balance))
    except Exception as exc:
        raise CompetitionError('Invalid starting balance.') from exc
    if balance < 10000:
        raise CompetitionError('Starting balance must be at least ₹10,000.')
    days = int(duration_days or 7)
    if days < 1 or days > 30:
        raise CompetitionError('Duration must be between 1 and 30 days.')

    now = timezone.now()
    comp = PaperCompetition.objects.create(
        host=user,
        name=name[:80],
        invite_code=_code(),
        starting_balance=balance,
        status=PaperCompetition.Status.OPEN,
        duration_days=days,
        ends_at=now + timedelta(days=days),
    )
    PaperCompetitionMember.objects.create(
        competition=comp,
        user=user,
        display_name=_display_name(user),
        equity=balance,
        pnl=Decimal('0'),
        pnl_percent=Decimal('0'),
    )
    return _serialize_competition(comp, user)


@transaction.atomic
def join_competition(user, *, invite_code: str) -> dict:
    code = (invite_code or '').strip().upper()
    if not code:
        raise CompetitionError('Enter an invite code.')
    try:
        comp = PaperCompetition.objects.select_for_update().get(invite_code=code)
    except PaperCompetition.DoesNotExist as exc:
        raise CompetitionError('Invalid invite code.') from exc

    comp = _maybe_end(comp)
    if comp.status == PaperCompetition.Status.ENDED:
        raise CompetitionError('This competition has ended.')
    if comp.members.filter(user=user).exists():
        return _serialize_competition(comp, user)
    if comp.members.count() >= 20:
        raise CompetitionError('Competition is full (max 20 friends).')

    PaperCompetitionMember.objects.create(
        competition=comp,
        user=user,
        display_name=_display_name(user),
        equity=comp.starting_balance,
        pnl=Decimal('0'),
        pnl_percent=Decimal('0'),
    )
    if comp.status == PaperCompetition.Status.OPEN and comp.members.count() >= 2:
        comp.status = PaperCompetition.Status.ACTIVE
        comp.save(update_fields=['status'])
    return _serialize_competition(comp, user)


def refresh_user_competitions(user):
    """Recalc standings after a paper trade."""
    memberships = PaperCompetitionMember.objects.filter(
        user=user,
        competition__status__in=[
            PaperCompetition.Status.OPEN,
            PaperCompetition.Status.ACTIVE,
        ],
    ).select_related('competition')
    for m in memberships:
        refresh_member_stats(m)
