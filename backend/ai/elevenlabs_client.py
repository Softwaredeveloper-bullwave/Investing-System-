"""ElevenLabs text-to-speech — API key stays on the server."""

from __future__ import annotations

import json
import logging
import re
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from django.conf import settings
from django.core.cache import cache

logger = logging.getLogger('bullwave.ai')

ELEVENLABS_API_BASE = 'https://api.elevenlabs.io/v1'

# Free-tier API: library/premade voices like Rachel often return 402.
# Prefer voices you created via Voice Design (category=generated).
FREE_TIER_VOICE_CATEGORIES = ('generated', 'cloned', 'premade')


class ElevenLabsError(Exception):
    pass


_voice_cache_key = 'elevenlabs:resolved_voice'


def elevenlabs_configured() -> bool:
    return bool((getattr(settings, 'ELEVENLABS_API_KEY', '') or '').strip())


def _api_key() -> str:
    key = (getattr(settings, 'ELEVENLABS_API_KEY', '') or '').strip()
    if not key:
        raise ElevenLabsError(
            'ElevenLabs is not configured. Add ELEVENLABS_API_KEY to backend/.env'
        )
    return key


def _api_request(method: str, path: str, *, body: dict | None = None) -> bytes:
    api_key = _api_key()
    url = f'{ELEVENLABS_API_BASE}{path}'
    headers = {'Accept': 'application/json', 'xi-api-key': api_key}
    data = None
    if body is not None:
        headers['Content-Type'] = 'application/json'
        data = json.dumps(body).encode('utf-8')

    req = Request(url, data=data, headers=headers, method=method)
    timeout = getattr(settings, 'ELEVENLABS_TIMEOUT', 45)
    try:
        with urlopen(req, timeout=timeout) as resp:
            return resp.read()
    except HTTPError as exc:
        detail = exc.read().decode('utf-8', errors='replace')
        raise ElevenLabsError(_friendly_http_error(exc.code, detail)) from exc
    except URLError as exc:
        raise ElevenLabsError(f'Cannot reach ElevenLabs: {exc.reason}') from exc


def list_account_voices() -> list[dict]:
    try:
        raw = _api_request('GET', '/voices')
        data = json.loads(raw.decode('utf-8'))
        return data.get('voices') or []
    except ElevenLabsError as exc:
        logger.warning('Could not list ElevenLabs voices (set ELEVENLABS_VOICE_ID manually): %s', exc)
        return []


def _pick_free_tier_voice(voices: list[dict], preferred_id: str = '') -> tuple[str, str, str]:
    """Return (voice_id, name, category) best suited for free API tier."""
    preferred_id = (preferred_id or '').strip()
    by_id = {v.get('voice_id'): v for v in voices if v.get('voice_id')}

    if preferred_id and preferred_id in by_id:
        v = by_id[preferred_id]
        return preferred_id, v.get('name') or preferred_id, v.get('category') or 'unknown'

    for category in FREE_TIER_VOICE_CATEGORIES:
        for v in voices:
            if v.get('category') == category and v.get('voice_id'):
                return v['voice_id'], v.get('name') or v['voice_id'], category

    if voices and voices[0].get('voice_id'):
        v = voices[0]
        return v['voice_id'], v.get('name') or v['voice_id'], v.get('category') or 'unknown'

    if preferred_id:
        return preferred_id, preferred_id, 'configured'

    raise ElevenLabsError(
        'Set ELEVENLABS_VOICE_ID in backend/.env to a Voice Design voice ID. '
        'Free plan cannot use library voices like Rachel. '
        'Create one at https://elevenlabs.io/app/voice-design'
    )


def resolve_voice_id(force_refresh: bool = False) -> dict:
    """Resolve voice for TTS — caches for 1 hour."""
    if not force_refresh:
        cached = cache.get(_voice_cache_key)
        if cached:
            return cached

    configured = (getattr(settings, 'ELEVENLABS_VOICE_ID', '') or '').strip()
    voices = list_account_voices()
    voice_id, name, category = _pick_free_tier_voice(voices, configured)

    if configured and configured != voice_id:
        logger.info(
            'ElevenLabs voice %s not usable on free tier — using %s (%s, %s)',
            configured,
            voice_id,
            name,
            category,
        )

    payload = {
        'voice_id': voice_id,
        'voice_name': name,
        'category': category,
        'configured_voice_id': configured,
        'auto_selected': not configured or configured != voice_id,
    }
    cache.set(_voice_cache_key, payload, 3600)
    return payload


