from django.conf import settings
from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .views import (
    BankAccountView,
    BankVerifyView,
    CompleteProfileView,
    DevLoginView,
    KycDocumentListView,
    KycStatusView,
    ProfileAvatarView,
    ProfileView,
    ResendEmailOTPView,
    SendOTPView,
    SetLoginEmailView,
    VerifyEmailOTPView,
    VerifyOTPView,
)

urlpatterns = [
    path('auth/send-otp/', SendOTPView.as_view(), name='send-otp'),
    path('auth/verify-otp/', VerifyOTPView.as_view(), name='verify-otp'),
    path('auth/set-login-email/', SetLoginEmailView.as_view(), name='set-login-email'),
    path('auth/verify-email-otp/', VerifyEmailOTPView.as_view(), name='verify-email-otp'),
    path('auth/resend-email-otp/', ResendEmailOTPView.as_view(), name='resend-email-otp'),
    path('auth/token/refresh/', TokenRefreshView.as_view(), name='token-refresh'),
    path('users/me/', ProfileView.as_view(), name='profile'),
    path('users/me/complete-profile/', CompleteProfileView.as_view(), name='complete-profile'),
    path('users/me/avatar/', ProfileAvatarView.as_view(), name='profile-avatar'),
    path('bank/', BankAccountView.as_view(), name='bank'),
    path('bank/verify/', BankVerifyView.as_view(), name='bank-verify'),
    path('kyc/documents/', KycDocumentListView.as_view(), name='kyc-documents'),
    # Manual KYC submit is handled by kyc app at /api/v1/kyc/submit/
    path('kyc/status/', KycStatusView.as_view(), name='kyc-status'),
]

if settings.DEBUG:
    urlpatterns.insert(2, path('auth/dev-login/', DevLoginView.as_view(), name='dev-login'))
