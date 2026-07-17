"""Cashfree Secure ID — PAN and bank verification."""

import logging

import httpx

from .cashfree_config import cashfree_settings

logger = logging.getLogger('bullwave.kyc')

ACCEPTABLE_NAME_MATCHES = frozenset(
    {'DIRECT_MATCH', 'GOOD_PARTIAL_MATCH', 'MODERATE_PARTIAL_MATCH'}
)
BANK_NAME_REJECT_MATCHES = frozenset({'NO_MATCH', 'POOR_PARTIAL_MATCH'})


class CashfreeSecureIdError(Exception):
    def __init__(self, message, code=''):
        super().__init__(message)
        self.code = code


def is_configured() -> bool:
    return cashfree_settings().is_configured


def _headers(cfg) -> dict:
    return {
        'x-client-id': cfg.client_id,
        'x-client-secret': cfg.client_secret,
        'x-api-version': cfg.api_version,
        'Content-Type': 'application/json',
    }


def _post(path: str, payload: dict) -> dict:
    cfg = cashfree_settings()
    if not cfg.is_configured:
        raise CashfreeSecureIdError('Cashfree Secure ID credentials are not configured.')

    url = f'{cfg.secure_id_base_url.rstrip("/")}{path}'
    try:
        with httpx.Client(timeout=45) as client:
            response = client.post(url, json=payload, headers=_headers(cfg))
    except httpx.HTTPError as exc:
        raise CashfreeSecureIdError(f'Cashfree connection failed: {exc}') from exc

    data = {}
    try:
        data = response.json()
    except Exception:
        pass

    if response.status_code == 401:
        raise CashfreeSecureIdError('Invalid Cashfree credentials.', 'auth_failed')
    if response.status_code == 403:
        raise CashfreeSecureIdError(
            data.get('message') or 'Access denied. Whitelist server IP in Cashfree dashboard.',
            'access_denied',
        )
    if response.is_error:
        message = (
            data.get('message')
            or (data.get('error') or {}).get('message')
            or response.text[:240]
            or f'Cashfree error ({response.status_code})'
        )
        code = _error_code(message, response.status_code)
        raise CashfreeSecureIdError(message, code)

    return data


def _error_code(message: str, status_code: int) -> str:
    lowered = (message or '').lower()
    if 'ip not whitelisted' in lowered or 'ip whitelisting' in lowered:
        return 'ip_not_whitelisted'
    if status_code == 403:
        return 'access_denied'
    return ''


def verify_pan(pan: str, name: str = '') -> dict:
    payload = {'pan': pan.upper().strip()}
    if name:
        payload['name'] = name.strip()

    data = _post('/pan', payload)
    if not data.get('valid'):
        message = data.get('message') or 'Invalid PAN or PAN not found.'
        raise CashfreeSecureIdError(message, 'invalid_pan')

    match_result = (data.get('name_match_result') or '').upper()
    if name and match_result in {'NO_MATCH', 'POOR_PARTIAL_MATCH'}:
        registered = data.get('registered_name') or data.get('name_pan_card') or ''
        hint = f' Registered name: {registered}.' if registered else ''
        raise CashfreeSecureIdError(
            (data.get('message') or 'Name on PAN does not match the name you entered.') + hint,
            'name_mismatch',
        )

    return {
        'reference_id': str(data.get('reference_id', '')),
        'registered_name': data.get('registered_name') or data.get('name_pan_card') or '',
        'pan_type': data.get('type', ''),
        'name_match_result': match_result,
        'name_match_score': data.get('name_match_score'),
        'valid': True,
    }


def verify_bank_account(*, bank_account: str, ifsc: str, name: str = '', phone: str = '') -> dict:
    payload = {'bank_account': bank_account.strip(), 'ifsc': ifsc.upper().strip()}
    if name:
        payload['name'] = name.strip()
    if phone:
        payload['phone'] = phone.strip()

    data = _post('/bank-account/sync', payload)
    status = (data.get('account_status') or '').upper()
    if status != 'VALID':
        code = data.get('account_status_code', 'INVALID')
        raise CashfreeSecureIdError(_bank_error_message(code), code.lower())

    return {
        'reference_id': str(data.get('reference_id', '')),
        'name_at_bank': data.get('name_at_bank') or '',
        'bank_name': data.get('bank_name') or '',
        'branch': data.get('branch') or '',
        'city': data.get('city') or '',
        'name_match_result': (data.get('name_match_result') or '').upper(),
        'name_match_score': data.get('name_match_score'),
        'account_status': status,
    }


def _bank_error_message(code: str) -> str:
    return {
        'INVALID_ACCOUNT_FAIL': 'Bank account number is invalid.',
        'INVALID_IFSC_FAIL': 'IFSC code is invalid.',
        'ACCOUNT_BLOCKED': 'This bank account is blocked.',
        'NRE_ACCOUNT_FAIL': 'NRE accounts are not supported.',
    }.get(code, f'Bank verification failed ({code}).')
