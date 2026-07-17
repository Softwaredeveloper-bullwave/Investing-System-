from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('engagement', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='referralreward',
            name='referred_user',
            field=models.OneToOneField(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='referral_reward_record',
                to=settings.AUTH_USER_MODEL,
            ),
        ),
    ]
