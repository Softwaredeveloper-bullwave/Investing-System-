import uuid

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name='EducationCategory',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('slug', models.SlugField(max_length=40, unique=True)),
                ('title', models.CharField(max_length=80)),
                ('subtitle', models.CharField(max_length=200)),
                ('icon_name', models.CharField(default='menu_book', max_length=40)),
                ('accent_hex', models.CharField(default='#3B82F6', max_length=7)),
                ('sort_order', models.PositiveIntegerField(default=0)),
                ('is_active', models.BooleanField(default=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'verbose_name_plural': 'Education categories',
                'ordering': ['sort_order', 'title'],
            },
        ),
        migrations.CreateModel(
            name='EducationQuiz',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('slug', models.SlugField(max_length=60)),
                ('title', models.CharField(max_length=120)),
                ('description', models.CharField(max_length=300)),
                ('sort_order', models.PositiveIntegerField(default=0)),
                ('is_active', models.BooleanField(default=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('category', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='quizzes', to='education.educationcategory')),
            ],
            options={
                'ordering': ['sort_order', 'title'],
                'unique_together': {('category', 'slug')},
            },
        ),
        migrations.CreateModel(
            name='EducationArticle',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('slug', models.SlugField(max_length=60)),
                ('title', models.CharField(max_length=200)),
                ('summary', models.CharField(max_length=300)),
                ('sections', models.JSONField(default=list)),
                ('read_minutes', models.PositiveSmallIntegerField(default=4)),
                ('level', models.CharField(choices=[('Beginner', 'Beginner'), ('Intermediate', 'Intermediate'), ('Advanced', 'Advanced')], default='Beginner', max_length=20)),
                ('sort_order', models.PositiveIntegerField(default=0)),
                ('is_active', models.BooleanField(default=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('category', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='articles', to='education.educationcategory')),
            ],
            options={
                'ordering': ['sort_order', 'title'],
                'unique_together': {('category', 'slug')},
            },
        ),
        migrations.CreateModel(
            name='EducationQuizQuestion',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('prompt', models.TextField()),
                ('options', models.JSONField(default=list)),
                ('correct_index', models.PositiveSmallIntegerField(default=0)),
                ('explanation', models.TextField()),
                ('sort_order', models.PositiveIntegerField(default=0)),
                ('quiz', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='questions', to='education.educationquiz')),
            ],
            options={
                'ordering': ['sort_order'],
            },
        ),
    ]
