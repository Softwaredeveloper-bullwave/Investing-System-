import logging

from django.apps import AppConfig

logger = logging.getLogger('bullwave.ai')


class AiConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'ai'

    def ready(self):
        from django.conf import settings

        provider = (settings.AI_PROVIDER or '').lower()

        if provider != 'ollama':
            self._log_cloud_provider(provider, settings)
            return

        from .ollama_client import check_ollama, warmup_model

        ok, message = check_ollama()
        if ok:
            logger.info('AI assistant ready — %s', message)
            warmup_model()
        else:
            logger.warning(
                'AI assistant (Ollama) not ready: %s\n'
                '  1. Install: https://ollama.com/download\n'
                '  2. Run: ollama pull llama3.2:1b  (fast model)\n'
                '  3. Restart Django runserver',
                message,
            )

    def _log_cloud_provider(self, provider, settings):
        ready = False
        model = ''

        if provider == 'openai' and (settings.OPENAI_API_KEY or '').strip():
            model = settings.OPENAI_MODEL
            from .openai_client import validate_openai_key

            ok, message = validate_openai_key()
            if ok:
                ready = True
                logger.info('AI assistant ready (provider=%s, model=%s)', provider, model)
            else:
                logger.warning('AI assistant configured but OpenAI key check failed: %s', message)
        elif provider == 'gemini' and (settings.GEMINI_API_KEY or '').strip():
            ready, model = True, settings.GEMINI_MODEL
            logger.info('AI assistant ready (provider=%s, model=%s)', provider, model)
        elif provider == 'groq' and (settings.GROQ_API_KEY or '').strip():
            ready, model = True, settings.GROQ_MODEL
            logger.info('AI assistant ready (provider=%s, model=%s)', provider, model)

        if ready and (settings.OPENAI_API_KEY or '').strip():
            voice = (settings.OPENAI_TTS_VOICE or 'nova').strip()
            logger.info(
                'AI voice ready (OpenAI TTS=%s, STT=%s)',
                voice,
                settings.OPENAI_STT_MODEL if settings.OPENAI_STT_ENABLED else 'disabled',
            )
        elif not ready:
            logger.warning('AI assistant NOT configured for provider=%s', provider)
