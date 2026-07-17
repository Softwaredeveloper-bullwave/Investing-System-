import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('stocks', '0007_remove_commoditytrade_realized_pnl_inr_and_more'),
    ]

    operations = [
        migrations.CreateModel(
            name='TraderNote',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('title', models.CharField(max_length=200)),
                ('body', models.TextField()),
                ('symbol', models.CharField(blank=True, default='', max_length=20)),
                (
                    'category',
                    models.CharField(
                        choices=[
                            ('general', 'General'),
                            ('stock', 'Stock'),
                            ('trade_idea', 'Trade Idea'),
                            ('journal', 'Journal'),
                        ],
                        default='general',
                        max_length=20,
                    ),
                ),
                ('is_pinned', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                (
                    'user',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='trader_notes',
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                'ordering': ['-is_pinned', '-updated_at'],
                'indexes': [
                    models.Index(fields=['user', 'category', '-updated_at'], name='stocks_trad_user_id_c4a8f1_idx'),
                    models.Index(fields=['user', '-updated_at'], name='stocks_trad_user_id_8e2b0a_idx'),
                ],
            },
        ),
    ]
