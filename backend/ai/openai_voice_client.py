"""OpenAI voice — text-to-speech (TTS) and speech-to-text (Whisper). API key stays on server."""

from __future__ import annotations

import json
import logging
import re
import urllib.error
import urllib.request
from io import BytesIO

from django.conf import settings

logger = logging.getLogger('bullwave.ai')

from .openai_client import (
    OPENAI_API_BASE,
    friendly_openai_error,
    openai_api_key,
    openai_auth_headers,
    openai_configured,
)

VALID_TTS_VOICES = frozenset(
    {'alloy', 'ash', 'ballad', 'coral', 'echo', 'fable', 'nova', 'onyx', 'sage', 'shimmer', 'verse'}
)


class OpenAiVoiceError(Exception):
    pass


def openai_voice_configured() -> bool:
    return openai_configured()


def _api_key() -> str:
    return openai_api_key()


def _request(method: str, path: str, *, json_body: dict | None = None, data: bytes | None = None, headers: dict | None = None):
    url = f'{OPENAI_API_BASE}{path}'
    try:
        req_headers = openai_auth_headers(content_type=None)
    except Exception as exc:
        raise OpenAiVoiceError(str(exc)) from exc
    if headers:
        req_headers.update(headers)

    body = None
    if json_body is not None:
        body = json.dumps(json_body).encode('utf-8')
        req_headers.setdefault('Content-Type', 'application/json')
    elif data is not None:
        body = data

    request = urllib.request.Request(url, data=body, headers=req_headers, method=method)
    timeout = getattr(settings, 'OPENAI_VOICE_TIMEOUT', 60)

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read(), response.headers.get('Content-Type', '')
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode('utf-8', errors='replace')
        raise OpenAiVoiceError(_friendly_http_error(exc.code, detail)) from exc
    except urllib.error.URLError as exc:
        raise OpenAiVoiceError(f'Cannot reach OpenAI: {exc.reason}') from exc


def _friendly_http_error(code: int, detail: str) -> str:
    message = detail
    try:
        payload = json.loads(detail)
        if isinstance(payload, dict):
            err = payload.get('error')
            if isinstance(err, dict) and err.get('message'):
                message = err['message']
            elif isinstance(err, str):
                message = err
    except json.JSONDecodeError:
        pass

    if code == 401:
        return friendly_openai_error(code, detail)
    if code == 429:
        return 'OpenAI rate limit reached. Wait a moment and try again.'
    if code == 402 or 'insufficient_quota' in message.lower():
        return 'OpenAI account has no remaining quota. Add billing at platform.openai.com.'
    return f'OpenAI voice error ({code}): {message[:280]}'


def _clean_text_for_speech(text: str) -> str:
    cleaned = re.sub(r'\*\*|__|\*|_|`|#', '', text or '')
    cleaned = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', cleaned)
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    max_chars = getattr(settings, 'OPENAI_TTS_MAX_CHARS', 4096)
    if len(cleaned) > max_chars:
        cleaned = cleaned[: max_chars - 3].rsplit(' ', 1)[0] + '...'
    return cleaned


def _resolve_tts_voice() -> str:
    voice = (getattr(settings, 'OPENAI_TTS_VOICE', '') or 'shimmer').strip().lower()
    if voice not in VALID_TTS_VOICES:
        return 'shimmer'
    return voice


def _resolve_tts_speed() -> float:
    speed = float(getattr(settings, 'OPENAI_TTS_SPEED', 0.93) or 0.93)
    return max(0.25, min(4.0, speed))


def text_to_speech_bytes(text: str) -> bytes:
    """Synthesize MP3 via OpenAI TTS."""
    cleaned = _clean_text_for_speech(text)
    if not cleaned:
        raise OpenAiVoiceError('Nothing to speak.')

    model = (getattr(settings, 'OPENAI_TTS_MODEL', '') or 'tts-1').strip()
    voice = _resolve_tts_voice()
    payload = {
        'model': model,
        'input': cleaned,
        'voice': voice,
        'response_format': 'mp3',
        'speed': _resolve_tts_speed(),
    }
    audio, _ = _request('POST', '/audio/speech', json_body=payload)
    if not audio:
        raise OpenAiVoiceError('OpenAI returned empty audio.')
    return audio


