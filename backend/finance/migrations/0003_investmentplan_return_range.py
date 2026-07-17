from decimal import Decimal

from django.db import migrations, models


def seed_premium_plan(apps, schema_editor):
    InvestmentPlan = apps.get_model('finance', 'InvestmentPlan')
    InvestmentPlan.objects.update_or_create(
        id='PLAN001',
        defaults={
            'name': 'BullWave Premium Plan',
            'minimum_investment': Decimal('1000000'),
            'monthly_return_rate': Decimal('1.00'),
            'monthly_return_min': Decimal('0.20'),
            'monthly_return_max': Decimal('2.00'),
            'annual_return_rate': Decimal('12.00'),
            'description': (
                'Invest a minimum of ₹10,00,000 and earn 0.2% to 2% monthly returns, '
                'credited directly to your wallet. Ideal for investors seeking steady '
                'income with professional portfolio management.'
            ),
            'is_featured': True,
            'is_active': True,
        },
    )


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0002_payment_order'),
    ]

    operations = [
        migrations.AddField(
            model_name='investmentplan',
            name='monthly_return_min',
            field=models.DecimalField(decimal_places=2, default=Decimal('0.20'), max_digits=5),
        ),
        migrations.AddField(
            model_name='investmentplan',
            name='monthly_return_max',
            field=models.DecimalField(decimal_places=2, default=Decimal('2.00'), max_digits=5),
        ),
        migrations.RunPython(seed_premium_plan, migrations.RunPython.noop),
    ]
