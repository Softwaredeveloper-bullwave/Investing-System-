"""Goal-based savings — monthly wallet contributions, withdraw, notifications."""

from __future__ import annotations

import logging
import uuid
from datetime import timedelta
from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from engagement.models import Notification

from .goal_returns import (
    MIN_MONTHLY_CONTRIBUTION,
    accrue_monthly_return,
    annual_rate_for_monthly,
    projected_maturity,
    serialize_tiers,
    tier_for_monthly,
)
from .models import GoalContribution, GoalPlanTemplate, Transaction, UserGoalPlan, Wallet, WalletTransaction

logger = logging.getLogger('bullwave.finance')


class GoalError(Exception):
    pass


def _ref_id() -> str:
    return f'GL-{timezone.now().strftime("%Y")}-{uuid.uuid4().hex[:6].upper()}'


def serialize_goal(goal: UserGoalPlan) -> dict:
    template = goal.template
    maturity, invested, est_returns = projected_maturity(
        goal.monthly_contribution,
        goal.duration_months,
        goal.annual_return_rate,
    )
    from .goal_returns import tier_for_monthly

    tier = tier_for_monthly(goal.monthly_contribution)
    return {
        'id': str(goal.id),
        'category': goal.category,
        'title': goal.title,
        'target_amount': float(goal.target_amount),
        'monthly_contribution': float(goal.monthly_contribution),
        'duration_months': goal.duration_months,
        'accumulated_amount': float(goal.accumulated_amount),
        'returns_earned': float(goal.returns_earned),
        'annual_return_rate': float(goal.annual_return_rate),
        'projected_maturity_value': float(maturity),
        'projected_returns': float(est_returns),
        'total_invested_planned': float(invested),
        'installments_done': goal.installments_done,
        'total_installments': goal.duration_months,
        'progress_percent': round(goal.progress_percent, 1),
        'next_contribution_date': goal.next_contribution_date.isoformat() if goal.next_contribution_date else None,
        'target_date': goal.target_date.isoformat() if goal.target_date else None,
        'status': goal.status,
        'reference_id': goal.reference_id,
        'created_at': goal.created_at.isoformat(),
        'icon': template.icon if template else 'savings',
        'color': template.color if template else '#9333EA',
        'tagline': template.tagline if template else '',
        'return_tier': tier['id'],
        'can_withdraw': goal.accumulated_amount > 0 and goal.status in (
            UserGoalPlan.Status.ACTIVE,
            UserGoalPlan.Status.COMPLETED,
        ),
        'is_due': _is_due(goal),
    }


def get_return_tiers() -> list[dict]:
    return serialize_tiers()


def _is_due(goal: UserGoalPlan) -> bool:
    if goal.status != UserGoalPlan.Status.ACTIVE:
        return False
    if not goal.next_contribution_date:
        return False
    return goal.next_contribution_date <= timezone.localdate()


def _notify(user, title: str, message: str) -> None:
    Notification.objects.create(user=user, title=title, message=message, type='goal')


@transaction.atomic
def _debit_wallet(user, amount: Decimal) -> Wallet:
    wallet = Wallet.objects.select_for_update().get(user=user)
    if wallet.balance < amount:
        raise GoalError(f'Insufficient wallet balance. Need ₹{amount:,.0f}.')
    wallet.balance -= amount
    wallet.save(update_fields=['balance'])
    WalletTransaction.objects.create(
        wallet=wallet,
        type=WalletTransaction.TxType.WITHDRAWAL,
        amount=amount,
        status=WalletTransaction.Status.COMPLETED,
    )
    return wallet


@transaction.atomic
def _credit_wallet(user, amount: Decimal, description: str) -> Wallet:
    wallet = Wallet.objects.select_for_update().get(user=user)
    wallet.balance += amount
    wallet.save(update_fields=['balance'])
    WalletTransaction.objects.create(
        wallet=wallet,
        type=WalletTransaction.TxType.DEPOSIT,
        amount=amount,
        status=WalletTransaction.Status.COMPLETED,
    )
    Transaction.objects.create(
        user=user,
        reference_id=_ref_id(),
        type=Transaction.TxType.PROFIT,
        status=Transaction.Status.COMPLETED,
        amount=amount,
        description=description,
    )
    return wallet


