from django.db.models import Prefetch
from django.utils import timezone
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import EducationArticle, EducationCategory, EducationQuiz, EducationQuizQuestion
from .serializers import (
    EducationArticleSerializer,
    EducationCategorySerializer,
    EducationQuizSerializer,
)


class EducationCatalogView(APIView):
    """Full education tree — categories, articles, quizzes."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        categories = (
            EducationCategory.objects.filter(is_active=True)
            .prefetch_related(
                Prefetch(
                    'articles',
                    queryset=EducationArticle.objects.filter(is_active=True).order_by('sort_order'),
                ),
                Prefetch(
                    'quizzes',
                    queryset=EducationQuiz.objects.filter(is_active=True)
                    .prefetch_related(
                        Prefetch(
                            'questions',
                            queryset=EducationQuizQuestion.objects.order_by('sort_order'),
                        )
                    )
                    .order_by('sort_order'),
                ),
            )
            .order_by('sort_order')
        )
        latest = categories.order_by('-updated_at').values_list('updated_at', flat=True).first()
        return Response({
            'updatedAt': latest or timezone.now(),
            'categories': EducationCategorySerializer(categories, many=True).data,
        })


class EducationCategoryDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, slug):
        try:
            category = (
                EducationCategory.objects.filter(is_active=True, slug=slug)
                .prefetch_related(
                    Prefetch(
                        'articles',
                        queryset=EducationArticle.objects.filter(is_active=True).order_by('sort_order'),
                    ),
                    Prefetch(
                        'quizzes',
                        queryset=EducationQuiz.objects.filter(is_active=True)
                        .prefetch_related('questions')
                        .order_by('sort_order'),
                    ),
                )
                .get()
            )
        except EducationCategory.DoesNotExist:
            return Response({'detail': 'Category not found.'}, status=404)
        return Response(EducationCategorySerializer(category).data)


class EducationArticleDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, category_slug, article_slug):
        try:
            article = EducationArticle.objects.select_related('category').get(
                is_active=True,
                category__slug=category_slug,
                category__is_active=True,
                slug=article_slug,
            )
        except EducationArticle.DoesNotExist:
            return Response({'detail': 'Article not found.'}, status=404)
        return Response(EducationArticleSerializer(article).data)


class EducationQuizDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, quiz_slug):
        try:
            quiz = (
                EducationQuiz.objects.filter(is_active=True, slug=quiz_slug)
                .prefetch_related(
                    Prefetch(
                        'questions',
                        queryset=EducationQuizQuestion.objects.order_by('sort_order'),
                    )
                )
                .get()
            )
        except EducationQuiz.DoesNotExist:
            return Response({'detail': 'Quiz not found.'}, status=404)
        return Response(EducationQuizSerializer(quiz).data)
