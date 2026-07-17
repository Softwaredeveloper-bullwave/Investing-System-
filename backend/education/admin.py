from django.contrib import admin

from .models import EducationArticle, EducationCategory, EducationQuiz, EducationQuizQuestion


class EducationArticleInline(admin.TabularInline):
    model = EducationArticle
    extra = 0
    fields = ('slug', 'title', 'read_minutes', 'level', 'sort_order', 'is_active')


class EducationQuizInline(admin.TabularInline):
    model = EducationQuiz
    extra = 0
    fields = ('slug', 'title', 'sort_order', 'is_active')


@admin.register(EducationCategory)
class EducationCategoryAdmin(admin.ModelAdmin):
    list_display = ('title', 'slug', 'sort_order', 'is_active', 'updated_at')
    list_filter = ('is_active',)
    search_fields = ('title', 'slug')
    inlines = [EducationArticleInline, EducationQuizInline]


class EducationQuizQuestionInline(admin.TabularInline):
    model = EducationQuizQuestion
    extra = 0
    fields = ('prompt', 'options', 'correct_index', 'explanation', 'sort_order')


@admin.register(EducationQuiz)
class EducationQuizAdmin(admin.ModelAdmin):
    list_display = ('title', 'category', 'slug', 'is_active')
    list_filter = ('category', 'is_active')
    inlines = [EducationQuizQuestionInline]


@admin.register(EducationArticle)
class EducationArticleAdmin(admin.ModelAdmin):
    list_display = ('title', 'category', 'level', 'read_minutes', 'is_active')
    list_filter = ('category', 'level', 'is_active')
    search_fields = ('title', 'slug')
