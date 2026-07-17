# Generated manually for Goal Plans feature

from decimal import Decimal

from django.db import migrations, models
import django.db.models.deletion
import uuid


GOAL_TEMPLATES = [
    {
        'id': 'GOAL_HOUSE',
        'category': 'house',
        'name': 'Dream Home',
        'tagline': 'Save for your down payment or renovation',
        'icon': 'home',
        'color': '#9333EA',
        'min_target': Decimal('50000'),
        'suggested_monthly': Decimal('5000'),
    },
    {
        'id': 'GOAL_RETIREMENT',
        'category': 'retirement',
        'name': 'Retirement',
        'tagline': 'Build your long-term retirement corpus',
        'icon': 'elderly',
        'color': '#6366F1',
        'min_target': Decimal('25000'),
        'suggested_monthly': Decimal('3000'),
    },
    {
        'id': 'GOAL_EDUCATION',
        'category': 'education',
        'name': 'Education',
        'tagline': 'Fund school, college or skill courses',
        'icon': 'school',
        'color': '#10B981',
        'min_target': Decimal('20000'),
        'suggested_monthly': Decimal('2500'),
    },
    {
        'id': 'GOAL_MARRIAGE',
        'category': 'marriage',
        'name': 'Marriage',
        'tagline': 'Plan wedding expenses stress-free',
        'icon': 'favorite',
        'color': '#EC4899',
        'min_target': Decimal('50000'),
        'suggested_monthly': Decimal('6000'),
    },
    {
        'id': 'GOAL_VEHICLE',
        'category': 'vehicle',
        'name': 'Vehicle',
        'tagline': 'Save for bike, car or EV down payment',
        'icon': 'directions_car',
        'color': '#F59E0B',
        'min_target': Decimal('30000'),
        'suggested_monthly': Decimal('4000'),
    },
]


def seed_goal_templates(apps, schema_editor):
    GoalPlanTemplate = apps.get_model('finance', 'GoalPlanTemplate')
    for row in GOAL_TEMPLATES:
        GoalPlanTemplate.objects.update_or_create(
            category=row['category'],
            defaults={
                'id': row['id'],
                'name': row['name'],
                'tagline': row['tagline'],
                'icon': row['icon'],
                'color': row['color'],
                'min_target': row['min_target'],
                'suggested_monthly': row['suggested_monthly'],
                'min_duration_months': 3,
                'max_duration_months': 24,
                'is_active': True,
            },
        )


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0004_featured_plans_tiers'),
    ]

    operations = [
        migrations.CreateModel(
            name='GoalPlanTemplate',
            fields=[
                ('id', models.CharField(max_length=30, primary_key=True, serialize=False)),
                ('category', models.CharField(choices=[('house', 'Dream Home'), ('retirement', 'Retirement'), ('education', 'Education'), ('marriage', 'Marriage'), ('vehicle', 'Vehicle')], max_length=20, unique=True)),
                ('name', models.CharField(max_length=120)),
                ('tagline', models.CharField(max_length=255)),
                ('icon', models.CharField(default='savings', max_length=40)),
                ('color', models.CharField(default='#9333EA', max_length=20)),
                ('min_target', models.DecimalField(decimal_places=2, default=Decimal('10000'), max_digits=14)),
                ('suggested_monthly', models.DecimalField(decimal_places=2, default=Decimal('2000'), max_digits=14)),
                ('min_duration_months', models.PositiveIntegerField(default=3)),
                ('max_duration_months', models.PositiveIntegerField(default=24)),
                ('is_active', models.BooleanField(default=True)),
            ],
        ),
        migrations.CreateModel(
            name='UserGoalPlan',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('category', models.CharField(max_length=20)),
                ('title', models.CharField(max_length=120)),
                ('target_amount', models.DecimalField(decimal_places=2, max_digits=14)),
                ('monthly_contribution', models.DecimalField(decimal_places=2, max_digits=14)),
                ('duration_months', models.PositiveIntegerField()),
                ('accumulated_amount', models.DecimalField(decimal_places=2, default=Decimal('0'), max_digits=14)),
                ('installments_done', models.PositiveIntegerField(default=0)),
                ('next_contribution_date', models.DateField(blank=True, null=True)),
                ('target_date', models.DateField(blank=True, null=True)),
                ('status', models.CharField(choices=[('active', 'Active'), ('completed', 'Completed'), ('paused', 'Paused'), ('closed', 'Closed')], default='active', max_length=20)),
                ('reference_id', models.CharField(max_length=30, unique=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('completed_at', models.DateTimeField(blank=True, null=True)),
                ('template', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, related_name='user_goals', to='finance.goalplantemplate')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='goal_plans', to='accounts.user')),
            ],
            options={'ordering': ['-created_at']},
        ),
        migrations.CreateModel(
            name='GoalContribution',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('amount', models.DecimalField(decimal_places=2, max_digits=14)),
                ('kind', models.CharField(choices=[('initial', 'Initial'), ('monthly', 'Monthly'), ('top_up', 'Top-up')], max_length=20)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('goal', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='contributions', to='finance.usergoalplan')),
            ],
        ),
        migrations.RunPython(seed_goal_templates, migrations.RunPython.noop),
    ]
