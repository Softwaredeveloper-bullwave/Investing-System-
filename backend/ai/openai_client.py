"""Shared OpenAI auth + request helpers (chat, TTS, STT)."""

from __future__ import annotations

import json

from django.conf import settings

OPENAI_API_BASE = 'https://api.openai.com/v1'
# Project-scoped keys (sk-proj-*) are ~164 chars; shorter values are usually truncated.
MIN_PROJECT_KEY_LENGTH = 150


class OpenAiConfigError(Exception):
    pass


def openai_api_key() -> str:
    key = (getattr(settings, 'OPENAI_API_KEY', '') or '').strip()
    if not key:
        raise OpenAiConfigError(
            'OPENAI_API_KEY is missing. Add it to backend/.env and restart Django.'
        )
    if not key.startswith('sk-'):
        raise OpenAiConfigError(
            'OPENAI_API_KEY must start with "sk-". Copy the full key from '
            'https://platform.openai.com/api-keys (no quotes).'
        )
    if key.startswith('sk-proj-') and len(key) < MIN_PROJECT_KEY_LENGTH:
        raise OpenAiConfigError(
            f'OPENAI_API_KEY looks truncated ({len(key)} chars). '
            f'Project keys are usually {MIN_PROJECT_KEY_LENGTH}+ characters — '
            'paste the entire key on one line in backend/.env.'
        )
    return key


def openai_configured() -> bool:
    try:
        openai_api_key()
        return True
    except OpenAiConfigError:
        return False


def openai_auth_headers(*, content_type: str | None = 'application/json') -> dict[str, str]:
    headers = {'Authorization': f'Bearer {openai_api_key()}'}
    org_id = (getattr(settings, 'OPENAI_ORG_ID', '') or '').strip()
    project_id = (getattr(settings, 'OPENAI_PROJECT_ID', '') or '').strip()
    if org_id:
        headers['OpenAI-Organization'] = org_id
    if project_id:
        headers['OpenAI-Project'] = project_id
    if content_type:
        headers['Content-Type'] = content_type
    return headers


def mask_api_key(key: str) -> str:
    cleaned = (key or '').strip()
    if len(cleaned) <= 12:
        return '***'
    return f'{cleaned[:7]}...{cleaned[-4:]}'


def friendly_openai_error(code: int, detail: str) -> str:
    message = detail
    try:
        payload = json.loads(detail)
        if isinstance(payload, dict):
            err = payload.get('error')
            if isinstance(err, dict) and err.get('message'):
                message = err['message']
            elif isinstance(err, str):
                message = err
    except Exception:
        pass

    if code == 401 or 'invalid_api_key' in message.lower():
        return (
            'OpenAI rejected the API key. Create a new secret key at '
            'https://platform.openai.com/api-keys, paste it in backend/.env as '
            'OPENAI_API_KEY=sk-... (no quotes, one line), then restart Django. '
            'Run: python manage.py check_openai'
        )
    if code == 429:
        return 'OpenAI rate limit reached. Wait a moment and try again.'
    if code == 402 or 'insufficient_quota' in message.lower():
        return 'OpenAI account has no remaining quota. Add billing at platform.openai.com.'
    return f'OpenAI error ({code}): {message[:280]}'


def validate_openai_key() -> tuple[bool, str]:
    """Lightweight startup / CLI validation."""
    try:
        key = openai_api_key()
    except OpenAiConfigError as exc:
        return False, str(exc)

    import httpx

    try:
        with httpx.Client(timeout=20) as client:
            response = client.get(
                f'{OPENAI_API_BASE}/models',
                headers=openai_auth_headers(content_type=None),
            )
        if response.is_success:
            return True, f'OpenAI key OK ({mask_api_key(key)}, {len(key)} chars).'
        return False, friendly_openai_error(response.status_code, response.text)
    except httpx.HTTPError as exc:
        return False, f'Cannot reach OpenAI: {exc}'
