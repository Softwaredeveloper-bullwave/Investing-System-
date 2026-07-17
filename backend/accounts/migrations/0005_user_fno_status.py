from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0004_user_kyc_status_manual'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='fno_status',
            field=models.CharField(
                choices=[
                    ('not_submitted', 'Not Submitted'),
                    ('pending', 'Pending'),
                    ('verified', 'Verified'),
                    ('rejected', 'Rejected'),
                ],
                default='not_submitted',
                max_length=20,
            ),
        ),
    ]
