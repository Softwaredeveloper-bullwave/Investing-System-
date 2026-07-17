# Generated manually for goal return tiers

from decimal import Decimal

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0005_goal_plans'),
    ]

    operations = [
        migrations.AddField(
            model_name='usergoalplan',
            name='annual_return_rate',
            field=models.DecimalField(decimal_places=2, default=Decimal('8'), max_digits=5),
        ),
        migrations.AddField(
            model_name='usergoalplan',
            name='returns_earned',
            field=models.DecimalField(decimal_places=2, default=Decimal('0'), max_digits=14),
        ),
        migrations.AlterField(
            model_name='goalcontribution',
            name='kind',
            field=models.CharField(
                choices=[
                    ('initial', 'Initial'),
                    ('monthly', 'Monthly'),
                    ('top_up', 'Top-up'),
                    ('return', 'Return'),
                ],
                max_length=20,
            ),
        ),
    ]
