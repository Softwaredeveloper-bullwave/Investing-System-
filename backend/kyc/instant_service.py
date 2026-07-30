"""Instant KYC — typed PAN (Eko PAN Lite) + Aadhaar (Eko DigiLocker), no
photo uploads and no admin review. Replaces the manual photo-upload flow
(`kyc.manual_service`) as the app's primary KYC path; that module is left
in place (still used by the admin panel / existing KYCRequest rows) rather
than deleted, so nothing already reviewed or in-flight breaks.
"""

from __future__ import annotations

import logging
from datetime import date

from django.conf import settings
from django.utils import timezone

from accounts.models import User
from services.providers.eko_digilocker import EkoDigilockerError, create_digilocker_url, get_digilocker_status
from services.providers.eko_pan import EkoPanError, verify_pan

from .models import KycProfile

logger = logging.getLogger('bullwave.kyc')


class InstantKycError(Exception):
    """User-facing KYC error — message is safe to show as-is."""

    def __init__(self, message, code=''):
        super().__init__(message)
        self.code = code


def _normalize_pan(pan: str) -> str:
    return (pan or '').upper().strip().replace(' ', '')


def _validate_pan_format(pan: str) -> None:
    import re

    if not re.fullmatch(r'[A-Z]{5}[0-9]{4}[A-Z]', pan):
        raise InstantKycError('Invalid PAN format. Example: ABCDE1234F', 'invalid_pan_format')


def get_instant_kyc_status(user: User) -> dict:
    """Current state of the instant PAN + Aadhaar flow for this user."""
    profile = getattr(user, 'kyc_profile', None)
    if profile is None:
        profile, _ = KycProfile.objects.get_or_create(user=user)

    return {
        'pan_status': profile.pan_status,
        'pan_number': profile.pan_number,
        'pan_name': profile.pan_name,
        'pan_verified_at': profile.pan_verified_at.isoformat() if profile.pan_verified_at else None,
        'pan_failure_reason': profile.pan_failure_reason,
        'aadhaar_status': profile.aadhaar_status,
        'aadhaar_started': bool(profile.aadhaar_reference_id),
        'aadhaar_name': profile.aadhaar_name,
        'aadhaar_last4': profile.aadhaar_last4,
        'aadhaar_verified_at': profile.aadhaar_verified_at.isoformat() if profile.aadhaar_verified_at else None,
        'aadhaar_failure_reason': profile.aadhaar_failure_reason,
        'overall_status': profile.overall_status,
        'kyc_status': user.kyc_status,
    }


def _maybe_complete_kyc(user: User, profile: KycProfile) -> None:
    """Once both PAN and Aadhaar are verified, mark the whole KYC as done —
    no admin review in this flow, per product decision (fully automatic)."""
    if profile.pan_status == KycProfile.VerificationStatus.VERIFIED and \
            profile.aadhaar_status == KycProfile.VerificationStatus.VERIFIED:
        now = timezone.now()
        profile.overall_status = KycProfile.OverallStatus.VERIFIED
        profile.verified_at = now
        profile.mobile_verified = True
        profile.save(update_fields=['overall_status', 'verified_at', 'mobile_verified'])

        user.kyc_status = User.KycStatus.VERIFIED
        user.pan_status = User.PanStatus.VERIFIED
        user.save(update_fields=['kyc_status', 'pan_status'])


