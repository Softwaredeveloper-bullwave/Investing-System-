# Generated manually — bump PaperCompetition.starting_balance default from
# ₹1,00,000 to ₹10,00,000 to match the main paper-trading wallet.

from decimal import Decimal

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('stocks', '0015_paper_options_commodities'),
    ]

    operations = [
        migrations.AlterField(
            model_name='papercompetition',
            name='starting_balance',
            field=models.DecimalField(decimal_places=2, default=Decimal('1000000'), max_digits=14),
        ),
    ]
