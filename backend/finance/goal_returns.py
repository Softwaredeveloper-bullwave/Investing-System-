"""Goal plan return tiers and projection helpers."""

from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP

GOAL_RETURN_TIERS = [
    {
        'id': 'starter',
        'name': 'Starter',
        'tagline': 'Begin your savings journey',
        'min_monthly': Decimal('500'),
        'max_monthly': Decimal('9999'),
        'annual_return_rate': Decimal('8'),
        'badge': 'Up to 8% p.a.',
        'color': '#10B981',
    },
    {
        'id': 'growth',
        'name': 'Growth',
        'tagline': 'Accelerate with higher returns',
        'min_monthly': Decimal('10000'),
        'max_monthly': Decimal('99999'),
        'annual_return_rate': Decimal('12'),
        'badge': 'Up to 12% p.a.',
        'color': '#6366F1',
    },
    {
        'id': 'elite',
        'name': 'Elite',
        'tagline': 'Premium tier for serious savers',
        'min_monthly': Decimal('100000'),
        'max_monthly': None,
        'annual_return_rate': Decimal('16'),
        'badge': 'Up to 16% p.a.',
        'color': '#F59E0B',
    },
]

MIN_MONTHLY_CONTRIBUTION = Decimal('500')
MAX_MONTHLY_CONTRIBUTION = Decimal('100000')


def tier_for_monthly(amount: Decimal) -> dict:
    amt = Decimal(str(amount))
    selected = GOAL_RETURN_TIERS[0]
    for tier in GOAL_RETURN_TIERS:
        max_m = tier['max_monthly']
        if amt >= tier['min_monthly'] and (max_m is None or amt <= max_m):
            selected = tier
    return selected


def annual_rate_for_monthly(amount: Decimal) -> Decimal:
    return tier_for_monthly(amount)['annual_return_rate']


def monthly_rate(annual_rate: Decimal) -> Decimal:
    return annual_rate / Decimal('100') / Decimal('12')


def accrue_monthly_return(accumulated: Decimal, annual_rate: Decimal) -> Decimal:
    """Interest on current balance for one month."""
    if accumulated <= 0 or annual_rate <= 0:
        return Decimal('0')
    interest = accumulated * monthly_rate(annual_rate)
    return interest.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


def projected_maturity(
    monthly_contribution: Decimal,
    months: int,
    annual_rate: Decimal,
) -> tuple[Decimal, Decimal, Decimal]:
    """
    SIP future value with monthly compounding.
    Returns (maturity_value, total_invested, estimated_returns).
    """
    if months <= 0 or monthly_contribution <= 0:
        return Decimal('0'), Decimal('0'), Decimal('0')

    r = monthly_rate(annual_rate)
    invested = monthly_contribution * months
    if r == 0:
        return invested, invested, Decimal('0')

    one_plus_r = Decimal('1') + r
    fv = monthly_contribution * (pow(one_plus_r, months) - Decimal('1')) / r
    fv = fv.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    returns = (fv - invested).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    return fv, invested, returns


def serialize_tiers() -> list[dict]:
    out = []
    for tier in GOAL_RETURN_TIERS:
        out.append(
            {
                'id': tier['id'],
                'name': tier['name'],
                'tagline': tier['tagline'],
                'minMonthly': float(tier['min_monthly']),
                'maxMonthly': float(tier['max_monthly']) if tier['max_monthly'] else None,
                'annualReturnRate': float(tier['annual_return_rate']),
                'badge': tier['badge'],
                'color': tier['color'],
            }
        )
    return out
