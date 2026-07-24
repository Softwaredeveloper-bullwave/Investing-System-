# Generated manually to add the isolated virtual paper-trading wallet.

from decimal import Decimal

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('stocks', '0012_block_deal_dark_pool'),
    ]

    operations = [
        migrations.CreateModel(
            name='PaperWallet',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('balance', models.DecimalField(decimal_places=2, default=Decimal('500000.00'), max_digits=14)),
                ('starting_balance', models.DecimalField(decimal_places=2, default=Decimal('500000.00'), max_digits=14)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='paper_wallet', to=settings.AUTH_USER_MODEL)),
            ],
        ),
    ]
