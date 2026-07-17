from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0002_user_avatar_user_bio_user_city_user_date_of_birth'),
    ]

    operations = [
        migrations.AddField(
            model_name='bankaccount',
            name='verification_provider',
            field=models.CharField(blank=True, default='', max_length=20),
        ),
        migrations.AddField(
            model_name='bankaccount',
            name='verification_reference_id',
            field=models.CharField(blank=True, default='', max_length=64),
        ),
        migrations.AddField(
            model_name='bankaccount',
            name='verification_status',
            field=models.CharField(
                choices=[
                    ('pending', 'Pending'),
                    ('verified', 'Verified'),
                    ('failed', 'Failed'),
                ],
                default='pending',
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='bankaccount',
            name='verification_message',
            field=models.CharField(blank=True, default='', max_length=280),
        ),
        migrations.AddField(
            model_name='bankaccount',
            name='name_at_bank',
            field=models.CharField(blank=True, default='', max_length=120),
        ),
        migrations.AddField(
            model_name='bankaccount',
            name='name_match_result',
            field=models.CharField(blank=True, default='', max_length=40),
        ),
        migrations.AddField(
            model_name='bankaccount',
            name='pan_registered_name',
            field=models.CharField(blank=True, default='', max_length=120),
        ),
        migrations.AddField(
            model_name='bankaccount',
            name='verified_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
