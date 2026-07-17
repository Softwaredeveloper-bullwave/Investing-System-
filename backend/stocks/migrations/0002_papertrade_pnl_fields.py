# Generated manually for trade P&L fields

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('stocks', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='papertrade',
            name='avg_cost',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=12, null=True),
        ),
        migrations.AddField(
            model_name='papertrade',
            name='realized_pnl',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=14, null=True),
        ),
    ]
