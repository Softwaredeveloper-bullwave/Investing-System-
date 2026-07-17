from django.urls import path

from .views import (
    EducationArticleDetailView,
    EducationCatalogView,
    EducationCategoryDetailView,
    EducationQuizDetailView,
)

urlpatterns = [
    path('education/catalog/', EducationCatalogView.as_view(), name='education-catalog'),
    path('education/categories/<slug:slug>/', EducationCategoryDetailView.as_view(), name='education-category'),
    path(
        'education/categories/<slug:category_slug>/articles/<slug:article_slug>/',
        EducationArticleDetailView.as_view(),
        name='education-article',
    ),
    path('education/quizzes/<slug:quiz_slug>/', EducationQuizDetailView.as_view(), name='education-quiz'),
]