def voice_status_payload() -> dict:
    if not elevenlabs_configured():
        return {'ttsEnabled': False, 'voiceId': '', 'message': 'ELEVENLABS_API_KEY not set'}
    try:
        info = resolve_voice_id()
        return {
            'ttsEnabled': True,
            'voiceId': info['voice_id'],
            'voiceName': info['voice_name'],
            'category': info['category'],
            'autoSelected': info['auto_selected'],
            'message': (
                'Using Voice Design voice (free tier).'
                if info['category'] == 'generated'
                else 'Voice auto-selected for your ElevenLabs plan.'
            ),
        }
    except ElevenLabsError as exc:
        return {'ttsEnabled': False, 'voiceId': '', 'message': str(exc)}


def _clean_text_for_speech(text: str) -> str:
    t = (text or '').strip()
    if not t:
        return ''
    t = re.sub(r'\*\*|__|\*|_', '', t)
    t = re.sub(r'`+', '', t)
    t = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', t)
    t = re.sub(r'\s+', ' ', t)
    return t[:4000]


def _friendly_http_error(code: int, detail: str) -> str:
    lowered = detail.lower()
    if code == 401:
        if 'missing the permission' in lowered or 'voices_read' in lowered:
            return (
                'ElevenLabs API key needs Text-to-Speech permission. '
                'Regenerate the key at elevenlabs.io/app/settings/api-keys '
                'with Text to Speech enabled.'
            )
        return 'Invalid ElevenLabs API key.'
    if code == 402 or 'paid_plan_required' in lowered or 'library voices' in lowered:
        return (
            'This voice needs a paid ElevenLabs plan. '
            'Create a free voice at elevenlabs.io/app/voice-design (Voice Design), '
            'then set ELEVENLABS_VOICE_ID to that Voice ID in backend/.env — '
            'or leave it empty and restart Django to auto-pick.'
        )
    if code == 429:
        return 'ElevenLabs monthly character limit reached. Upgrade plan or wait until next month.'
    return f'ElevenLabs error {code}: {detail[:280]}'


def _tts_request(voice_id: str, text: str, model_id: str) -> bytes:
    payload = {
        'text': text,
        'model_id': model_id,
        'voice_settings': {
            'stability': 0.45,
            'similarity_boost': 0.75,
            'style': 0.15,
            'use_speaker_boost': True,
        },
    }
    api_key = _api_key()
    url = f'{ELEVENLABS_API_BASE}/text-to-speech/{voice_id}'
    body = json.dumps(payload).encode('utf-8')
    req = Request(
        url,
        data=body,
        headers={
            'Accept': 'audio/mpeg',
            'Content-Type': 'application/json',
            'xi-api-key': api_key,
        },
        method='POST',
    )
    timeout = getattr(settings, 'ELEVENLABS_TIMEOUT', 45)
    try:
        with urlopen(req, timeout=timeout) as resp:
            return resp.read()
    except HTTPError as exc:
        detail = exc.read().decode('utf-8', errors='replace')
        raise ElevenLabsError(_friendly_http_error(exc.code, detail)) from exc
    except URLError as exc:
        raise ElevenLabsError(f'Cannot reach ElevenLabs: {exc.reason}') from exc


def text_to_speech_bytes(text: str) -> bytes:
    """Convert text to MP3 — auto-picks a free-tier voice when needed."""
    cleaned = _clean_text_for_speech(text)
    if not cleaned:
        raise ElevenLabsError('Nothing to speak.')

    model_id = (
        getattr(settings, 'ELEVENLABS_MODEL_ID', '') or 'eleven_turbo_v2_5'
    ).strip()

    configured = (getattr(settings, 'ELEVENLABS_VOICE_ID', '') or '').strip()
    voice_info = resolve_voice_id()
    candidates: list[str] = []

    def _add(vid: str) -> None:
        if vid and vid not in candidates:
            candidates.append(vid)

    _add(voice_info['voice_id'])
    if configured:
        _add(configured)

    # Try any generated voices from the account on 402 fallback.
    try:
        for v in list_account_voices():
            if v.get('category') == 'generated' and v.get('voice_id'):
                _add(v['voice_id'])
    except ElevenLabsError:
        pass

    last_error: ElevenLabsError | None = None
    for voice_id in candidates:
        try:
            audio = _tts_request(voice_id, cleaned, model_id)
            if audio:
                if voice_id != voice_info['voice_id']:
                    cache.delete(_voice_cache_key)
                    cache.set(
                        _voice_cache_key,
                        {**voice_info, 'voice_id': voice_id, 'auto_selected': True},
                        3600,
                    )
                return audio
        except ElevenLabsError as exc:
            last_error = exc
            if 'paid ElevenLabs plan' in str(exc) or '402' in str(exc):
                logger.warning('Voice %s rejected (402), trying next…', voice_id)
                continue
            raise

    raise last_error or ElevenLabsError(
        'No usable ElevenLabs voice on your plan. '
        'Create one at elevenlabs.io/app/voice-design and set ELEVENLABS_VOICE_ID.'
    )
