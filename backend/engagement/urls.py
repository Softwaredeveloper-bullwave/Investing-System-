from django.urls import path

from .views import (
    ApplyReferralView,
    NotificationListView,
    NotificationMarkAllReadView,
    NotificationReadView,
    ReferralView,
    SupportFaqListView,
    SupportTicketListView,
)

urlpatterns = [
    path('notifications/', NotificationListView.as_view(), name='notifications'),
    path('notifications/mark-all-read/', NotificationMarkAllReadView.as_view(), name='notifications-mark-all'),
    path('notifications/<uuid:notification_id>/read/', NotificationReadView.as_view(), name='notification-read'),
    path('support/faqs/', SupportFaqListView.as_view(), name='support-faqs'),
    path('support/tickets/', SupportTicketListView.as_view(), name='support-tickets'),
    path('referrals/', ReferralView.as_view(), name='referrals'),
    path('referrals/apply/', ApplyReferralView.as_view(), name='referrals-apply'),
]
