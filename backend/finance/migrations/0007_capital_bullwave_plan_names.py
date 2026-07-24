from django.db import migrations

# Rename the seeded featured plans from "BullWave ..." to "Capital Bullwave ..."
# to match the app's branding (the Flutter fallback catalog already used the
# "Capital Bullwave" form; the live DB rows seeded by 0003/0004 did not).
RENAMES = {
    'PLAN001': 'Capital Bullwave Alpha Premier',
    'PLAN002': 'Capital Bullwave Platinum Reserve',
    'PLAN003': 'Capital Bullwave Sovereign Crown',
}


def rename_plans(apps, schema_editor):
    InvestmentPlan = apps.get_model('finance', 'InvestmentPlan')
    for plan_id, new_name in RENAMES.items():
        InvestmentPlan.objects.filter(id=plan_id).update(name=new_name)


def revert_plans(apps, schema_editor):
    InvestmentPlan = apps.get_model('finance', 'InvestmentPlan')
    old_names = {
        'PLAN001': 'BullWave Alpha Premier',
        'PLAN002': 'BullWave Platinum Reserve',
        'PLAN003': 'BullWave Sovereign Crown',
    }
    for plan_id, old_name in old_names.items():
        InvestmentPlan.objects.filter(id=plan_id).update(name=old_name)


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0006_goal_return_tiers'),
    ]

    operations = [
        migrations.RunPython(rename_plans, revert_plans),
    ]