def verify_pan_instant(user: User, *, pan_number: str, full_name: str, dob: date) -> dict:
    """Step 1 — instant PAN verification via Eko PAN Lite. Raises
    InstantKycError with a user-safe message on any failure (invalid
    format, Eko mismatch, Eko/network error) — the caller should keep the
    PAN form visible and show the message as-is."""
    pan = _normalize_pan(pan_number)
    _validate_pan_format(pan)
    name = (full_name or user.name or '').strip()
    if len(name) < 2:
        raise InstantKycError('Enter your full name as per PAN.', 'invalid_name')

    profile, _ = KycProfile.objects.get_or_create(user=user)

    try:
        result = verify_pan(pan, name, dob.isoformat(), client_ref_id=str(user.id))
    except EkoPanError as exc:
        profile.pan_status = KycProfile.VerificationStatus.FAILED
        profile.pan_failure_reason = str(exc)[:280]
        profile.save(update_fields=['pan_status', 'pan_failure_reason'])
        logger.info('Instant PAN verification failed for %s: %s', user.phone, exc)
        raise InstantKycError(str(exc), exc.code) from exc

    now = timezone.now()
    profile.pan_number = pan
    profile.pan_name = result.get('registered_name') or name
    profile.pan_status = KycProfile.VerificationStatus.VERIFIED
    profile.pan_reference_id = result.get('reference_id', '') or ''
    profile.pan_verified_at = now
    profile.pan_failure_reason = ''
    profile.name_match_result = result.get('name_match_result', '') or ''
    profile.name_match_score = result.get('name_match_score') or 0
    profile.name_match_passed = result.get('name_match_result') == 'DIRECT_MATCH'
    profile.name_match_checked_at = now
    profile.save()

    user.name = user.name or name
    user.date_of_birth = user.date_of_birth or dob
    user.pan_status = User.PanStatus.VERIFIED
    user.save(update_fields=['name', 'date_of_birth', 'pan_status'])

    logger.info('Instant PAN verified for %s', user.phone)
    return get_instant_kyc_status(user)


def start_aadhaar_verification(user: User, *, redirect_url: str = '') -> dict:
    """Step 2a — kicks off a DigiLocker Aadhaar verification session and
    returns the URL the client should open."""
    profile = getattr(user, 'kyc_profile', None)
    if profile is None or profile.pan_status != KycProfile.VerificationStatus.VERIFIED:
        raise InstantKycError('Verify your PAN first.', 'pan_not_verified')

    redirect = redirect_url or getattr(settings, 'DIGILOCKER_REDIRECT_URL', '') or 'https://capitalbullwave.com/kyc/digilocker-complete'

    try:
        result = create_digilocker_url(redirect, client_ref_id=str(user.id))
    except EkoDigilockerError as exc:
        logger.error('DigiLocker start failed for %s: %s', user.phone, exc)
        raise InstantKycError(str(exc), exc.code) from exc

    profile.aadhaar_status = KycProfile.VerificationStatus.PENDING
    profile.aadhaar_reference_id = result['reference_id']
    profile.aadhaar_failure_reason = ''
    profile.save(update_fields=['aadhaar_status', 'aadhaar_reference_id', 'aadhaar_failure_reason'])

    return {
        'reference_id': result['reference_id'],
        'url': result['url'],
    }


def check_aadhaar_verification(user: User) -> dict:
    """Step 2b — polled by the client after the user opens the DigiLocker
    URL. Returns the current status; only raises InstantKycError on a
    genuine API failure, NOT while the user just hasn't finished the
    DigiLocker journey yet (that's a normal 'still pending' state)."""
    profile = getattr(user, 'kyc_profile', None)
    if profile is None or not profile.aadhaar_reference_id:
        raise InstantKycError('Start Aadhaar verification first.', 'not_started')

    if profile.aadhaar_status == KycProfile.VerificationStatus.VERIFIED:
        return get_instant_kyc_status(user)

    try:
        result = get_digilocker_status(profile.aadhaar_reference_id, client_ref_id=str(user.id))
    except EkoDigilockerError as exc:
        logger.error('DigiLocker status check failed for %s: %s', user.phone, exc)
        raise InstantKycError(str(exc), exc.code) from exc

    if not result['verified']:
        # Not a failure — the user just hasn't completed the DigiLocker
        # journey yet. Leave status as PENDING and let the client poll again.
        return get_instant_kyc_status(user)

    now = timezone.now()
    profile.aadhaar_status = KycProfile.VerificationStatus.VERIFIED
    profile.aadhaar_name = result['name']
    profile.aadhaar_dob = result['dob']
    profile.aadhaar_verified_at = now
    profile.aadhaar_failure_reason = ''
    profile.save(update_fields=[
        'aadhaar_status', 'aadhaar_name', 'aadhaar_dob', 'aadhaar_verified_at', 'aadhaar_failure_reason',
    ])

    _maybe_complete_kyc(user, profile)
    logger.info('Aadhaar verified via DigiLocker for %s', user.phone)
    return get_instant_kyc_status(user)
