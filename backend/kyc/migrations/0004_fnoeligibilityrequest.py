import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('kyc', '0003_kycrequestimage'),
    ]

    operations = [
        migrations.CreateModel(
            name='FnoEligibilityRequest',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                (
                    'proof_type',
                    models.CharField(
                        choices=[
                            ('bank_statement', '6-Month Bank Statement'),
                            ('form16', 'FORM 16'),
                            ('itr', 'ITR Form'),
                            ('portfolio_holding', '₹50,000 Portfolio Holding'),
                        ],
                        max_length=32,
                    ),
                ),
                ('document', models.FileField(blank=True, null=True, upload_to='fno/proofs/%Y/%m/')),
                ('portfolio_value', models.DecimalField(decimal_places=2, default=0, max_digits=14)),
                (
                    'status',
                    models.CharField(
                        choices=[
                            ('PENDING', 'Pending'),
                            ('APPROVED', 'Approved'),
                            ('REJECTED', 'Rejected'),
                        ],
                        default='PENDING',
                        max_length=20,
                    ),
                ),
                ('rejection_reason', models.CharField(blank=True, default='', max_length=500)),
                ('reviewed_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                (
                    'reviewed_by',
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name='fno_reviews',
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                (
                    'user',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='fno_requests',
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                'ordering': ['-created_at'],
                'indexes': [models.Index(fields=['status', 'created_at'], name='kyc_fnoelig_status_created_idx')],
            },
        ),
    ]
