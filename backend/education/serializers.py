from rest_framework import serializers

from core.serializers import CamelCaseModelSerializer, CamelCaseSerializer

from .models import EducationArticle, EducationCategory, EducationQuiz, EducationQuizQuestion


class EducationQuizQuestionSerializer(CamelCaseModelSerializer):
    class Meta:
        model = EducationQuizQuestion
        fields = ('id', 'prompt', 'options', 'correct_index', 'explanation', 'sort_order')


class EducationQuizSerializer(CamelCaseModelSerializer):
    questions = EducationQuizQuestionSerializer(many=True, read_only=True)
    category_slug = serializers.CharField(source='category.slug', read_only=True)

    class Meta:
        model = EducationQuiz
        fields = ('id', 'slug', 'category_slug', 'title', 'description', 'questions', 'updated_at')


class EducationArticleSerializer(CamelCaseModelSerializer):
    category_slug = serializers.CharField(source='category.slug', read_only=True)

    class Meta:
        model = EducationArticle
        fields = (
            'id', 'slug', 'category_slug', 'title', 'summary', 'sections',
            'read_minutes', 'level', 'updated_at',
        )


class EducationCategorySerializer(CamelCaseModelSerializer):
    articles = EducationArticleSerializer(many=True, read_only=True)
    quizzes = EducationQuizSerializer(many=True, read_only=True)
    article_count = serializers.SerializerMethodField()
    quiz_count = serializers.SerializerMethodField()

    class Meta:
        model = EducationCategory
        fields = (
            'id', 'slug', 'title', 'subtitle', 'icon_name', 'accent_hex',
            'article_count', 'quiz_count', 'articles', 'quizzes', 'updated_at',
        )

    def get_article_count(self, obj):
        return obj.articles.filter(is_active=True).count()

    def get_quiz_count(self, obj):
        return obj.quizzes.filter(is_active=True).count()


class EducationCatalogSerializer(CamelCaseSerializer):
    updated_at = serializers.DateTimeField()
    categories = EducationCategorySerializer(many=True)
