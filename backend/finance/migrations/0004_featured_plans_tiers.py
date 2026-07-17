from decimal import Decimal

from django.db import migrations


FEATURED_PLANS = [
    {
        'id': 'PLAN001',
        'name': 'BullWave Alpha Premier',
        'minimum_investment': Decimal('1000000'),
        'monthly_return_rate': Decimal('0.25'),
        'monthly_return_min': Decimal('0.25'),
        'monthly_return_max': Decimal('0.25'),
        'annual_return_rate': Decimal('3.00'),
        'description': (
            'Entry-tier premium plan for disciplined investors. Commit ₹10,00,000 and '
            'receive 0.25% monthly returns credited to your wallet with full transparency.'
        ),
        'is_featured': True,
        'is_active': True,
    },
    {
        'id': 'PLAN002',
        'name': 'BullWave Platinum Reserve',
        'minimum_investment': Decimal('5000000'),
        'monthly_return_rate': Decimal('3.00'),
        'monthly_return_min': Decimal('3.00'),
        'monthly_return_max': Decimal('3.00'),
        'annual_return_rate': Decimal('36.00'),
        'description': (
            'Mid-tier wealth plan for established portfolios. Invest ₹50,00,000 minimum '
            'and earn 3% monthly returns with priority support and monthly statements.'
        ),
        'is_featured': True,
        'is_active': True,
    },
    {
        'id': 'PLAN003',
        'name': 'BullWave Sovereign Crown',
        'minimum_investment': Decimal('10000000'),
        'monthly_return_rate': Decimal('4.00'),
        'monthly_return_min': Decimal('4.00'),
        'monthly_return_max': Decimal('4.00'),
        'annual_return_rate': Decimal('48.00'),
        'description': (
            'Flagship HNI plan for ultra-premium clients. Allocate ₹1 crore or more '
            'and unlock 4% monthly returns with dedicated relationship management.'
        ),
        'is_featured': True,
        'is_active': True,
    },
]


def seed_featured_plans(apps, schema_editor):
    InvestmentPlan = apps.get_model('finance', 'InvestmentPlan')
    for plan in FEATURED_PLANS:
        InvestmentPlan.objects.update_or_create(id=plan['id'], defaults=plan)


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0003_investmentplan_return_range'),
    ]

    operations = [
        migrations.RunPython(seed_featured_plans, migrations.RunPython.noop),
    ]
