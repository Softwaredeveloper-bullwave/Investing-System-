"""Report which real APIs are configured."""

from django.conf import settings

from services.providers.cashfree_config import cashfree_settings
from services.providers.cashfree_payments import is_configured as cashfree_payments_configured
from services.providers.cashfree_secure_id import is_configured as cashfree_secure_id_configured

from .razorpay_service import is_configured as razorpay_configured
from .sms_service import resolve_sms_provider, uses_twilio_verify


def _market_provider():
    explicit = (getattr(settings, 'MARKET_DATA_PROVIDER', 'auto') or 'auto').lower()
    if explicit != 'auto':
        return explicit
    if (getattr(settings, 'KOTAK_NEO_ACCESS_TOKEN', '') or '').strip():
        return 'kotak_neo'
    if (getattr(settings, 'ALPHA_VANTAGE_API_KEY', '') or '').strip():
        return 'alphavantage'
    if (getattr(settings, 'FINNHUB_API_KEY', '') or '').strip():
        return 'finnhub'
    return 'yahoo'


def integration_status() -> dict:
    kotak = bool((getattr(settings, 'KOTAK_NEO_ACCESS_TOKEN', '') or '').strip())
    av = bool((getattr(settings, 'ALPHA_VANTAGE_API_KEY', '') or '').strip())
    finnhub = bool((getattr(settings, 'FINNHUB_API_KEY', '') or '').strip())
    provider = _market_provider()
    sms_provider = resolve_sms_provider()
    ai_provider = (getattr(settings, 'AI_PROVIDER', 'ollama') or 'ollama').lower()

    ai_ready = ai_provider == 'ollama' or bool(
        {
            'openai': getattr(settings, 'OPENAI_API_KEY', ''),
            'gemini': getattr(settings, 'GEMINI_API_KEY', ''),
            'groq': getattr(settings, 'GROQ_API_KEY', ''),
        }.get(ai_provider, '')
    )

    cf = cashfree_settings()

    return {
        'market_data': {
            'provider': provider,
            'configured': kotak or av or finnhub,
            'kotak_neo': kotak,
            'alpha_vantage': av,
            'finnhub': finnhub,
            'fallback': 'yahoo_finance',
        },
        'news': {'provider': 'rss_feeds', 'configured': True},
        'payments': {
            'provider': 'cashfree' if cashfree_payments_configured() else 'razorpay',
            'configured': cashfree_payments_configured() or razorpay_configured(),
            'cashfree': cf.is_configured,
            'razorpay': razorpay_configured(),
        },
        'kyc_verification': {
            'provider': 'cashfree_secure_id',
            'configured': cashfree_secure_id_configured(),
        },
        'payouts': {
            'provider': 'cashfree_payouts',
            'configured': cf.is_configured,
        },
        'sms_otp': {
            'provider': 'twilio_verify' if uses_twilio_verify() else sms_provider,
            'configured': sms_provider != 'console',
            'twilio_verify': uses_twilio_verify(),
        },
        'bank_validation': {
            'provider': 'cashfree' if cashfree_secure_id_configured() else 'razorpay_ifsc',
            'configured': cashfree_secure_id_configured(),
        },
        'ai_assistant': {
            'provider': ai_provider,
            'configured': ai_ready,
        },
        'broker': {
            'provider': 'paper_trading',
            'configured': False,
            'note': 'Set KITE_API_KEY or DHAN_ACCESS_TOKEN for live broker (future).',
        },
    }
