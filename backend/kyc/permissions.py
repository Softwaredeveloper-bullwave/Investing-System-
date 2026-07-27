"""DRF permissions for KYC-gated resources."""

from django.conf import settings
from rest_framework.permissions import BasePermission, IsAuthenticated

from accounts.models import User

from .manual_service import user_kyc_is_verified
from .fno_service import user_fno_is_verified
from .models import KycProfile
from .service import get_or_create_profile


class IsKycVerified(BasePermission):
    message = 'Complete KYC verification to access markets.'

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        # TEMPORARY (requested 2026-07-22) — mirrors the frontend's
        # DevConfig.skipKycVerification. Reuses the existing KYC_AUTO_APPROVE
        # env flag (see accounts/views.py, cashfree_bypass.py for the same
        # convention) instead of a new one. Nothing about the Eko PAN/bank
        # integration was touched — set KYC_AUTO_APPROVE=False in .env to
        # restore real enforcement here.
        if getattr(settings, 'KYC_AUTO_APPROVE', False):
            return True
        if user_kyc_is_verified(request.user):
            return True
        # Legacy Cashfree profile check
        profile = get_or_create_profile(request.user)
        return profile.overall_status == KycProfile.OverallStatus.VERIFIED


class IsFnoVerified(BasePermission):
    message = 'Complete F&O eligibility verification to access derivatives.'

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return user_fno_is_verified(request.user)


# Browse quotes, news, commodities — login only.
MARKET_BROWSE_PERMISSIONS = [IsAuthenticated]

# Trading, funding, alerts — full KYC.
MARKET_TRADE_PERMISSIONS = [IsAuthenticated, IsKycVerified]
