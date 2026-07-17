import uuid

from django.db import models


class EducationCategory(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    slug = models.SlugField(max_length=40, unique=True)
    title = models.CharField(max_length=80)
    subtitle = models.CharField(max_length=200)
    icon_name = models.CharField(max_length=40, default='menu_book')
    accent_hex = models.CharField(max_length=7, default='#3B82F6')
    sort_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['sort_order', 'title']
        verbose_name_plural = 'Education categories'

    def __str__(self):
        return self.title


class EducationArticle(models.Model):
    class Level(models.TextChoices):
        BEGINNER = 'Beginner', 'Beginner'
        INTERMEDIATE = 'Intermediate', 'Intermediate'
        ADVANCED = 'Advanced', 'Advanced'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    category = models.ForeignKey(
        EducationCategory, on_delete=models.CASCADE, related_name='articles'
    )
    slug = models.SlugField(max_length=60)
    title = models.CharField(max_length=200)
    summary = models.CharField(max_length=300)
    sections = models.JSONField(default=list)
    read_minutes = models.PositiveSmallIntegerField(default=4)
    level = models.CharField(max_length=20, choices=Level.choices, default=Level.BEGINNER)
    sort_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['sort_order', 'title']
        unique_together = ('category', 'slug')

    def __str__(self):
        return self.title


class EducationQuiz(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    category = models.ForeignKey(
        EducationCategory, on_delete=models.CASCADE, related_name='quizzes'
    )
    slug = models.SlugField(max_length=60)
    title = models.CharField(max_length=120)
    description = models.CharField(max_length=300)
    sort_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['sort_order', 'title']
        unique_together = ('category', 'slug')

    def __str__(self):
        return self.title


class EducationQuizQuestion(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    quiz = models.ForeignKey(
        EducationQuiz, on_delete=models.CASCADE, related_name='questions'
    )
    prompt = models.TextField()
    options = models.JSONField(default=list)
    correct_index = models.PositiveSmallIntegerField(default=0)
    explanation = models.TextField()
    sort_order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['sort_order']

    def __str__(self):
        return self.prompt[:60]
