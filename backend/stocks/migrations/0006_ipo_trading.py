from django.db import migrations, models
import django.db.models.deletion
import uuid


class Migration(migrations.Migration):

    dependencies = [
        ('stocks', '0005_ipo_events'),
    ]

    operations = [
        migrations.CreateModel(
            name='IpoHolding',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('lots', models.PositiveIntegerField()),
                ('quantity', models.PositiveIntegerField()),
                ('avg_price', models.DecimalField(decimal_places=2, max_digits=12)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('ipo', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='holdings', to='stocks.ipoevent')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='ipo_holdings', to='accounts.user')),
            ],
            options={
                'unique_together': {('user', 'ipo')},
            },
        ),
        migrations.CreateModel(
            name='IpoTrade',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('side', models.CharField(choices=[('APPLY', 'Apply'), ('SELL', 'Sell')], max_length=8)),
                ('lots', models.PositiveIntegerField(default=1)),
                ('quantity', models.PositiveIntegerField()),
                ('price', models.DecimalField(decimal_places=2, max_digits=12)),
                ('amount_inr', models.DecimalField(decimal_places=2, max_digits=14)),
                ('status', models.CharField(choices=[('Executed', 'Executed'), ('Cancelled', 'Cancelled')], default='Executed', max_length=20)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('ipo', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='trades', to='stocks.ipoevent')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='ipo_trades', to='accounts.user')),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
    ]