@transaction.atomic
def _apply_contribution(goal: UserGoalPlan, amount: Decimal, kind: str) -> UserGoalPlan:
    if goal.status not in (UserGoalPlan.Status.ACTIVE,):
        raise GoalError('This goal is not active.')

    _debit_wallet(goal.user, amount)

    interest = accrue_monthly_return(goal.accumulated_amount, goal.annual_return_rate)
    if interest > 0:
        goal.returns_earned += interest
        goal.accumulated_amount += interest
        GoalContribution.objects.create(
            goal=goal,
            amount=interest,
            kind=GoalContribution.Kind.RETURN,
        )

    goal.accumulated_amount += amount
    goal.installments_done += 1

    GoalContribution.objects.create(goal=goal, amount=amount, kind=kind)

    Transaction.objects.create(
        user=goal.user,
        reference_id=goal.reference_id,
        type=Transaction.TxType.INVESTMENT,
        status=Transaction.Status.COMPLETED,
        amount=amount,
        description=f'Goal: {goal.title}',
    )

    today = timezone.localdate()
    goal.next_contribution_date = today + timedelta(days=30)

    if goal.accumulated_amount >= goal.target_amount or goal.installments_done >= goal.duration_months:
        goal.status = UserGoalPlan.Status.COMPLETED
        goal.completed_at = timezone.now()
        goal.next_contribution_date = None
        _notify(
            goal.user,
            f'Goal achieved: {goal.title}',
            f'Congratulations! You reached ₹{goal.accumulated_amount:,.0f} '
            f'toward {goal.title}. You can withdraw anytime.',
        )
    else:
        total_msg = f'₹{amount:,.0f} added. Total saved: ₹{goal.accumulated_amount:,.0f} '
        if interest > 0:
            total_msg += f'(incl. ₹{interest:,.0f} returns at {goal.annual_return_rate}% p.a.). '
        total_msg += f'{goal.progress_percent:.0f}% of target.'
        _notify(
            goal.user,
            f'Goal saved: {goal.title}',
            total_msg,
        )

    goal.save()
    return goal


@transaction.atomic
def create_goal_plan(
    user,
    *,
    category: str,
    title: str,
    target_amount: Decimal,
    monthly_contribution: Decimal,
    duration_months: int,
    pay_first_installment: bool = True,
) -> UserGoalPlan:
    category = (category or '').strip().lower()
    try:
        template = GoalPlanTemplate.objects.get(category=category, is_active=True)
    except GoalPlanTemplate.DoesNotExist:
        template = None

    if target_amount < (template.min_target if template else Decimal('5000')):
        raise GoalError(f'Minimum target is ₹{(template.min_target if template else 5000):,.0f}.')

    if duration_months < 3 or duration_months > 24:
        raise GoalError('Duration must be between 3 and 24 months.')

    if monthly_contribution <= 0:
        raise GoalError('Monthly contribution must be greater than zero.')

    if monthly_contribution < MIN_MONTHLY_CONTRIBUTION:
        raise GoalError(f'Minimum monthly contribution is ₹{MIN_MONTHLY_CONTRIBUTION:,.0f}.')

    annual_rate = annual_rate_for_monthly(monthly_contribution)
    tier = tier_for_monthly(monthly_contribution)

    today = timezone.localdate()
    goal = UserGoalPlan.objects.create(
        user=user,
        template=template,
        category=category,
        title=title.strip() or (template.name if template else category.title()),
        target_amount=target_amount,
        monthly_contribution=monthly_contribution,
        duration_months=duration_months,
        annual_return_rate=annual_rate,
        next_contribution_date=today + timedelta(days=30),
        target_date=today + timedelta(days=30 * duration_months),
        reference_id=_ref_id(),
        status=UserGoalPlan.Status.ACTIVE,
    )

    if pay_first_installment:
        first_amount = min(monthly_contribution, target_amount)
        _apply_contribution(goal, first_amount, GoalContribution.Kind.INITIAL)
        goal.refresh_from_db()

    _notify(
        user,
        f'Goal plan started: {goal.title}',
        f'Your {goal.title} plan is active on the {tier["name"]} tier at '
        f'{annual_rate}% p.a. ₹{monthly_contribution:,.0f}/month for {duration_months} months. '
        f'Next installment on {goal.next_contribution_date}.',
    )
    return goal


