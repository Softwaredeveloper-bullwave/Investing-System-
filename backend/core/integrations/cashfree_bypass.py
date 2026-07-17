"""Sandbox/dev Cashfree fallbacks when IP is not whitelisted or API is blocked."""

import logging

from django.conf import settings

from services.providers.cashfree_config import cashfree_settings
from services.providers.cashfree_secure_id import CashfreeSecureIdError, verify_bank_account, verify_pan

logger = logging.getLogger('bullwave.kyc')


def sandbox_bypass_allowed() -> bool:
    """Dev/sandbox only — never bypass in production."""
    cfg = cashfree_settings()
    if cfg.is_production:
        return False
    return bool(getattr(settings, 'DEBUG', False) or getattr(settings, 'KYC_AUTO_APPROVE', False))


def should_bypass_cashfree(exc: CashfreeSecureIdError) -> bool:
    if not sandbox_bypass_allowed():
        return False
    # Invalid API keys must be fixed — do not mask auth failures.
    if exc.code == 'auth_failed':
        return False
    return True


def mock_pan_result(pan: str, holder_name: str) -> dict:
    name = (holder_name or 'Verified User').strip()
    return {
        'reference_id': f'sandbox-{pan[-4:]}',
        'registered_name': name,
        'pan_type': 'Individual',
        'name_match_result': 'DIRECT_MATCH',
        'name_match_score': 100,
        'valid': True,
        'dev_bypass': True,
    }


def mock_bank_result(*, account_holder_name: str, ifsc: str) -> dict:
    bank_name = 'Sandbox Bank'
    prefix = ifsc.upper()[:4]
    if prefix == 'HDFC':
        bank_name = 'HDFC Bank'
    elif prefix == 'SBIN':
        bank_name = 'State Bank of India'
    elif prefix == 'ICIC':
        bank_name = 'ICICI Bank'
    return {
        'reference_id': f'sandbox-{ifsc[-4:]}',
        'name_at_bank': account_holder_name,
        'bank_name': bank_name,
        'branch': 'Sandbox Branch',
        'city': 'Mumbai',
        'name_match_result': 'DIRECT_MATCH',
        'name_match_score': 100,
        'account_status': 'VALID',
        'dev_bypass': True,
    }


def verify_pan_with_bypass(pan: str, holder_name: str = '') -> dict:
    try:
        return verify_pan(pan, holder_name)
    except CashfreeSecureIdError as exc:
        if should_bypass_cashfree(exc):
            logger.warning(
                'Cashfree PAN blocked (%s) — sandbox dev bypass for %s',
                exc.code or 'error',
                pan[-4:].rjust(len(pan), '*') if pan else '****',
            )
            return mock_pan_result(pan, holder_name)
        raise


def verify_bank_with_bypass(
    *,
    bank_account: str,
    ifsc: str,
    name: str = '',
    phone: str = '',
) -> dict:
    try:
        return verify_bank_account(
            bank_account=bank_account,
            ifsc=ifsc,
            name=name,
            phone=phone,
        )
    except CashfreeSecureIdError as exc:
        if should_bypass_cashfree(exc):
            logger.warning(
                'Cashfree bank verify blocked (%s) — sandbox dev bypass for IFSC %s',
                exc.code or 'error',
                ifsc,
            )
            return mock_bank_result(account_holder_name=name, ifsc=ifsc)
        raise
