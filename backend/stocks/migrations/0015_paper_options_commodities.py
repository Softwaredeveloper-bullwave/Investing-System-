# Generated manually — Paper Options (equity F&O + commodity options) and
# Paper Commodities, extending the paper-trading module started in
# 0014_paper_trading_module.py. Both settle against the existing
# PaperWallet — no new wallet model needed.

import uuid
from decimal import Decimal

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('stocks', '0014_paper_trading_module'),
    ]

    operations = [
        migrations.CreateModel(
            name='PaperOptionHolding',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('underlying', models.CharField(db_index=True, max_length=20)),
                ('asset_class', models.CharField(choices=[('equity_fno', 'Equity F&O'), ('commodity', 'Commodity')], default='equity_fno', max_length=20)),
                ('strike', models.DecimalField(decimal_places=4, max_digits=12)),
                ('option_type', models.CharField(max_length=2)),
                ('expiry', models.DateField()),
                ('quantity', models.PositiveIntegerField()),
                ('avg_premium', models.DecimalField(decimal_places=4, max_digits=12)),
                ('lot_size', models.PositiveIntegerField(default=1)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='paper_option_holdings', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'unique_together': {('user', 'underlying', 'strike', 'option_type', 'expiry', 'asset_class')},
            },
        ),
        migrations.AddIndex(
            model_name='paperoptionholding',
            index=models.Index(fields=['user', 'underlying'], name='stocks_pape_user_id_e1a7c1_idx'),
        ),
        migrations.CreateModel(
            name='PaperOptionOrder',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('underlying', models.CharField(db_index=True, max_length=20)),
                ('asset_class', models.CharField(choices=[('equity_fno', 'Equity F&O'), ('commodity', 'Commodity')], default='equity_fno', max_length=20)),
                ('strike', models.DecimalField(decimal_places=4, max_digits=12)),
                ('option_type', models.CharField(max_length=2)),
                ('expiry', models.DateField()),
                ('side', models.CharField(choices=[('BUY', 'Buy'), ('SELL', 'Sell')], max_length=4)),
                ('quantity', models.PositiveIntegerField()),
                ('premium', models.DecimalField(decimal_places=4, max_digits=12)),
                ('lot_size', models.PositiveIntegerField(default=1)),
                ('amount_inr', models.DecimalField(decimal_places=2, max_digits=14)),
                ('avg_premium', models.DecimalField(blank=True, decimal_places=4, max_digits=12, null=True)),
                ('realized_pnl_inr', models.DecimalField(blank=True, decimal_places=2, max_digits=14, null=True)),
                ('charges', models.DecimalField(decimal_places=2, default=Decimal('0'), max_digits=12)),
                ('status', models.CharField(choices=[('EXECUTED', 'Executed'), ('REJECTED', 'Rejected')], default='EXECUTED', max_length=10)),
                ('reject_reason', models.CharField(blank=True, default='', max_length=200)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='paper_option_orders', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.AddIndex(
            model_name='paperoptionorder',
            index=models.Index(fields=['user', 'created_at'], name='stocks_pape_user_id_f2b8d2_idx'),
        ),
        migrations.AddIndex(
            model_name='paperoptionorder',
            index=models.Index(fields=['user', 'underlying'], name='stocks_pape_user_id_a9c3e4_idx'),
        ),
        migrations.CreateModel(
            name='PaperCommodityHolding',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('commodity_id', models.CharField(db_index=True, max_length=20)),
                ('quantity', models.PositiveIntegerField()),
                ('avg_price_usd', models.DecimalField(decimal_places=4, max_digits=14)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='paper_commodity_holdings', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'unique_together': {('user', 'commodity_id')},
            },
        ),
        migrations.CreateModel(
            name='PaperCommodityOrder',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('commodity_id', models.CharField(db_index=True, max_length=20)),
                ('side', models.CharField(choices=[('BUY', 'Buy'), ('SELL', 'Sell')], max_length=4)),
                ('quantity', models.PositiveIntegerField()),
                ('price_usd', models.DecimalField(decimal_places=4, max_digits=14)),
                ('amount_inr', models.DecimalField(decimal_places=2, max_digits=14)),
                ('usd_inr_rate', models.DecimalField(decimal_places=4, max_digits=10)),
                ('avg_cost_usd', models.DecimalField(blank=True, decimal_places=4, max_digits=14, null=True)),
                ('realized_pnl_inr', models.DecimalField(blank=True, decimal_places=2, max_digits=14, null=True)),
                ('charges', models.DecimalField(decimal_places=2, default=Decimal('0'), max_digits=12)),
                ('status', models.CharField(choices=[('EXECUTED', 'Executed'), ('REJECTED', 'Rejected')], default='EXECUTED', max_length=10)),
                ('reject_reason', models.CharField(blank=True, default='', max_length=200)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='paper_commodity_orders', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.AddIndex(
            model_name='papercommodityorder',
            index=models.Index(fields=['user', 'created_at'], name='stocks_pape_user_id_c7d1f5_idx'),
        ),
    ]
