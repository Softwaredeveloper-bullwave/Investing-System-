import logging

import httpx
from django.conf import settings

from .context import build_user_context
from .ollama_client import OllamaError, chat as ollama_chat, check_ollama
from .openai_client import friendly_openai_error, openai_api_key, openai_auth_headers

logger = logging.getLogger('bullwave.ai')

SYSTEM_PROMPT = """You are BullWave AI — the in-app assistant for BullWave Invest (Indian markets: NSE/BSE).

RULES:
1. Answer using the APP KNOWLEDGE and LIVE USER DATA sections below. Quote real numbers (₹, %, quantities) from user data.
2. Portfolio & stock questions: summarize the user's actual holdings, P&L, wallet, watchlist — be specific and helpful.
3. App / how-to questions: explain which screen to open and steps (Home, Portfolio, Wallet, Goal Plans, Markets, etc.).
4. Stock analysis: use live quote data provided; mention sector, PE, day change when relevant.
5. You ARE allowed to discuss the user's portfolio and holdings — that data is provided for this purpose.
6. For buy/sell recommendations: give balanced view, not personalized SEBI-regulated advice; add a brief risk note.
7. Keep answers clear and structured (short bullets OK). Default under 150 words unless user asks for detail.
8. If user data shows empty portfolio, guide them to Markets or Featured Plans to start."""

SUPPORTED_PROVIDERS = ('ollama', 'openai', 'gemini', 'groq')


class LlmError(Exception):
    pass


def _history_to_messages(history):
    messages = []
    for item in history or []:
        role = item.get('role')
        content = (item.get('content') or '').strip()
        if role in ('user', 'assistant') and content:
            messages.append({'role': role, 'content': content})
    return messages


def _parse_http_error(provider, response):
    try:
        payload = response.json()
    except ValueError:
        return f'{provider} request failed ({response.status_code}).'

    if isinstance(payload, dict):
        error = payload.get('error')
        if isinstance(error, dict):
            message = error.get('message')
            if message:
                return f'{provider}: {message}'
        if isinstance(error, str):
            return f'{provider}: {error}'
        detail = payload.get('detail')
        if detail:
            return f'{provider}: {detail}'

    return f'{provider} request failed ({response.status_code}).'


def _validate_provider_config():
    provider = (settings.AI_PROVIDER or '').strip().lower()
    if provider not in SUPPORTED_PROVIDERS:
        raise LlmError(
            f'AI_PROVIDER must be one of: {", ".join(SUPPORTED_PROVIDERS)}. '
            f'Got "{settings.AI_PROVIDER}".'
        )

    if provider == 'ollama':
        if not (settings.OLLAMA_BASE_URL or '').strip():
            raise LlmError('OLLAMA_BASE_URL is required when AI_PROVIDER=ollama.')
        ok, message = check_ollama()
        if not ok:
            raise LlmError(message)
        return provider

    if provider == 'openai':
        try:
            openai_api_key()
        except Exception as exc:
            raise LlmError(str(exc)) from exc
        return provider

    if provider == 'gemini':
        if not (settings.GEMINI_API_KEY or '').strip():
            raise LlmError('GEMINI_API_KEY is required when AI_PROVIDER=gemini.')
        return provider

    if not (settings.GROQ_API_KEY or '').strip():
        raise LlmError('GROQ_API_KEY is required when AI_PROVIDER=groq.')
    return provider


