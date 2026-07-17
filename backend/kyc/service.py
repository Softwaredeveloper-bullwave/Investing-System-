"""KYC business logic — orchestrates Cashfree verification steps."""

import logging
import re
from difflib import SequenceMatcher

from django.conf import settings
from django.utils import timezone

from accounts.models import BankAccount, User
from services.providers.cashfree_config import cashfree_settings
from services.providers.cashfree_secure_id import CashfreeSecureIdError
from core.integrations.cashfree_bypass import verify_bank_with_bypass, verify_pan_with_bypass

from .masking import mask_account_number, mask_pan
from .models import KycProfile, VerificationAuditLog

logger = logging.getLogger('bullwave.kyc')

PAN_REGEX = re.compile(r'^[A-Z]{5}[0-9]{4}[A-Z]$')
IFSC_REGEX = re.compile(r'^[A-Z]{4}0[A-Z0-9]{6}$')
ACCOUNT_REGEX = re.compile(r'^\d{9,18}$')

NAME_MATCH_PASS = frozenset({'DIRECT_MATCH', 'GOOD_PARTIAL_MATCH', 'MODERATE_PARTIAL_MATCH'})


def _cashfree_pan(pan: str, holder_name: str) -> dict:
    return verify_pan_with_bypass(pan, holder_name)


def _cashfree_bank(*, bank_account: str, ifsc: str, name: str, phone: str) -> dict:
    return verify_bank_with_bypass(
        bank_account=bank_account,
        ifsc=ifsc,
        name=name,
        phone=phone,
    )


def get_or_create_profile(user) -> KycProfile:
    profile, _ = KycProfile.objects.get_or_create(user=user)
    if user.phone and not profile.mobile_verified:
        profile.mobile_verified = True
        profile.save(update_fields=['mobile_verified'])
    return profile


def _audit(user, step, status, request_meta=None, response_meta=None, message=''):
    VerificationAuditLog.objects.create(
        user=user,
        step=step,
        status=status,
        message=message[:500],
        request_meta=request_meta or {},
        response_meta=response_meta or {},
    )


def _normalize_name(value: str) -> str:
    return re.sub(r'[^A-Z0-9 ]', '', (value or '').upper()).strip()


def _name_similarity(a: str, b: str) -> float:
    if not a or not b:
        return 0.0
    return SequenceMatcher(None, _normalize_name(a), _normalize_name(b)).ratio()


def verify_pan_step(user, pan: str, holder_name: str = '') -> KycProfile:
    pan = pan.upper().strip()
    if not PAN_REGEX.match(pan):
        raise ValueError('Invalid PAN format.')

    profile = get_or_create_profile(user)
    _audit(user, VerificationAuditLog.Step.PAN, VerificationAuditLog.Status.STARTED, {'pan': mask_pan(pan)})

    if not cashfree_settings().is_configured:
        raise CashfreeSecureIdError('Cashfree Secure ID is not configured.')

    try:
        result = _cashfree_pan(pan, holder_name or profile.pan_name or user.name)
    except CashfreeSecureIdError as exc:
        profile.pan_status = KycProfile.VerificationStatus.FAILED
        profile.pan_failure_reason = str(exc)[:280]
        profile.save(update_fields=['pan_status', 'pan_failure_reason'])
        _audit(user, VerificationAuditLog.Step.PAN, VerificationAuditLog.Status.FAILED, message=str(exc))
        raise

    profile.pan_number = pan
    profile.pan_name = result['registered_name'] or holder_name
    profile.pan_status = KycProfile.VerificationStatus.VERIFIED
    profile.pan_reference_id = result.get('reference_id', '')
    profile.pan_verified_at = timezone.now()
    profile.pan_failure_reason = ''
    profile.save()
    _update_overall_status(profile)
    _audit(user, VerificationAuditLog.Step.PAN, VerificationAuditLog.Status.SUCCESS, response_meta=result)
    return profile


def verify_bank_step(
    user,
    *,
    account_holder_name: str,
    account_number: str,
    confirm_account_number: str,
    ifsc: str,
) -> KycProfile:
    account_holder_name = account_holder_name.strip()
    account_number = re.sub(r'\s', '', account_number)
    confirm_account_number = re.sub(r'\s', '', confirm_account_number)
    ifsc = ifsc.upper().strip()

    if account_number != confirm_account_number:
        raise ValueError('Account numbers do not match.')
    if not ACCOUNT_REGEX.match(account_number):
        raise ValueError('Account number must be 9–18 digits.')
    if not IFSC_REGEX.match(ifsc):
        raise ValueError('Invalid IFSC format.')

    profile = get_or_create_profile(user)
    if profile.pan_status != KycProfile.VerificationStatus.VERIFIED:
        raise ValueError('Verify PAN before bank verification.')

    _audit(
        user,
        VerificationAuditLog.Step.BANK,
        VerificationAuditLog.Status.STARTED,
        {'account': mask_account_number(account_number), 'ifsc': ifsc},
    )

    if not cashfree_settings().is_configured:
        raise CashfreeSecureIdError('Cashfree Secure ID is not configured.')

    try:
        result = _cashfree_bank(
            bank_account=account_number,
            ifsc=ifsc,
            name=account_holder_name,
            phone=user.phone,
        )
    except CashfreeSecureIdError as exc:
        profile.bank_status = KycProfile.VerificationStatus.FAILED
        profile.bank_failure_reason = str(exc)[:280]
        profile.save(update_fields=['bank_status', 'bank_failure_reason'])
        _audit(user, VerificationAuditLog.Step.BANK, VerificationAuditLog.Status.FAILED, message=str(exc))
        raise

    profile.account_holder_name = account_holder_name
    profile.bank_account_number = account_number
    profile.bank_ifsc = ifsc
    profile.bank_name = result.get('bank_name', '')[:120]
    profile.bank_branch = result.get('branch', '')[:120]
    profile.name_at_bank = result.get('name_at_bank', '')[:120]
    profile.bank_status = KycProfile.VerificationStatus.VERIFIED
    profile.bank_reference_id = result.get('reference_id', '')
    profile.bank_verified_at = timezone.now()
    profile.bank_failure_reason = ''
    profile.save()
    _sync_bank_account(user, profile)
    _update_overall_status(profile)
    _audit(user, VerificationAuditLog.Step.BANK, VerificationAuditLog.Status.SUCCESS, response_meta=result)
    return profile


