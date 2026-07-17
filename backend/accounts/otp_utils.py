"""Phone and OTP normalization for auth."""

import re


def normalize_phone(raw) -> str:
    """Return 10-digit Indian mobile or empty string."""
    digits = re.sub(r'\D', '', str(raw or ''))
    if len(digits) == 12 and digits.startswith('91'):
        digits = digits[2:]
    elif len(digits) == 11 and digits.startswith('0'):
        digits = digits[1:]
    return digits if len(digits) == 10 else ''


def normalize_otp(raw) -> str:
    """Return 6-digit OTP string."""
    digits = re.sub(r'\D', '', str(raw or ''))
    if len(digits) > 6:
        digits = digits[-6:]
    return digits
