# Generated manually for commodity trading

import uuid

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('stocks', '0002_papertrade_pnl_fields'),
    ]

    operations = [
        migrations.CreateModel(
            name='CommodityHolding',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('commodity_id', models.CharField(db_index=True, max_length=20)),
                ('quantity', models.PositiveIntegerField()),
                ('avg_price_usd', models.DecimalField(decimal_places=2, max_digits=12)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='commodity_holdings', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'unique_together': {('user', 'commodity_id')},
            },
        ),
        migrations.CreateModel(
            name='CommodityTrade',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('commodity_id', models.CharField(db_index=True, max_length=20)),
                ('side', models.CharField(choices=[('BUY', 'Buy'), ('SELL', 'Sell')], max_length=4)),
                ('quantity', models.PositiveIntegerField()),
                ('price_usd', models.DecimalField(decimal_places=2, max_digits=12)),
                ('amount_inr', models.DecimalField(decimal_places=2, max_digits=14)),
                ('usd_inr_rate', models.DecimalField(decimal_places=2, max_digits=8)),
                ('avg_cost_usd', models.DecimalField(blank=True, decimal_places=2, max_digits=12, null=True)),
                ('realized_pnl_inr', models.DecimalField(blank=True, decimal_places=2, max_digits=14, null=True)),
                ('status', models.CharField(choices=[('Executed', 'Executed')], default='Executed', max_length=20)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='commodity_trades', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
    ]