def name_match_step(user) -> KycProfile:
    profile = get_or_create_profile(user)
    _audit(user, VerificationAuditLog.Step.NAME_MATCH, VerificationAuditLog.Status.STARTED)

    if profile.pan_status != KycProfile.VerificationStatus.VERIFIED:
        raise ValueError('PAN must be verified first.')
    if profile.bank_status != KycProfile.VerificationStatus.VERIFIED:
        raise ValueError('Bank must be verified first.')

    pan_name = profile.pan_name or profile.account_holder_name
    bank_name = profile.name_at_bank or profile.account_holder_name
    score = _name_similarity(pan_name, bank_name)

    if score >= 0.72:
        result_label = 'DIRECT_MATCH' if score >= 0.92 else 'GOOD_PARTIAL_MATCH'
        profile.name_match_result = result_label
        profile.name_match_score = round(score * 100, 2)
        profile.name_match_passed = True
    else:
        profile.name_match_result = 'NO_MATCH'
        profile.name_match_score = round(score * 100, 2)
        profile.name_match_passed = False

    profile.name_match_checked_at = timezone.now()
    profile.save()
    _update_overall_status(profile)

    status = (
        VerificationAuditLog.Status.SUCCESS
        if profile.name_match_passed
        else VerificationAuditLog.Status.FAILED
    )
    _audit(
        user,
        VerificationAuditLog.Step.NAME_MATCH,
        status,
        response_meta={'score': profile.name_match_score, 'result': profile.name_match_result},
    )
    return profile


def _sync_bank_account(user, profile: KycProfile):
    BankAccount.objects.update_or_create(
        user=user,
        defaults={
            'account_holder_name': profile.account_holder_name,
            'bank_name': profile.bank_name,
            'account_number': profile.bank_account_number,
            'ifsc': profile.bank_ifsc,
            'pan_number': profile.pan_number,
            'is_verified': profile.name_match_passed and profile.bank_status == KycProfile.VerificationStatus.VERIFIED,
            'verification_provider': 'cashfree',
            'verification_status': 'verified' if profile.bank_status == KycProfile.VerificationStatus.VERIFIED else 'pending',
            'name_at_bank': profile.name_at_bank,
            'name_match_result': profile.name_match_result,
            'pan_registered_name': profile.pan_name,
            'verified_at': profile.bank_verified_at,
        },
    )


def _update_overall_status(profile: KycProfile):
    user = profile.user
    if (
        profile.mobile_verified
        and profile.pan_status == KycProfile.VerificationStatus.VERIFIED
        and profile.bank_status == KycProfile.VerificationStatus.VERIFIED
        and profile.name_match_passed
    ):
        profile.overall_status = KycProfile.OverallStatus.VERIFIED
        profile.verified_at = timezone.now()
        user.kyc_status = User.KycStatus.COMPLETED
        user.pan_status = User.PanStatus.VERIFIED
    elif profile.pan_status == KycProfile.VerificationStatus.FAILED or profile.bank_status == KycProfile.VerificationStatus.FAILED:
        profile.overall_status = KycProfile.OverallStatus.REJECTED
    elif profile.name_match_checked_at and not profile.name_match_passed:
        profile.overall_status = KycProfile.OverallStatus.REJECTED
    else:
        profile.overall_status = KycProfile.OverallStatus.PENDING
        if profile.pan_status == KycProfile.VerificationStatus.VERIFIED or profile.bank_status == KycProfile.VerificationStatus.VERIFIED:
            user.kyc_status = User.KycStatus.IN_PROGRESS
    profile.save()
    user.save(update_fields=['kyc_status', 'pan_status'])


def build_status_payload(profile: KycProfile) -> dict:
    return {
        'mobileVerified': profile.mobile_verified,
        'panVerified': profile.pan_status == KycProfile.VerificationStatus.VERIFIED,
        'bankVerified': profile.bank_status == KycProfile.VerificationStatus.VERIFIED,
        'nameMatchPassed': profile.name_match_passed,
        'overallStatus': profile.overall_status,
        'panNumberMasked': mask_pan(profile.pan_number) if profile.pan_number else '',
        'panName': profile.pan_name,
        'panStatus': profile.pan_status,
        'bankName': profile.bank_name,
        'bankBranch': profile.bank_branch,
        'accountHolderName': profile.account_holder_name,
        'bankAccountMasked': mask_account_number(profile.bank_account_number),
        'ifsc': profile.bank_ifsc,
        'bankStatus': profile.bank_status,
        'nameAtBank': profile.name_at_bank,
        'nameMatchResult': profile.name_match_result,
        'nameMatchScore': float(profile.name_match_score or 0),
        'verifiedAt': profile.verified_at.isoformat() if profile.verified_at else None,
    }
