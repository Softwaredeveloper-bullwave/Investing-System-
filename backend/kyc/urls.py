from django.urls import path

from .manual_views import (
    AdminKycApproveView,
    AdminKycDetailView,
    AdminKycPendingListView,
    AdminKycRejectView,
    KycMeView,
    KycSubmitView,
)
from .email_action_views import (
    FnoEmailApproveView,
    FnoEmailRejectView,
    KycEmailApproveView,
    KycEmailRejectView,
)
from .fno_views import FnoMeView, FnoSubmitView
from .views import (
    KycStatusView,
    NameMatchView,
    SendOtpAliasView,
    VerifyBankView,
    VerifyOtpAliasView,
    VerifyPanView,
)

urlpatterns = [
    path('send-otp/', SendOtpAliasView.as_view(), name='send-otp'),
    path('verify-otp/', VerifyOtpAliasView.as_view(), name='verify-otp'),
    # Legacy Cashfree KYC (optional — manual flow uses /kyc/submit instead)
    path('verify-pan/', VerifyPanView.as_view(), name='verify-pan'),
    path('verify-bank/', VerifyBankView.as_view(), name='verify-bank'),
    path('name-match/', NameMatchView.as_view(), name='name-match'),
    path('kyc-status/', KycStatusView.as_view(), name='kyc-status'),
    # Manual admin-reviewed KYC
    path('kyc/submit/', KycSubmitView.as_view(), name='kyc-submit'),
    path('kyc/me/', KycMeView.as_view(), name='kyc-me'),
    # One-click review from admin email (signed token, no login)
    path('kyc/review/approve/', KycEmailApproveView.as_view(), name='kyc-email-approve'),
    path('kyc/review/reject/', KycEmailRejectView.as_view(), name='kyc-email-reject'),
    path('admin/kyc/pending/', AdminKycPendingListView.as_view(), name='admin-kyc-pending'),
    path('admin/kyc/<uuid:pk>/', AdminKycDetailView.as_view(), name='admin-kyc-detail'),
    path('admin/kyc/<uuid:pk>/approve/', AdminKycApproveView.as_view(), name='admin-kyc-approve'),
    path('admin/kyc/<uuid:pk>/reject/', AdminKycRejectView.as_view(), name='admin-kyc-reject'),
    # F&O eligibility
    path('fno/me/', FnoMeView.as_view(), name='fno-me'),
    path('fno/submit/', FnoSubmitView.as_view(), name='fno-submit'),
    path('fno/review/approve/', FnoEmailApproveView.as_view(), name='fno-email-approve'),
    path('fno/review/reject/', FnoEmailRejectView.as_view(), name='fno-email-reject'),
]
