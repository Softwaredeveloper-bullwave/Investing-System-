from django.db import migrations, models


def map_legacy_kyc_status(apps, schema_editor):
    User = apps.get_model('accounts', 'User')
    User.objects.filter(kyc_status='completed').update(kyc_status='verified')


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0003_bankaccount_cashfree_verification'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='kyc_status',
            field=models.CharField(
                choices=[
                    ('not_submitted', 'Not Submitted'),
                    ('pending', 'Pending'),
                    ('verified', 'Verified'),
                    ('rejected', 'Rejected'),
                    ('in_progress', 'In Progress'),
                    ('completed', 'Completed'),
                ],
                default='not_submitted',
                max_length=20,
            ),
        ),
        migrations.RunPython(map_legacy_kyc_status, migrations.RunPython.noop),
    ]
