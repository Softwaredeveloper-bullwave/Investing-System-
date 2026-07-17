import uuid

from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('stocks', '0003_commodity_trading'),
    ]

    operations = [
        migrations.CreateModel(
            name='OptionHolding',
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
                ('user', models.ForeignKey(on_delete=models.deletion.CASCADE, related_name='option_holdings', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'unique_together': {('user', 'underlying', 'strike', 'option_type', 'expiry', 'asset_class')},
            },
        ),
        migrations.CreateModel(
            name='OptionTrade',
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
                ('status', models.CharField(choices=[('Executed', 'Executed')], default='Executed', max_length=20)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('user', models.ForeignKey(on_delete=models.deletion.CASCADE, related_name='option_trades', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
    ]
