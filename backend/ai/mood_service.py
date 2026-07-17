"""AI Mood Detector — a Fear/Greed-style market mood gauge.

The score is always computed deterministically from live market signals
(index move + advance/decline breadth), so the feature works even without
an AI provider configured. When an LLM is available, we additionally ask
it for a short, human commentary layered on top of the computed score —
mirroring the graceful-degradation pattern used elsewhere in this app
(Kotak Neo -> Finnhub -> Yahoo, etc.).
"""
from __future__ import annotations

import logging

from django.utils import timezone

from stocks.models import Stock
from stocks.market_symbols import NIFTY_50

from . import llm_service

logger = logging.getLogger('bullwave.ai')

MOOD_BANDS = (
    (20, 'extreme_fear', 'Extreme Fear'),
    (40, 'fear', 'Fear'),
    (60, 'neutral', 'Neutral'),
    (80, 'greed', 'Greed'),
    (101, 'extreme_greed', 'Extreme Greed'),
)

FALLBACK_COMMENTARY = {
    'extreme_fear': 'Sharp broad-based selling — sentiment is stretched to the downside.',
    'fear': 'More red than green on the tape; caution is dominating flows.',
    'neutral': 'A balanced tape — no strong conviction either way today.',
    'greed': 'Buyers are firmly in control with broad participation.',
    'extreme_greed': 'Aggressive, broad-based buying — sentiment is stretched to the upside.',
}


def _mood_band(score: float):
    for threshold, key, label in MOOD_BANDS:
        if score < threshold:
            return key, label
    return 'extreme_greed', 'Extreme Greed'


def _index_change_percent() -> float:
    try:
        from engagement.models import MarketIndex

        nifty = MarketIndex.objects.filter(id__in=['NIFTY50', 'NIFTY', 'NIFTY_50']).first()
        return float(nifty.change_percent) if nifty else 0.0
    except Exception:  # pragma: no cover - defensive, mood must never 500
        logger.exception('Could not read index change for mood score')
        return 0.0


def _breadth():
    """Advancers vs decliners across the Nifty 50 universe."""
    qs = Stock.objects.filter(symbol__in=NIFTY_50)
    total = qs.count()
    if not total:
        return 0, 0, 0
    advancers = qs.filter(change_percent__gt=0).count()
    decliners = qs.filter(change_percent__lt=0).count()
    return advancers, decliners, total


def compute_market_mood(*, with_ai_commentary: bool = True) -> dict:
    index_change = _index_change_percent()
    advancers, decliners, total = _breadth()
    breadth_signal = ((advancers - decliners) / total * 100) if total else 0.0

    # Weighted blend: index move carries more punch than raw breadth spread.
    score = 50 + (index_change * 8) + (breadth_signal * 0.3)
    score = max(0.0, min(100.0, score))

    mood_key, mood_label = _mood_band(score)
    commentary = FALLBACK_COMMENTARY[mood_key]
    ai_generated = False

    if with_ai_commentary:
        try:
            commentary = _ai_commentary(
                score=score,
                mood_label=mood_label,
                index_change=index_change,
                advancers=advancers,
                decliners=decliners,
            )
            ai_generated = True
        except llm_service.LlmError:
            pass  # keep the deterministic fallback line — feature still works

    return {
        'score': round(score, 1),
        'mood': mood_key,
        'mood_label': mood_label,
        'index_change_percent': round(index_change, 2),
        'advancers': advancers,
        'decliners': decliners,
        'universe_size': total,
        'commentary': commentary,
        'ai_generated': ai_generated,
        'generated_at': timezone.now().isoformat(),
    }


def _ai_commentary(*, score, mood_label, index_change, advancers, decliners) -> str:
    prompt = (
        f'Nifty 50 is {"up" if index_change >= 0 else "down"} {abs(index_change):.2f}% today. '
        f'{advancers} stocks are advancing and {decliners} are declining. '
        f'The computed mood score is {score:.0f}/100 ({mood_label}). '
        'In one short, punchy sentence (max 20 words, no hedging, no "as an AI"), '
        'describe today\'s market mood for a retail investor.'
    )
    provider = llm_service._validate_provider_config()
    dispatch = {
        'ollama': llm_service._call_ollama,
        'openai': llm_service._call_openai,
        'gemini': llm_service._call_gemini,
        'groq': llm_service._call_groq,
    }
    reply = dispatch[provider](
        'You are a terse markets commentator for an Indian retail investing app.',
        [],
        prompt,
    )
    return reply.strip().strip('"')
