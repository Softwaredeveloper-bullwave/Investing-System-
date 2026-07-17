from decimal import Decimal

from django.db import transaction
from django.db.models import F
from django.utils import timezone

from .models import CopySubscription, CopyTraderProfile, CopyTraderTrade


class CopyTradingError(Exception):
    pass


def _serialize_trader(trader: CopyTraderProfile, *, is_copying: bool = False) -> dict:
    return {
        'id': str(trader.id),
        'display_name': trader.display_name,
        'handle': trader.handle,
        'avatar_color': trader.avatar_color,
        'bio': trader.bio,
        'strategy_title': trader.strategy_title,
        'strategy_summary': trader.strategy_summary,
        'method_tags': trader.method_tags or [],
        'risk_level': trader.risk_level,
        'is_verified': trader.is_verified,
        'return_1m': float(trader.return_1m),
        'return_3m': float(trader.return_3m),
        'return_1y': float(trader.return_1y),
        'win_rate': float(trader.win_rate),
        'max_drawdown': float(trader.max_drawdown),
        'followers_count': trader.followers_count,
        'aum_inr': float(trader.aum_inr),
        'min_copy_amount': float(trader.min_copy_amount),
        'experience_years': trader.experience_years,
        'is_copying': is_copying,
    }


def _serialize_trade(trade: CopyTraderTrade) -> dict:
    return {
        'id': str(trade.id),
        'symbol': trade.symbol,
        'side': trade.side,
        'quantity': trade.quantity,
        'price': float(trade.price),
        'pnl_percent': float(trade.pnl_percent) if trade.pnl_percent is not None else None,
        'note': trade.note,
        'executed_at': trade.executed_at.isoformat(),
    }


def _serialize_subscription(sub: CopySubscription) -> dict:
    return {
        'id': str(sub.id),
        'trader': _serialize_trader(sub.trader, is_copying=sub.status in ('active', 'paused')),
        'allocation_inr': float(sub.allocation_inr),
        'copy_ratio': float(sub.copy_ratio),
        'status': sub.status,
        'auto_copy': sub.auto_copy,
        'copied_pnl': float(sub.copied_pnl),
        'started_at': sub.started_at.isoformat(),
        'updated_at': sub.updated_at.isoformat(),
    }


def list_traders(user=None, *, risk=None, q=None):
    from django.db.models import Q

    qs = CopyTraderProfile.objects.filter(is_active=True, is_verified=True)
    if risk:
        qs = qs.filter(risk_level=risk.lower())
    if q:
        qs = qs.filter(
            Q(display_name__icontains=q)
            | Q(handle__icontains=q)
            | Q(strategy_title__icontains=q)
        )
    copying_ids = set()
    if user and user.is_authenticated:
        copying_ids = set(
            CopySubscription.objects.filter(
                follower=user, status__in=['active', 'paused']
            ).values_list('trader_id', flat=True)
        )
    return [_serialize_trader(t, is_copying=t.id in copying_ids) for t in qs]


def get_trader(trader_id, user=None) -> dict:
    try:
        trader = CopyTraderProfile.objects.get(pk=trader_id, is_active=True)
    except CopyTraderProfile.DoesNotExist as exc:
        raise CopyTradingError('Trader not found.') from exc
    is_copying = False
    if user and user.is_authenticated:
        is_copying = CopySubscription.objects.filter(
            follower=user, trader=trader, status__in=['active', 'paused']
        ).exists()
    payload = _serialize_trader(trader, is_copying=is_copying)
    trades = CopyTraderTrade.objects.filter(trader=trader)[:20]
    payload['recent_trades'] = [_serialize_trade(t) for t in trades]
    return payload


def list_trader_trades(trader_id, *, limit=30):
    try:
        trader = CopyTraderProfile.objects.get(pk=trader_id, is_active=True)
    except CopyTraderProfile.DoesNotExist as exc:
        raise CopyTradingError('Trader not found.') from exc
    trades = CopyTraderTrade.objects.filter(trader=trader)[:limit]
    return [_serialize_trade(t) for t in trades]


