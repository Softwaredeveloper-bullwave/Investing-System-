"""Bank validation — Razorpay public IFSC lookup (free, no API key)."""

import logging
import re

import httpx

logger = logging.getLogger('bullwave.integrations')


class BankValidationError(Exception):
    pass


def validate_ifsc(ifsc: str) -> dict:
    code = (ifsc or '').upper().strip()
    if not re.match(r'^[A-Z]{4}0[A-Z0-9]{6}$', code):
        raise BankValidationError('Invalid IFSC format.')

    try:
        with httpx.Client(timeout=10) as client:
            response = client.get(f'https://ifsc.razorpay.com/{code}')
    except httpx.HTTPError as exc:
        raise BankValidationError(f'IFSC lookup failed: {exc}') from exc

    if response.status_code == 404:
        raise BankValidationError('IFSC code not found.')
    if response.is_error:
        raise BankValidationError('Unable to validate IFSC right now.')

    data = response.json()
    return {
        'bank': data.get('BANK', ''),
        'branch': data.get('BRANCH', ''),
        'city': data.get('CITY', ''),
        'state': data.get('STATE', ''),
        'ifsc': data.get('IFSC', code),
    }


def validate_account_number(account_number: str) -> None:
    acct = re.sub(r'\s', '', account_number or '')
    if not re.match(r'^\d{9,18}$', acct):
        raise BankValidationError('Account number must be 9–18 digits.')
