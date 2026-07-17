"""Backward-compatible wrapper — use services.providers.cashfree_secure_id."""

from services.providers.cashfree_config import cashfree_settings
from services.providers.cashfree_secure_id import (
    ACCEPTABLE_NAME_MATCHES,
    BANK_NAME_REJECT_MATCHES,
    CashfreeSecureIdError,
    is_configured,
    verify_bank_account,
    verify_pan,
)

CashfreeError = CashfreeSecureIdError

__all__ = [
    'CashfreeError',
    'CashfreeSecureIdError',
    'is_configured',
    'verify_pan',
    'verify_bank_account',
    'ACCEPTABLE_NAME_MATCHES',
    'BANK_NAME_REJECT_MATCHES',
    'cashfree_settings',
]