def list_subscriptions(user):
    subs = (
        CopySubscription.objects.filter(follower=user)
        .exclude(status='stopped')
        .select_related('trader')
    )
    return [_serialize_subscription(s) for s in subs]


@transaction.atomic
def start_copy(user, *, trader_id, allocation_inr, copy_ratio=1, auto_copy=True):
    try:
        trader = CopyTraderProfile.objects.select_for_update().get(
            pk=trader_id, is_active=True, is_verified=True
        )
    except CopyTraderProfile.DoesNotExist as exc:
        raise CopyTradingError('Verified trader not found.') from exc

    allocation = Decimal(str(allocation_inr))
    if allocation < trader.min_copy_amount:
        raise CopyTradingError(
            f'Minimum copy amount is ₹{trader.min_copy_amount:,.0f}.'
        )

    ratio = Decimal(str(copy_ratio or 1))
    if ratio <= 0 or ratio > 5:
        raise CopyTradingError('Copy ratio must be between 0.1 and 5.')

    existing = CopySubscription.objects.filter(follower=user, trader=trader).first()
    if existing and existing.status in ('active', 'paused'):
        existing.allocation_inr = allocation
        existing.copy_ratio = ratio
        existing.auto_copy = bool(auto_copy)
        existing.status = 'active'
        existing.save(
            update_fields=['allocation_inr', 'copy_ratio', 'auto_copy', 'status', 'updated_at']
        )
        return _serialize_subscription(existing)

    if existing and existing.status == 'stopped':
        existing.allocation_inr = allocation
        existing.copy_ratio = ratio
        existing.auto_copy = bool(auto_copy)
        existing.status = 'active'
        existing.copied_pnl = Decimal('0')
        existing.started_at = timezone.now()
        existing.save()
        CopyTraderProfile.objects.filter(pk=trader.pk).update(
            followers_count=F('followers_count') + 1,
            aum_inr=F('aum_inr') + allocation,
        )
        existing.refresh_from_db()
        return _serialize_subscription(existing)

    sub = CopySubscription.objects.create(
        follower=user,
        trader=trader,
        allocation_inr=allocation,
        copy_ratio=ratio,
        auto_copy=bool(auto_copy),
        status='active',
    )
    CopyTraderProfile.objects.filter(pk=trader.pk).update(
        followers_count=F('followers_count') + 1,
        aum_inr=F('aum_inr') + allocation,
    )
    sub.refresh_from_db()
    return _serialize_subscription(sub)


@transaction.atomic
def update_subscription(user, subscription_id, *, status=None, allocation_inr=None, auto_copy=None):
    try:
        sub = CopySubscription.objects.select_for_update().select_related('trader').get(
            pk=subscription_id, follower=user
        )
    except CopySubscription.DoesNotExist as exc:
        raise CopyTradingError('Subscription not found.') from exc

    if status is not None:
        status = status.lower()
        if status not in ('active', 'paused', 'stopped'):
            raise CopyTradingError('Invalid status.')
        prev = sub.status
        sub.status = status
        if status == 'stopped' and prev != 'stopped':
            CopyTraderProfile.objects.filter(pk=sub.trader_id, followers_count__gt=0).update(
                followers_count=F('followers_count') - 1,
                aum_inr=F('aum_inr') - sub.allocation_inr,
            )

    if allocation_inr is not None:
        allocation = Decimal(str(allocation_inr))
        if allocation < sub.trader.min_copy_amount:
            raise CopyTradingError(
                f'Minimum copy amount is ₹{sub.trader.min_copy_amount:,.0f}.'
            )
        delta = allocation - sub.allocation_inr
        sub.allocation_inr = allocation
        if sub.status in ('active', 'paused'):
            CopyTraderProfile.objects.filter(pk=sub.trader_id).update(aum_inr=F('aum_inr') + delta)

    if auto_copy is not None:
        sub.auto_copy = bool(auto_copy)

    sub.save()
    return _serialize_subscription(sub)
