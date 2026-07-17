"""Ollama local LLM client — tuned for speed on CPU."""

import logging
import threading

import httpx
from django.conf import settings

logger = logging.getLogger('bullwave.ai')

# Cap chat history sent to the model (fewer tokens = faster inference).
OLLAMA_HISTORY_LIMIT = 4


class OllamaError(Exception):
    pass


def _base_url():
    return (settings.OLLAMA_BASE_URL or 'http://127.0.0.1:11434').rstrip('/')


def check_ollama():
    """Verify Ollama is running and the configured model is available."""
    base = _base_url()
    model = (settings.OLLAMA_MODEL or 'llama3.2:1b').strip()

    try:
        with httpx.Client(timeout=10) as client:
            response = client.get(f'{base}/api/tags')
            response.raise_for_status()
            data = response.json()
    except httpx.ConnectError:
        return False, (
            'Ollama is not running. Install from https://ollama.com then run: '
            f'ollama pull {model}'
        )
    except httpx.HTTPError as exc:
        return False, f'Cannot reach Ollama at {base}: {exc}'

    installed_names = {m.get('name', '') for m in data.get('models', [])}
    model_base = model.split(':')[0]
    found = model in installed_names or any(
        n == model or n.startswith(f'{model_base}:') for n in installed_names
    )

    if not found:
        names = ', '.join(sorted(installed_names)) if installed_names else 'none'
        return False, (
            f'Model "{model}" is not installed. Run: ollama pull {model} '
            f'(installed: {names})'
        )

    return True, f'Ollama ready at {base} with model {model}'


def _ollama_options():
    return {
        'temperature': settings.AI_TEMPERATURE,
        'num_predict': settings.AI_MAX_TOKENS,
        'num_ctx': settings.OLLAMA_NUM_CTX,
        'top_p': 0.9,
    }


def _trim_history(history):
    """Keep only the last N turns to reduce prompt size."""
    messages = []
    for item in history or []:
        role = item.get('role')
        content = (item.get('content') or '').strip()
        if role in ('user', 'assistant') and content:
            messages.append({'role': role, 'content': content})
    if len(messages) > OLLAMA_HISTORY_LIMIT:
        messages = messages[-OLLAMA_HISTORY_LIMIT:]
    return messages


def chat(system_prompt, history, user_message):
    """Call Ollama /api/chat with speed-optimized settings."""
    base = _base_url()
    model = settings.OLLAMA_MODEL

    messages = [{'role': 'system', 'content': system_prompt}]
    messages.extend(_trim_history(history))
    messages.append({'role': 'user', 'content': user_message})

    payload = {
        'model': model,
        'messages': messages,
        'stream': False,
        'keep_alive': settings.OLLAMA_KEEP_ALIVE,
        'options': _ollama_options(),
    }

    timeout = settings.AI_REQUEST_TIMEOUT
    with httpx.Client(timeout=timeout) as client:
        response = client.post(f'{base}/api/chat', json=payload)
        if response.status_code == 404:
            raise OllamaError(
                f'Model "{model}" not found. Run: ollama pull {model}'
            )
        if response.is_error:
            try:
                detail = response.json().get('error', response.text)
            except ValueError:
                detail = response.text
            raise OllamaError(f'Ollama: {detail}')

        data = response.json()

    try:
        content = data['message']['content'].strip()
    except (KeyError, TypeError) as exc:
        raise OllamaError('Unexpected Ollama response format.') from exc

    if not content:
        raise OllamaError('Ollama returned an empty response.')
    return content


def warmup_model():
    """
    Pre-load the model into memory so the first user message is not slow.
    Runs in a background thread during Django startup.
    """
    ok, message = check_ollama()
    if not ok:
        logger.warning('Ollama warmup skipped: %s', message)
        return

    def _run():
        try:
            chat(
                system_prompt='Reply with one word: ready',
                history=[],
                user_message='ping',
            )
            logger.info('Ollama model pre-loaded into memory')
        except Exception as exc:
            logger.warning('Ollama warmup failed: %s', exc)

    threading.Thread(target=_run, daemon=True, name='ollama-warmup').start()
