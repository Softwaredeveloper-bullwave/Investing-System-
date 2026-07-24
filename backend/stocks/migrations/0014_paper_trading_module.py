# Generated manually — Paper Trading module (orders, ledger, journal,
# equity snapshots, risk limits) + bumping the default virtual starting
# balance from ₹5,00,000 to ₹10,00,000.

import uuid
from decimal import Decimal

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


def bump_existing_wallets(apps, schema_editor):
    """Raise every existing PaperWallet's starting balance to the new
    ₹10,00,000 default, adding the same delta to the current balance so any
    simulated P&L already earned/lost is preserved rather than wiped."""
    PaperWallet = apps.get_model('stocks', 'PaperWallet')
    old_default = Decimal('500000.00')
    new_default = Decimal('1000000.00')
    delta = new_default - old_default
    for wallet in PaperWallet.objects.all():
        wallet.balance = (wallet.balance or Decimal('0')) + delta
        wallet.starting_balance = new_default
        wallet.save(update_fields=['balance', 'starting_balance'])


def noop_reverse(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('stocks', '0013_paper_wallet'),
    ]

    operations = [
        migrations.AlterField(
            model_name='paperwallet',
            name='balance',
            field=models.DecimalField(decimal_places=2, default=Decimal('1000000.00'), max_digits=14),
        ),
        migrations.AlterField(
            model_name='paperwallet',
            name='starting_balance',
            field=models.DecimalField(decimal_places=2, default=Decimal('1000000.00'), max_digits=14),
        ),
        migrations.RunPython(bump_existing_wallets, noop_reverse),
        migrations.CreateModel(
            name='PaperOrder',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('side', models.CharField(choices=[('BUY', 'Buy'), ('SELL', 'Sell')], max_length=4)),
                ('order_type', models.CharField(choices=[('MARKET', 'Market'), ('LIMIT', 'Limit'), ('SL-M', 'Stop-Loss Market'), ('SL', 'Stop-Loss Limit')], default='MARKET', max_length=10)),
                ('quantity', models.PositiveIntegerField()),
                ('limit_price', models.DecimalField(blank=True, decimal_places=2, max_digits=12, null=True)),
                ('trigger_price', models.DecimalField(blank=True, decimal_places=2, max_digits=12, null=True)),
                ('status', models.CharField(choices=[('PENDING', 'Pending'), ('EXECUTED', 'Executed'), ('CANCELLED', 'Cancelled'), ('REJECTED', 'Rejected')], default='PENDING', max_length=10)),
                ('executed_price', models.DecimalField(blank=True, decimal_places=2, max_digits=12, null=True)),
                ('charges', models.DecimalField(decimal_places=2, default=Decimal('0'), max_digits=12)),
                ('reject_reason', models.CharField(blank=True, default='', max_length=200)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('executed_at', models.DateTimeField(blank=True, null=True)),
                ('stock', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='paper_orders', to='stocks.stock')),
                ('trade', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='order', to='stocks.papertrade')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='paper_orders', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.AddIndex(
            model_name='paperorder',
            index=models.Index(fields=['user', 'status'], name='stocks_pape_user_id_1b6f0a_idx'),
        ),
        migrations.AddIndex(
            model_name='paperorder',
            index=models.Index(fields=['status', 'order_type'], name='stocks_pape_status_3d9c41_idx'),
        ),
        migrations.AddIndex(
            model_name='paperorder',
            index=models.Index(fields=['user', 'created_at'], name='stocks_pape_user_id_6a2e77_idx'),
        ),
        migrations.CreateModel(
            name='PaperLedgerEntry',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('entry_type', models.CharField(choices=[('RESET', 'Account Reset'), ('BUY', 'Buy Debit'), ('SELL', 'Sell Credit'), ('CHARGE', 'Trading Charges'), ('ADJUSTMENT', 'Adjustment')], max_length=12)),
                ('amount', models.DecimalField(decimal_places=2, max_digits=14)),
                ('balance_after', models.DecimalField(decimal_places=2, max_digits=14)),
                ('description', models.CharField(blank=True, default='', max_length=200)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('order', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='ledger_entries', to='stocks.paperorder')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='paper_ledger_entries', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.AddIndex(
            model_name='paperledgerentry',
            index=models.Index(fields=['user', 'created_at'], name='stocks_pape_user_id_f3a8b2_idx'),
        ),
        migrations.CreateModel(
            name='PaperJournalEntry',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('symbol', models.CharField(blank=True, default='', max_length=20)),
                ('title', models.CharField(max_length=120)),
                ('notes', models.TextField(blank=True, default='')),
                ('lesson_learned', models.TextField(blank=True, default='')),
                ('mood', models.CharField(blank=True, choices=[('confident', 'Confident'), ('neutral', 'Neutral'), ('anxious', 'Anxious'), ('fomo', 'FOMO'), ('disciplined', 'Disciplined')], default='', max_length=12)),
                ('rating', models.PositiveSmallIntegerField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('trade', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='journal_entries', to='stocks.papertrade')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='paper_journal_entries', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.AddIndex(
            model_name='paperjournalentry',
            index=models.Index(fields=['user', 'created_at'], name='stocks_pape_user_id_9c1d44_idx'),
        ),
        migrations.CreateModel(
            name='PaperEquitySnapshot',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('date', models.DateField()),
                ('balance', models.DecimalField(decimal_places=2, max_digits=14)),
                ('holdings_value', models.DecimalField(decimal_places=2, max_digits=14)),
                ('equity', models.DecimalField(decimal_places=2, max_digits=14)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='paper_equity_snapshots', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['date'],
            },
        ),
        migrations.AddIndex(
            model_name='paperequitysnapshot',
            index=models.Index(fields=['user', 'date'], name='stocks_pape_user_id_5e7f19_idx'),
        ),
        migrations.AlterUniqueTogether(
            name='paperequitysnapshot',
            unique_together={('user', 'date')},
        ),
        migrations.CreateModel(
            name='PaperRiskLimit',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('max_daily_loss', models.DecimalField(blank=True, decimal_places=2, max_digits=14, null=True)),
                ('max_position_size_percent', models.DecimalField(decimal_places=2, default=Decimal('20.00'), max_digits=5)),
                ('is_active', models.BooleanField(default=True)),
                ('last_daily_warning_date', models.DateField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='paper_risk_limit', to=settings.AUTH_USER_MODEL)),
            ],
        ),
    ]