def _call_openai_compatible(system_prompt, history, user_message, *, provider, base_url, api_key, model):
    payload = {
        'model': model,
        'messages': [
            {'role': 'system', 'content': system_prompt},
            *_history_to_messages(history),
            {'role': 'user', 'content': user_message},
        ],
        'temperature': settings.AI_TEMPERATURE,
        'max_tokens': settings.AI_MAX_TOKENS,
    }

    if provider == 'OpenAI':
        headers = openai_auth_headers()
    else:
        headers = {'Content-Type': 'application/json'}
        if api_key:
            headers['Authorization'] = f'Bearer {api_key}'

    url = f'{base_url.rstrip("/")}/chat/completions'

    with httpx.Client(timeout=settings.AI_REQUEST_TIMEOUT) as client:
        response = client.post(url, headers=headers, json=payload)
        if response.is_error:
            if provider == 'OpenAI' and response.status_code == 401:
                raise LlmError(friendly_openai_error(response.status_code, response.text))
            raise LlmError(_parse_http_error(provider, response))
        data = response.json()

    try:
        content = data['choices'][0]['message']['content'].strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise LlmError(f'Unexpected {provider} response format.') from exc

    if not content:
        raise LlmError(f'{provider} returned an empty response.')
    return content


def _call_openai(system_prompt, history, user_message):
    return _call_openai_compatible(
        system_prompt,
        history,
        user_message,
        provider='OpenAI',
        base_url='https://api.openai.com/v1',
        api_key=openai_api_key(),
        model=settings.OPENAI_MODEL,
    )


def _call_groq(system_prompt, history, user_message):
    return _call_openai_compatible(
        system_prompt,
        history,
        user_message,
        provider='Groq',
        base_url='https://api.groq.com/openai/v1',
        api_key=settings.GROQ_API_KEY.strip(),
        model=settings.GROQ_MODEL,
    )


def _call_ollama(system_prompt, history, user_message):
    try:
        return ollama_chat(system_prompt, history, user_message)
    except OllamaError as exc:
        raise LlmError(str(exc)) from exc


def _call_gemini(system_prompt, history, user_message):
    api_key = settings.GEMINI_API_KEY.strip()
    contents = []
    for item in _history_to_messages(history):
        gemini_role = 'user' if item['role'] == 'user' else 'model'
        contents.append({'role': gemini_role, 'parts': [{'text': item['content']}]})
    contents.append({'role': 'user', 'parts': [{'text': user_message}]})

    url = (
        f'https://generativelanguage.googleapis.com/v1beta/models/'
        f'{settings.GEMINI_MODEL}:generateContent'
    )
    payload = {
        'systemInstruction': {'parts': [{'text': system_prompt}]},
        'contents': contents,
        'generationConfig': {
            'temperature': settings.AI_TEMPERATURE,
            'maxOutputTokens': settings.AI_MAX_TOKENS,
        },
    }

    with httpx.Client(timeout=settings.AI_REQUEST_TIMEOUT) as client:
        response = client.post(url, params={'key': api_key}, json=payload)
        if response.is_error:
            raise LlmError(_parse_http_error('Gemini', response))
        data = response.json()

    try:
        content = data['candidates'][0]['content']['parts'][0]['text'].strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise LlmError('Unexpected Gemini response format.') from exc

    if not content:
        raise LlmError('Gemini returned an empty response.')
    return content


def generate_stock_assistant_reply(user, message, symbol='', history=None):
    """
    Generate an assistant reply using the configured AI provider.

    Default: Ollama (local, free, no API key).
    Set AI_PROVIDER in backend/.env to switch providers.
    """
    context = build_user_context(user, message=message, symbol=symbol)
    system_prompt = f'{SYSTEM_PROMPT}\n\n---\n\n{context}'
    provider = _validate_provider_config()

    dispatch = {
        'ollama': _call_ollama,
        'openai': _call_openai,
        'gemini': _call_gemini,
        'groq': _call_groq,
    }

    try:
        return dispatch[provider](system_prompt, history, message)
    except httpx.TimeoutException as exc:
        logger.exception('%s request timed out', provider)
        raise LlmError(
            'AI request timed out. Ollama can be slow on first run — try again.'
        ) from exc
    except httpx.HTTPError as exc:
        logger.exception('%s request failed', provider)
        raise LlmError(f'{provider.title()} connection failed.') from exc