@transaction.atomic
def contribute_to_goal(goal: UserGoalPlan, amount: Decimal | None = None) -> UserGoalPlan:
    amt = amount or goal.monthly_contribution
    if amt <= 0:
        raise GoalError('Invalid contribution amount.')
    return _apply_contribution(goal, amt, GoalContribution.Kind.TOP_UP)


@transaction.atomic
def withdraw_from_goal(goal: UserGoalPlan, amount: Decimal | None = None) -> UserGoalPlan:
    if goal.accumulated_amount <= 0:
        raise GoalError('Nothing to withdraw from this goal.')

    withdraw = amount or goal.accumulated_amount
    if withdraw <= 0 or withdraw > goal.accumulated_amount:
        raise GoalError('Invalid withdrawal amount.')

    _credit_wallet(goal.user, withdraw, f'Goal withdrawal: {goal.title}')
    goal.accumulated_amount -= withdraw

    if goal.accumulated_amount <= 0:
        goal.status = UserGoalPlan.Status.CLOSED
        goal.next_contribution_date = None

    goal.save()

    _notify(
        goal.user,
        f'Withdrawal from {goal.title}',
        f'₹{withdraw:,.0f} transferred to your wallet.',
    )
    return goal


def get_user_goals(user) -> list[dict]:
    goals = UserGoalPlan.objects.filter(user=user).select_related('template')
    return [serialize_goal(g) for g in goals]


def get_due_reminders(user) -> list[dict]:
    today = timezone.localdate()
    due = UserGoalPlan.objects.filter(
        user=user,
        status=UserGoalPlan.Status.ACTIVE,
        next_contribution_date__lte=today,
    ).select_related('template')
    return [serialize_goal(g) for g in due]


def process_due_goal_contributions() -> int:
    """Auto-debit wallet for due monthly installments. Returns count processed."""
    today = timezone.localdate()
    goals = UserGoalPlan.objects.filter(
        status=UserGoalPlan.Status.ACTIVE,
        next_contribution_date__lte=today,
    ).select_related('user', 'template')

    processed = 0
    for goal in goals:
        if goal.installments_done >= goal.duration_months:
            goal.status = UserGoalPlan.Status.COMPLETED
            goal.completed_at = timezone.now()
            goal.next_contribution_date = None
            goal.save()
            continue

        amount = min(goal.monthly_contribution, goal.target_amount - goal.accumulated_amount)
        if amount <= 0:
            continue

        try:
            with transaction.atomic():
                wallet = Wallet.objects.select_for_update().get(user=goal.user)
                if wallet.balance < amount:
                    _notify(
                        goal.user,
                        f'Goal installment due: {goal.title}',
                        f'Add ₹{amount:,.0f} to your wallet to complete this month\'s '
                        f'savings for {goal.title}. Open Goals to pay now.',
                    )
                    continue
                _apply_contribution(goal, amount, GoalContribution.Kind.MONTHLY)
            processed += 1
        except Exception as exc:
            logger.warning('Goal installment failed %s: %s', goal.id, exc)

    return processed


def send_upcoming_reminders() -> int:
    """Notify users 2 days before next installment."""
    today = timezone.localdate()
    upcoming = today + timedelta(days=2)
    goals = UserGoalPlan.objects.filter(
        status=UserGoalPlan.Status.ACTIVE,
        next_contribution_date=upcoming,
    ).select_related('user')

    count = 0
    for goal in goals:
        _notify(
            goal.user,
            f'Upcoming: {goal.title}',
            f'Your ₹{goal.monthly_contribution:,.0f} installment for {goal.title} '
            f'is due in 2 days ({goal.next_contribution_date}). Keep wallet funded.',
        )
        count += 1
    return count
