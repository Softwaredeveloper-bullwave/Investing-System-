"""Eko PAN Lite — PAN verification with name & date-of-birth match.

Docs: https://developers.eko.in/reference/pan-lite
Auth: https://developers.eko.in/docs/authentication (Security 2.0)
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import logging
import re
import time
import uuid

import httpx

from .eko_config import eko_settings

logger = logging.getLogger('bullwave.kyc')

_PAN_STATUS_MESSAGES = {
    'N': 'PAN not found in Income Tax records.',
    'X': 'This PAN has been deactivated.',
    'F': 'This PAN appears to be fake.',
    'D': 'This PAN has been deleted.',
}


class EkoPanError(Exception):
    def __init__(self, message, code=''):
        super().__init__(message)
        self.code = code


def is_configured() -> bool:
    return eko_settings().is_configured


def _secret_headers(key: str) -> tuple[str, str]:
    """Eko "Security 2.0" (per developers.eko.in/docs/authentication):

    1. base64-encode the raw `key` Eko gave you
    2. HMAC-SHA256(message=timestamp_ms, key=base64-encoded key from step 1)
    3. base64-encode that digest -> secret-key
    """
    timestamp = str(int(time.time() * 1000))
    encoded_key = base64.b64encode(key.strip().encode('utf-8'))
    digest = hmac.new(encoded_key, timestamp.encode('utf-8'), hashlib.sha256).digest()
    secret_key = base64.b64encode(digest).decode('utf-8')
    return secret_key, timestamp


def _pan_status_message(code: str) -> str:
    return _PAN_STATUS_MESSAGES.get((code or '').upper(), 'PAN could not be verified.')


def _plain_text_snippet(html_or_text: str, limit: int = 400) -> str:
    """Strip an HTML error page (e.g. a servlet-container 'Error report') down to
    its readable text so failures are diagnosable instead of a CSS dump."""
    text = html_or_text or ''
    text = re.sub(r'<style[\s\S]*?</style>', ' ', text, flags=re.IGNORECASE)
    text = re.sub(r'<[^>]+>', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text[:limit]


def verify_pan(pan: str, name: str, dob: str, *, client_ref_id: str = '') -> dict:
    """Verify PAN via Eko's PAN Lite API.

    `dob` must be an ISO date string (YYYY-MM-DD). Raises EkoPanError on any
    failure (not configured, network error, invalid PAN, or name mismatch).
    """
    cfg = eko_settings()
    if not cfg.is_configured:
        raise EkoPanError('Eko PAN verification is not configured.', 'not_configured')

    secret_key, secret_key_timestamp = _secret_headers(cfg.key)

    payload = {
        'initiator_id': cfg.initiator_id,
        'pan_number': pan.upper().strip(),
        'name': name.strip(),
        'dob': dob,
        'client_ref_id': client_ref_id or f'bw-{uuid.uuid4().hex[:16]}',
        'source': 'API',
    }
    if cfg.user_code:
        payload['user_code'] = cfg.user_code

    headers = {
        'developer_key': cfg.developer_key,
        'secret-key': secret_key,
        'secret-key-timestamp': secret_key_timestamp,
        'Content-Type': 'application/json',
    }

    url = f'{cfg.base_url.rstrip("/")}/ekoapi/{cfg.api_version}/tools/kyc/pan-lite'
    try:
        with httpx.Client(timeout=30) as client:
            response = client.post(url, json=payload, headers=headers)
    except httpx.HTTPError as exc:
        raise EkoPanError(f'Eko connection failed: {exc}') from exc

    try:
        body = response.json()
    except Exception:
        snippet = _plain_text_snippet(response.text)
        if response.status_code in (401, 403):
            raise EkoPanError(
                f'Eko rejected the request (HTTP {response.status_code}) — this is usually because '
                f'the developer_key/EKO_KEY was issued for a different environment (sandbox vs '
                f'production) than EKO_ENV, or your server IP is not whitelisted with Eko.'
                + (f' Eko said: {snippet}' if snippet else ''),
                'auth_failed',
            ) from None
        if response.status_code == 404 or 'no mapping rule' in snippet.lower():
            raise EkoPanError(
                'Eko: "No mapping rule matched" — this URL isn\'t routed for your account. '
                'Per Eko\'s docs, try setting EKO_API_VERSION=v2 (or v1) in .env instead of the '
                'default v3, and if that doesn\'t help, email Eko support with this exact request URL.'
                + (f' ({snippet})' if snippet else ''),
                'no_mapping_rule',
            ) from None
        raise EkoPanError(
            f'Unexpected Eko response (HTTP {response.status_code}).' + (f' {snippet}' if snippet else ''),
        ) from None

    if response.status_code == 401 or response.status_code == 403:
        raise EkoPanError(
            body.get('message') or 'Invalid Eko credentials or IP not whitelisted.',
            'auth_failed',
        )

    data = body.get('data') or {}
    if response.is_error and not data:
        message = body.get('message') or body.get('response_type_desc') or f'Eko error ({response.status_code}).'
        if 'no mapping rule' in message.lower():
            message += (
                ' — per Eko\'s docs, try EKO_API_VERSION=v2 (or v1) in .env, or email Eko '
                'support with this request URL if that doesn\'t help.'
            )
        raise EkoPanError(message, str(body.get('response_status_id', '')))

    status = (data.get('status') or '').upper()
    if status != 'VALID':
        raise EkoPanError(_pan_status_message(data.get('pan_status')), 'invalid_pan')

    name_match = (data.get('name_match') or '').upper()
    if name_match == 'N':
        registered = data.get('name') or ''
        hint = f' Registered name: {registered}.' if registered else ''
        raise EkoPanError(f'Name on PAN does not match the name you entered.{hint}', 'name_mismatch')

    dob_match = (data.get('dob_match') or '').upper()
    if dob_match == 'N':
        raise EkoPanError('Date of birth does not match PAN records.', 'dob_mismatch')

    logger.info('Eko PAN verified for %s (name_match=%s dob_match=%s)', pan[-4:].rjust(len(pan), '*'), name_match, dob_match)

    return {
        'reference_id': str(body.get('response_id') or data.get('client_ref_id') or payload['client_ref_id']),
        'registered_name': data.get('name') or name,
        'pan_type': '',
        'name_match_result': 'DIRECT_MATCH' if name_match == 'Y' else 'UNKNOWN',
        'name_match_score': 100 if name_match == 'Y' else None,
        'valid': True,
        'dob_match': dob_match,
        'aadhaar_seeding_status': data.get('aadhaar_seeding_status'),
        'provider': 'eko',
    }
