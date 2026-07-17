"""Unified AI voice — OpenAI primary, ElevenLabs fallback."""

from __future__ import annotations

from django.conf import settings

from .elevenlabs_client import ElevenLabsError, elevenlabs_configured, text_to_speech_bytes as elevenlabs_tts
from .openai_voice_client import OpenAiVoiceError, openai_voice_configured, text_to_speech_bytes as openai_tts, voice_status_payload


class VoiceError(Exception):
    pass


def _effective_voice_provider() -> str:
    preference = (getattr(settings, 'AI_VOICE_PROVIDER', '') or 'auto').strip().lower()

    if openai_voice_configured():
        if preference in ('auto', 'openai', ''):
            return 'openai'

    if preference == 'openai':
        return 'openai'

    if preference == 'elevenlabs' and elevenlabs_configured():
        return 'elevenlabs'

    if preference == 'auto' and elevenlabs_configured():
        return 'elevenlabs'

    return 'openai' if openai_voice_configured() else ''


def text_to_speech_bytes(text: str) -> bytes:
    provider = _effective_voice_provider()
    if provider == 'openai':
        try:
            return openai_tts(text)
        except OpenAiVoiceError as exc:
            raise VoiceError(str(exc)) from exc
    if provider == 'elevenlabs':
        try:
            return elevenlabs_tts(text)
        except ElevenLabsError as exc:
            raise VoiceError(str(exc)) from exc
    raise VoiceError(
        'Voice is not configured. Add OPENAI_API_KEY to backend/.env '
        '(recommended) or ELEVENLABS_API_KEY, then restart Django.'
    )


def get_voice_status() -> dict:
    return voice_status_payload()
