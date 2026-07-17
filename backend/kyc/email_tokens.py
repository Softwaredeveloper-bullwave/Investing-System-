"""Signed, time-limited tokens for one-click KYC / F&O approve/reject from admin email."""

from django.core.signing import BadSignature, SignatureExpired, TimestampSigner

_MAX_AGE_SECONDS = 7 * 24 * 60 * 60  # 7 days

VALID_ACTIONS = frozenset({'approve', 'reject'})

_KYC_SIGNER = TimestampSigner(salt='bullwave-kyc-email-review-v1')
_FNO_SIGNER = TimestampSigner(salt='bullwave-fno-email-review-v1')


def _make_action_token(signer: TimestampSigner, request_id: str, action: str) -> str:
    action = (action or '').strip().lower()
    if action not in VALID_ACTIONS:
        raise ValueError(f'Invalid email action: {action}')
    return signer.sign(f'{request_id}:{action}')


def _parse_action_token(signer: TimestampSigner, token: str) -> tuple[str, str]:
    """Return (request_id, action). Raises ValueError on invalid/expired token."""
    token = (token or '').strip()
    if not token:
        raise ValueError('Missing review token.')
    try:
        payload = signer.unsign(token, max_age=_MAX_AGE_SECONDS)
    except SignatureExpired as exc:
        raise ValueError('This review link has expired. Use Django admin instead.') from exc
    except BadSignature as exc:
        raise ValueError('Invalid review link.') from exc

    if ':' not in payload:
        raise ValueError('Malformed review token.')
    request_id, action = payload.split(':', 1)
    if action not in VALID_ACTIONS:
        raise ValueError('Unknown review action.')
    return request_id, action


def make_kyc_action_token(request_id: str, action: str) -> str:
    return _make_action_token(_KYC_SIGNER, request_id, action)


def parse_kyc_action_token(token: str) -> tuple[str, str]:
    return _parse_action_token(_KYC_SIGNER, token)


def make_fno_action_token(request_id: str, action: str) -> str:
    return _make_action_token(_FNO_SIGNER, request_id, action)


def parse_fno_action_token(token: str) -> tuple[str, str]:
    return _parse_action_token(_FNO_SIGNER, token)