def transcribe_audio_bytes(audio_bytes: bytes, *, filename: str = 'speech.m4a', mime: str = 'audio/mp4') -> str:
    """Transcribe audio via OpenAI Whisper."""
    if not audio_bytes:
        raise OpenAiVoiceError('No audio received.')

    model = (getattr(settings, 'OPENAI_STT_MODEL', '') or 'whisper-1').strip()
    boundary = '----BullWaveVoiceBoundary7MA4YWxkTrZu0gW'

    body = BytesIO()
    body.write(f'--{boundary}\r\n'.encode())
    body.write(f'Content-Disposition: form-data; name="model"\r\n\r\n{model}\r\n'.encode())
    body.write(f'--{boundary}\r\n'.encode())
    body.write(f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'.encode())
    body.write(f'Content-Type: {mime}\r\n\r\n'.encode())
    body.write(audio_bytes)
    body.write(f'\r\n--{boundary}--\r\n'.encode())

    content_type = f'multipart/form-data; boundary={boundary}'
    raw, _ = _request(
        'POST',
        '/audio/transcriptions',
        data=body.getvalue(),
        headers={'Content-Type': content_type},
    )

    try:
        payload = json.loads(raw.decode('utf-8'))
    except json.JSONDecodeError as exc:
        raise OpenAiVoiceError('Unexpected OpenAI transcription response.') from exc

    text = (payload.get('text') or '').strip()
    if not text:
        raise OpenAiVoiceError('Could not understand speech. Try again.')
    return text


def voice_status_payload() -> dict:
    """Status for Flutter AI assistant voice UI."""
    configured = openai_voice_configured()
    ai_provider = (getattr(settings, 'AI_PROVIDER', '') or 'ollama').strip().lower()
    preference = (getattr(settings, 'AI_VOICE_PROVIDER', '') or 'auto').strip().lower()

    if configured:
        ai_ready = ai_provider != 'openai' or True
        if ai_provider == 'gemini':
            ai_ready = bool((getattr(settings, 'GEMINI_API_KEY', '') or '').strip())
        elif ai_provider == 'groq':
            ai_ready = bool((getattr(settings, 'GROQ_API_KEY', '') or '').strip())
        elif ai_provider == 'ollama':
            from .ollama_client import check_ollama
            ai_ready, _ = check_ollama()

        return {
            'ttsEnabled': True,
            'sttEnabled': getattr(settings, 'OPENAI_STT_ENABLED', True),
            'sttProvider': 'openai',
            'voiceProvider': 'openai',
            'voiceId': _resolve_tts_voice(),
            'ttsModel': (getattr(settings, 'OPENAI_TTS_MODEL', '') or 'tts-1').strip(),
            'aiProvider': ai_provider,
            'aiReady': ai_ready,
            'message': f'Female AI voice ready ({_resolve_tts_voice()}, Indian English style).',
        }

    # No OpenAI key — optional ElevenLabs fallback only if explicitly enabled
    from .elevenlabs_client import elevenlabs_configured as el_configured, voice_status_payload as eleven_status

    if preference == 'elevenlabs' or (preference == 'auto' and el_configured()):
        if el_configured():
            payload = eleven_status()
            payload['aiProvider'] = ai_provider
            payload['voiceProvider'] = 'elevenlabs'
            payload['sttEnabled'] = False
            payload['sttProvider'] = 'device'
            return payload

    return {
        'ttsEnabled': False,
        'sttEnabled': False,
        'sttProvider': 'device',
        'voiceProvider': '',
        'voiceId': '',
        'ttsModel': '',
        'aiProvider': ai_provider,
        'aiReady': False,
        'message': 'Add OPENAI_API_KEY to backend/.env for AI chat and voice, then restart Django.',
    }
