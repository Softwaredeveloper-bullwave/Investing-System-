import uuid

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('kyc', '0002_kycrequest'),
    ]

    operations = [
        migrations.CreateModel(
            name='KYCRequestImage',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('image', models.ImageField(upload_to='kyc/pan/%Y/%m/')),
                ('sort_order', models.PositiveSmallIntegerField(default=0)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('request', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='images',
                    to='kyc.kycrequest',
                )),
            ],
            options={
                'ordering': ['sort_order', 'created_at'],
            },
        ),
    ]
