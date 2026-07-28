from django.urls import path

from .views import (
    AdminLoginView,
    AdminMeView,
    AdminUserActionView,
    AdminUserDetailView,
    AdminUserListView,
    AdminUserStatsView,
)

urlpatterns = [
    path('login/', AdminLoginView.as_view(), name='admin-login'),
    path('me/', AdminMeView.as_view(), name='admin-me'),
    path('users/', AdminUserListView.as_view(), name='admin-user-list'),
    path('users/stats/', AdminUserStatsView.as_view(), name='admin-user-stats'),
    path('users/<uuid:user_id>/', AdminUserDetailView.as_view(), name='admin-user-detail'),
    path('users/<uuid:user_id>/action/', AdminUserActionView.as_view(), name='admin-user-action'),
]
