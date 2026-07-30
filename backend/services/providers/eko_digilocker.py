"""Eko DigiLocker — instant Aadhaar verification via DigiLocker consent flow.

Docs: https://developers.eko.in/reference/create-digilocker-url
      https://developers.eko.in/reference/digilocker-verification-status
Auth: https://developers.eko.in/docs/authentication (Security 2.0)

Unlike a typed Aadhaar-number + OTP flow (which on Eko's platform is
actually part of their DMT/PPI money-transfer "Sender" onboarding product,
not a standalone customer-KYC API), DigiLocker is Eko's real general-purpose
Aadhaar verification product: the user is sent to DigiLocker's own site to
authenticate with their Aadhaar-linked DigiLocker account and consent to
sharing their e-Aadhaar, then we poll a status endpoint for the verified
name/DOB/gender once they're done.
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


class EkoDigilockerError(Exception):
    def __init__(self, message, code=''):
        super().__init__(message)
        self.code = code


def _secret_headers(key: str) -> tuple[str, str]:
    """Same "Security 2.0" scheme as eko_pan.py — see that module for the
    step-by-step breakdown. Duplicated here rather than shared because
    eko_pan.py doesn't currently export it as a public helper."""
    timestamp = str(int(time.time() * 1000))
    encoded_key = base64.b64encode(key.strip().encode('utf-8'))
    digest = hmac.new(encoded_key, timestamp.encode('utf-8'), hashlib.sha256).digest()
    secret_key = base64.b64encode(digest).decode('utf-8')
    return secret_key, timestamp


def _plain_text_snippet(html_or_text: str, limit: int = 400) -> str:
    text = html_or_text or ''
    text = re.sub(r'<style[\s\S]*?</style>', ' ', text, flags=re.IGNORECASE)
    text = re.sub(r'<[^>]+>', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text[:limit]


def _headers(cfg) -> dict:
    secret_key, secret_key_timestamp = _secret_headers(cfg.key)
    return {
        'developer_key': cfg.developer_key,
        'secret-key': secret_key,
        'secret-key-timestamp': secret_key_timestamp,
        'Content-Type': 'application/json',
    }


def _request(method: str, url: str, cfg, *, json=None, params=None) -> dict:
    try:
        with httpx.Client(timeout=30) as client:
            response = client.request(
                method, url, json=json, params=params, headers=_headers(cfg)
            )
    except httpx.HTTPError as exc:
        raise EkoDigilockerError(f'Eko connection failed: {exc}') from exc

    try:
        body = response.json()
    except Exception:
        snippet = _plain_text_snippet(response.text)
        if response.status_code in (401, 403):
            raise EkoDigilockerError(
                f'Eko rejected the request (HTTP {response.status_code}) — check your '
                f'developer_key/EKO_KEY, EKO_ENV, and that DigiLocker KYC is enabled '
                f'for your account.' + (f' Eko said: {snippet}' if snippet else ''),
                'auth_failed',
            ) from None
        raise EkoDigilockerError(
            f'Unexpected Eko response (HTTP {response.status_code}).' + (f' {snippet}' if snippet else ''),
        ) from None

    if response.status_code in (401, 403):
        raise EkoDigilockerError(
            body.get('message') or 'Invalid Eko credentials or IP not whitelisted.',
            'auth_failed',
        )

    data = body.get('data') or {}
    if response.is_error and not data:
        message = body.get('message') or body.get('response_type_desc') or f'Eko error ({response.status_code}).'
        raise EkoDigilockerError(message, str(body.get('response_status_id', '')))

    return data


def create_digilocker_url(redirect_url: str, *, client_ref_id: str = '') -> dict:
    """Starts a DigiLocker Aadhaar verification session.

    Returns {'reference_id', 'url', 'document_requested', 'redirect_url'}.
    `url` is where the user should be sent (in-app browser / external
    browser) to authenticate with DigiLocker and consent to sharing their
    Aadhaar. Raises EkoDigilockerError on any failure.
    """
    cfg = eko_settings()
    if not cfg.is_configured:
        raise EkoDigilockerError('Eko DigiLocker verification is not configured.', 'not_configured')

    payload = {
        'initiator_id': cfg.initiator_id,
        'client_ref_id': client_ref_id or f'bw-dl-{uuid.uuid4().hex[:16]}',
        'document_requested': ['AADHAAR'],
        'redirect_url': redirect_url,
    }
    if cfg.user_code:
        payload['user_code'] = cfg.user_code

    url = f'{cfg.base_url.rstrip("/")}/ekoapi/{cfg.api_version}/tools/kyc/digilocker'
    data = _request('POST', url, cfg, json=payload)

    reference_id = data.get('reference_id')
    dl_url = data.get('url')
    if not reference_id or not dl_url:
        raise EkoDigilockerError('Eko did not return a DigiLocker URL. Try again.')

    return {
        'reference_id': str(reference_id),
        'url': dl_url,
        'document_requested': data.get('document_requested') or ['AADHAAR'],
        'redirect_url': data.get('redirect_url') or redirect_url,
    }


def get_digilocker_status(reference_id: str, *, client_ref_id: str = '') -> dict:
    """Polls the status of a DigiLocker verification session.

    Returns {'verified': bool, 'name', 'dob', 'gender', 'has_eaadhaar',
    'mobile'}. `verified` is True once DigiLocker has returned real user
    details (name present); if the user hasn't completed the DigiLocker
    journey yet, Eko returns an empty/partial `user_details` rather than an
    error, so callers should keep polling instead of treating that as a
    failure. Raises EkoDigilockerError only on a genuine API failure.
    """
    cfg = eko_settings()
    if not cfg.is_configured:
        raise EkoDigilockerError('Eko DigiLocker verification is not configured.', 'not_configured')

    params = {
        'initiator_id': cfg.initiator_id,
        'client_ref_id': client_ref_id or f'bw-dls-{uuid.uuid4().hex[:16]}',
        'reference_id': reference_id,
    }
    url = f'{cfg.base_url.rstrip("/")}/ekoapi/{cfg.api_version}/tools/kyc/digilocker/status'
    data = _request('GET', url, cfg, params=params)

    user_details = data.get('user_details') or {}
    name = (user_details.get('name') or '').strip()

    return {
        'verified': bool(name),
        'name': name,
        'dob': user_details.get('dob') or '',
        'gender': user_details.get('gender') or '',
        'has_eaadhaar': bool(user_details.get('eaadhaar')),
        'mobile': user_details.get('mobile') or '',
        'document_requested': data.get('document_requested') or [],
    }
