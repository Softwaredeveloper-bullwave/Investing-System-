"""Cashfree Payouts — withdrawal to verified bank account."""

from __future__ import annotations

import logging
import uuid

import httpx

from .cashfree_config import cashfree_settings

logger = logging.getLogger('bullwave.payouts')


class CashfreePayoutError(Exception):
    def __init__(self, message, code=''):
        super().__init__(message)
        self.code = code


def is_configured() -> bool:
    return cashfree_settings().is_configured


def _authorize(cfg) -> str:
    url = f'{cfg.payouts_base_url.rstrip("/")}/authorize'
    try:
        with httpx.Client(timeout=30) as client:
            response = client.post(
                url,
                headers={
                    'X-Client-Id': cfg.client_id,
                    'X-Client-Secret': cfg.client_secret,
                },
            )
    except httpx.HTTPError as exc:
        raise CashfreePayoutError(f'Payout authorize failed: {exc}') from exc

    data = response.json() if response.content else {}
    if response.is_error:
        raise CashfreePayoutError(data.get('message') or 'Payout authorization failed.')

    token = data.get('data', {}).get('token') or data.get('token')
    if not token:
        raise CashfreePayoutError('Payout authorization token missing.')
    return token


def initiate_payout(
    *,
    amount: float,
    account_holder_name: str,
    account_number: str,
    ifsc: str,
    phone: str,
    transfer_id: str | None = None,
) -> dict:
    cfg = cashfree_settings()
    if not cfg.is_configured:
        raise CashfreePayoutError('Cashfree Payouts credentials are not configured.')

    token = _authorize(cfg)
    transfer_id = transfer_id or f'bw_payout_{uuid.uuid4().hex[:12]}'

    payload = {
        'transferId': transfer_id,
        'transferMode': 'banktransfer',
        'beneDetails': {
            'name': account_holder_name,
            'email': f'{phone}@bullwave.app',
            'phone': phone,
            'bankAccount': account_number,
            'ifsc': ifsc.upper(),
            'address1': 'India',
        },
        'amount': str(amount),
    }

    url = f'{cfg.payouts_base_url.rstrip("/")}/directTransfer'
    try:
        with httpx.Client(timeout=45) as client:
            response = client.post(
                url,
                json=payload,
                headers={
                    'Authorization': f'Bearer {token}',
                    'Content-Type': 'application/json',
                },
            )
    except httpx.HTTPError as exc:
        raise CashfreePayoutError(f'Payout transfer failed: {exc}') from exc

    data = response.json() if response.content else {}
    if response.is_error:
        raise CashfreePayoutError(data.get('message') or 'Payout initiation failed.')

    status = (data.get('status') or data.get('data', {}).get('status') or 'PENDING').upper()
    reference = data.get('referenceId') or data.get('data', {}).get('referenceId') or transfer_id

    return {
        'transfer_id': transfer_id,
        'reference_id': str(reference),
        'status': status,
        'raw': data,
    }


def verify_payout_webhook(raw_body: bytes, signature: str) -> bool:
    cfg = cashfree_settings()
    secret = cfg.payout_webhook_secret or cfg.webhook_secret
    if not secret:
        return False
    import hashlib
    import hmac

    expected = hmac.new(secret.encode(), raw_body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature or '')
