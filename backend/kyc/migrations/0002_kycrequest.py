# Generated migration for manual KYC

import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('kyc', '0001_initial'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='KYCRequest',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('pan_number', models.CharField(max_length=10)),
                ('full_name', models.CharField(max_length=120)),
                ('dob', models.DateField()),
                ('pan_image', models.ImageField(upload_to='kyc/pan/%Y/%m/')),
                ('status', models.CharField(
                    choices=[('PENDING', 'Pending'), ('APPROVED', 'Approved'), ('REJECTED', 'Rejected')],
                    default='PENDING',
                    max_length=20,
                )),
                ('rejection_reason', models.CharField(blank=True, default='', max_length=500)),
                ('reviewed_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('reviewed_by', models.ForeignKey(
                    blank=True,
                    null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='kyc_reviews',
                    to=settings.AUTH_USER_MODEL,
                )),
                ('user', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='kyc_requests',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.AddIndex(
            model_name='kycrequest',
            index=models.Index(fields=['status', 'created_at'], name='kyc_kycrequ_status_created_idx'),
        ),
    ]
