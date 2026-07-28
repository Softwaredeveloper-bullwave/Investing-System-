from django.urls import path

from .views import (
    AdminDashboardActivityView,
    AdminDashboardRevenueView,
    AdminKycActionView,
    AdminKycListView,
    AdminKycMessageView,
    AdminKycStatsView,
    AdminLoginView,
    AdminLogsStatsView,
    AdminLogsView,
    AdminMeView,
    AdminStockTradesView,
    AdminUserActionView,
    AdminUserDetailView,
    AdminUserListView,
    AdminUserMessageView,
    AdminUserStatsView,
)

urlpatterns = [
    path('login/', AdminLoginView.as_view(), name='admin-login'),
    path('me/', AdminMeView.as_view(), name='admin-me'),
    path('users/', AdminUserListView.as_view(), name='admin-user-list'),
    path('users/stats/', AdminUserStatsView.as_view(), name='admin-user-stats'),
    path('users/<uuid:user_id>/', AdminUserDetailView.as_view(), name='admin-user-detail'),
    path('users/<uuid:user_id>/action/', AdminUserActionView.as_view(), name='admin-user-action'),
    path('users/<uuid:user_id>/messages/', AdminUserMessageView.as_view(), name='admin-user-messages'),
    path('kyc/', AdminKycListView.as_view(), name='admin-kyc-list'),
    path('kyc/stats/', AdminKycStatsView.as_view(), name='admin-kyc-stats'),
    path('kyc/<uuid:kyc_id>/action/', AdminKycActionView.as_view(), name='admin-kyc-action'),
    path('kyc/<uuid:kyc_id>/message/', AdminKycMessageView.as_view(), name='admin-kyc-message'),
    path('trades/stocks/', AdminStockTradesView.as_view(), name='admin-trades-stocks'),
    path('logs/', AdminLogsView.as_view(), name='admin-logs'),
    path('logs/stats/', AdminLogsStatsView.as_view(), name='admin-logs-stats'),
    path('dashboard/activity/', AdminDashboardActivityView.as_view(), name='admin-dashboard-activity'),
    path('dashboard/revenue/', AdminDashboardRevenueView.as_view(), name='admin-dashboard-revenue'),
]
