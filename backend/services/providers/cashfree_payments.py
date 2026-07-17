"""Cashfree Payment Gateway — order creation and webhook verification."""

import hashlib
import hmac
import logging
import uuid
from decimal import Decimal

import httpx

from .cashfree_config import cashfree_settings

logger = logging.getLogger('bullwave.payments')


class CashfreePaymentError(Exception):
    def __init__(self, message, code=''):
        super().__init__(message)
        self.code = code


def is_configured() -> bool:
    return cashfree_settings().is_configured


def _pg_headers(cfg) -> dict:
    return {
        'x-client-id': cfg.client_id,
        'x-client-secret': cfg.client_secret,
        'x-api-version': cfg.payment_api_version,
        'Content-Type': 'application/json',
    }


def create_payment_order(
    *,
    amount_inr: Decimal,
    customer_id: str,
    customer_phone: str,
    customer_email: str = '',
    return_url: str = '',
) -> dict:
    cfg = cashfree_settings()
    if not cfg.is_configured:
        raise CashfreePaymentError('Cashfree Payments credentials are not configured.')

    order_id = f'bw_{uuid.uuid4().hex[:16]}'
    payload = {
        'order_id': order_id,
        'order_amount': float(amount_inr),
        'order_currency': 'INR',
        'customer_details': {
            'customer_id': customer_id,
            'customer_phone': customer_phone,
            'customer_email': customer_email or f'{customer_phone}@bullwave.app',
        },
    }
    if return_url:
        payload['order_meta'] = {'return_url': return_url, 'notify_url': return_url}

    url = f'{cfg.payments_base_url.rstrip("/")}/orders'
    try:
        with httpx.Client(timeout=30) as client:
            response = client.post(url, json=payload, headers=_pg_headers(cfg))
    except httpx.HTTPError as exc:
        raise CashfreePaymentError(f'Cashfree Payments connection failed: {exc}') from exc

    data = response.json() if response.content else {}
    if response.is_error:
        raise CashfreePaymentError(
            data.get('message') or data.get('error') or f'Payment order failed ({response.status_code})'
        )

    return {
        'order_id': data.get('order_id') or order_id,
        'payment_session_id': data.get('payment_session_id', ''),
        'order_amount': float(amount_inr),
        'order_currency': 'INR',
        'environment': 'PRODUCTION' if cfg.is_production else 'SANDBOX',
    }


def verify_payment_webhook(raw_body: bytes, signature: str, timestamp: str = '') -> bool:
    cfg = cashfree_settings()
    secret = cfg.webhook_secret
    if not secret:
        logger.warning('CASHFREE_PAYMENT_WEBHOOK_SECRET not set — webhook rejected.')
        return False

    signed_payload = timestamp + raw_body.decode('utf-8') if timestamp else raw_body.decode('utf-8')
    expected = hmac.new(secret.encode(), signed_payload.encode(), hashlib.sha256).digest()
    import base64

    try:
        received = base64.b64decode(signature)
    except Exception:
        return False
    return hmac.compare_digest(expected, received)
