"""Razorpay payments — orders, signature verify, webhooks."""

from __future__ import annotations

import hashlib
import hmac
import logging
import uuid
from decimal import Decimal

import httpx
from django.conf import settings

logger = logging.getLogger('bullwave.integrations')

BASE_URL = 'https://api.razorpay.com/v1'


class RazorpayError(Exception):
    pass


def is_configured() -> bool:
    return bool(_key_id() and _key_secret())


def _key_id() -> str:
    return (getattr(settings, 'RAZORPAY_KEY_ID', '') or '').strip()


def _key_secret() -> str:
    return (getattr(settings, 'RAZORPAY_KEY_SECRET', '') or '').strip()


def _auth():
    return (_key_id(), _key_secret())


def create_order(amount_inr: Decimal, receipt: str | None = None) -> dict:
    if not is_configured():
        raise RazorpayError('RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET are required.')

    amount_paise = int(amount_inr * 100)
    if amount_paise < 100:
        raise RazorpayError('Minimum deposit is ₹1.')

    payload = {
        'amount': amount_paise,
        'currency': 'INR',
        'receipt': receipt or f'bw_{uuid.uuid4().hex[:12]}',
        'payment_capture': 1,
    }
    try:
        with httpx.Client(timeout=20) as client:
            response = client.post(
                f'{BASE_URL}/orders',
                json=payload,
                auth=_auth(),
            )
    except httpx.HTTPError as exc:
        raise RazorpayError(f'Razorpay connection failed: {exc}') from exc

    if response.is_error:
        raise RazorpayError(f'Razorpay error ({response.status_code}): {response.text[:300]}')

    data = response.json()
    return {
        'order_id': data['id'],
        'amount': amount_inr,
        'amount_paise': amount_paise,
        'currency': data.get('currency', 'INR'),
        'key_id': _key_id(),
    }


def verify_payment_signature(order_id: str, payment_id: str, signature: str) -> bool:
    secret = _key_secret()
    if not secret:
        return False
    body = f'{order_id}|{payment_id}'
    expected = hmac.new(secret.encode(), body.encode(), hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature or '')


def verify_webhook_signature(body: bytes, signature: str) -> bool:
    webhook_secret = (getattr(settings, 'RAZORPAY_WEBHOOK_SECRET', '') or '').strip()
    if not webhook_secret:
        return False
    expected = hmac.new(webhook_secret.encode(), body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature or '')
