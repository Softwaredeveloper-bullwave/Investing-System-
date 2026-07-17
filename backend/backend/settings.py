from pathlib import Path

from decouple import Config, RepositoryEnv
from datetime import timedelta

BASE_DIR = Path(__file__).resolve().parent.parent

_env_file = BASE_DIR / '.env'
if _env_file.is_file():
    config = Config(RepositoryEnv(str(_env_file)))
else:
    from decouple import config  # noqa: F401 — falls back to cwd / environment variables


def _clean_env(value: str, *, strip_trailing_slash: bool = False) -> str:
    """Strip accidental inline # comments and whitespace from .env values."""
    cleaned = (value or '').split('#', 1)[0].strip()
    if strip_trailing_slash:
        cleaned = cleaned.rstrip('/')
    return cleaned


def _ascii_env(value: str) -> str:
    """API keys must be ASCII — rejects copy-paste corruption (e.g. Cyrillic lookalikes)."""
    cleaned = _clean_env(value)
    if not cleaned:
        return ''
    ascii_only = ''.join(ch for ch in cleaned if ord(ch) < 128)
    return ascii_only.strip()

SECRET_KEY = config('SECRET_KEY', default='django-insecure-dev-key-change-in-production')
DEBUG = config('DEBUG', default=True, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost,127.0.0.1,10.0.2.2').split(',')
if DEBUG:
    ALLOWED_HOSTS = ['*']

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {'class': 'logging.StreamHandler'},
    },
    'loggers': {
        'bullwave.requests': {
            'handlers': ['console'],
            'level': 'INFO',
        },
        'bullwave.ai': {
            'handlers': ['console'],
            'level': 'INFO',
        },
    },
}

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework_simplejwt',
    'corsheaders',
    'accounts.apps.AccountsConfig',
    'kyc',
    'payments',
    'finance',
    'stocks.apps.StocksConfig',
    'engagement',
    'education',
    'ai',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'core.middleware.RequestLogMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'backend.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'backend.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME', default='bullwave_db'),
        'USER': config('DB_USER', default='postgres'),
        'PASSWORD': config('DB_PASSWORD', default='postgres'),
        'HOST': config('DB_HOST', default='localhost'),
        'PORT': config('DB_PORT', default='5432'),
    }
}

AUTH_USER_MODEL = 'accounts.User'

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Asia/Kolkata'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    'DATETIME_FORMAT': '%Y-%m-%dT%H:%M:%S.%fZ',
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=7),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=30),
    'ROTATE_REFRESH_TOKENS': True,
}

CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOWED_ORIGINS = config(
    'CORS_ALLOWED_ORIGINS',
    default='http://localhost:3000,http://127.0.0.1:3000',
    cast=lambda v: [origin.strip() for origin in v.split(',') if origin.strip()],
)

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'bullwave-cache',
    }
}

OTP_EXPIRY_MINUTES = config('OTP_EXPIRY_MINUTES', default=5, cast=int)

# AI assistant — default: Ollama (local, free). See ai/ollama_client.py
AI_PROVIDER = config('AI_PROVIDER', default='ollama')
OPENAI_API_KEY = _ascii_env(config('OPENAI_API_KEY', default=''))
OPENAI_ORG_ID = _ascii_env(config('OPENAI_ORG_ID', default=''))
OPENAI_PROJECT_ID = _ascii_env(config('OPENAI_PROJECT_ID', default=''))
OPENAI_MODEL = config('OPENAI_MODEL', default='gpt-4o-mini')
# OpenAI voice — TTS + Whisper STT (same API key as chat)
AI_VOICE_PROVIDER = config('AI_VOICE_PROVIDER', default='auto')  # auto | openai | elevenlabs
OPENAI_TTS_MODEL = config('OPENAI_TTS_MODEL', default='tts-1')  # tts-1 | tts-1-hd
OPENAI_TTS_VOICE = config('OPENAI_TTS_VOICE', default='shimmer')  # shimmer/coral = warm female voice
OPENAI_TTS_SPEED = config('OPENAI_TTS_SPEED', default=0.93, cast=float)
OPENAI_TTS_MAX_CHARS = config('OPENAI_TTS_MAX_CHARS', default=4096, cast=int)
OPENAI_STT_MODEL = config('OPENAI_STT_MODEL', default='whisper-1')
OPENAI_STT_ENABLED = config('OPENAI_STT_ENABLED', default=True, cast=bool)
OPENAI_STT_MAX_BYTES = config('OPENAI_STT_MAX_BYTES', default=25 * 1024 * 1024, cast=int)
OPENAI_VOICE_TIMEOUT = config('OPENAI_VOICE_TIMEOUT', default=60, cast=int)
GEMINI_API_KEY = config('GEMINI_API_KEY', default='')
GEMINI_MODEL = config('GEMINI_MODEL', default='gemini-2.0-flash')
GROQ_API_KEY = config('GROQ_API_KEY', default='')
GROQ_MODEL = config('GROQ_MODEL', default='llama-3.1-8b-instant')
OLLAMA_BASE_URL = config('OLLAMA_BASE_URL', default='http://127.0.0.1:11434')
OLLAMA_MODEL = config('OLLAMA_MODEL', default='llama3.2:1b')
OLLAMA_KEEP_ALIVE = config('OLLAMA_KEEP_ALIVE', default='30m')
OLLAMA_NUM_CTX = config('OLLAMA_NUM_CTX', default=2048, cast=int)
AI_TEMPERATURE = config('AI_TEMPERATURE', default=0.4, cast=float)
AI_MAX_TOKENS = config('AI_MAX_TOKENS', default=500, cast=int)
AI_REQUEST_TIMEOUT = config('AI_REQUEST_TIMEOUT', default=90, cast=int)

# ElevenLabs — AI voice (text-to-speech). Get key: https://elevenlabs.io/app/settings/api-keys
ELEVENLABS_API_KEY = config('ELEVENLABS_API_KEY', default='')
ELEVENLABS_VOICE_ID = config('ELEVENLABS_VOICE_ID', default='')
ELEVENLABS_MODEL_ID = config('ELEVENLABS_MODEL_ID', default='eleven_turbo_v2_5')
ELEVENLABS_TIMEOUT = config('ELEVENLABS_TIMEOUT', default=45, cast=int)

# Real-time market data — Kotak Neo (primary) / Finnhub / Yahoo
# Kotak v2 SDK calls the dashboard token "consumer_key"; we accept either env name.
KOTAK_NEO_ACCESS_TOKEN = config('KOTAK_NEO_ACCESS_TOKEN', default='') or config(
    'KOTAK_NEO_CONSUMER_KEY', default=''
)
KOTAK_NEO_BASE_URL = config('KOTAK_NEO_BASE_URL', default='https://mis.kotaksecurities.com')
KOTAK_NEO_QUOTE_CACHE_SECONDS = config('KOTAK_NEO_QUOTE_CACHE_SECONDS', default=15, cast=int)
KOTAK_NEO_UNIVERSE_CACHE_SECONDS = config('KOTAK_NEO_UNIVERSE_CACHE_SECONDS', default=15, cast=int)
KOTAK_NEO_BATCH_SIZE = config('KOTAK_NEO_BATCH_SIZE', default=50, cast=int)
MARKET_DATA_PROVIDER = config('MARKET_DATA_PROVIDER', default='auto')  # auto | kotak_neo | finnhub | yahoo
ALPHA_VANTAGE_API_KEY = config('ALPHA_VANTAGE_API_KEY', default='')
ALPHA_VANTAGE_REQUEST_DELAY_SECONDS = config('ALPHA_VANTAGE_REQUEST_DELAY_SECONDS', default=12, cast=int)
ALPHA_VANTAGE_QUOTE_CACHE_SECONDS = config('ALPHA_VANTAGE_QUOTE_CACHE_SECONDS', default=120, cast=int)
ALPHA_VANTAGE_MAX_QUOTES_PER_REFRESH = config('ALPHA_VANTAGE_MAX_QUOTES_PER_REFRESH', default=5, cast=int)
FINNHUB_API_KEY = config('FINNHUB_API_KEY', default='')
MARKET_QUOTE_CACHE_SECONDS = config('MARKET_QUOTE_CACHE_SECONDS', default=30, cast=int)
MARKET_UNIVERSE_CACHE_SECONDS = config('MARKET_UNIVERSE_CACHE_SECONDS', default=60, cast=int)
NEWS_CACHE_MINUTES = config('NEWS_CACHE_MINUTES', default=15, cast=int)

# TradingView — widget embed works without a key; set these when using Charting Library + UDF
TRADINGVIEW_API_KEY = config('TRADINGVIEW_API_KEY', default='')
TRADINGVIEW_CHARTING_LIBRARY_URL = config('TRADINGVIEW_CHARTING_LIBRARY_URL', default='')
TRADINGVIEW_UDF_BASE_URL = config('TRADINGVIEW_UDF_BASE_URL', default='')
TRADINGVIEW_DEFAULT_EXCHANGE = config('TRADINGVIEW_DEFAULT_EXCHANGE', default='NSE')

# SMS OTP — console (dev), msg91, twilio
_sms_provider_raw = _clean_env(config('SMS_PROVIDER', default='console')).lower()
MSG91_AUTH_KEY = _ascii_env(config('MSG91_AUTH_KEY', default=''))
MSG91_TEMPLATE_ID = _clean_env(config('MSG91_TEMPLATE_ID', default=''))
TWILIO_ACCOUNT_SID = _ascii_env(config('TWILIO_ACCOUNT_SID', default=''))
TWILIO_AUTH_TOKEN = _ascii_env(config('TWILIO_AUTH_TOKEN', default=''))
TWILIO_FROM_NUMBER = _clean_env(config('TWILIO_FROM_NUMBER', default=''))
TWILIO_SERVICE_SID = _ascii_env(config('TWILIO_SERVICE_SID', default=''))
TWILIO_VERIFY_CHANNEL = _clean_env(config('TWILIO_VERIFY_CHANNEL', default='sms')) or 'sms'

if TWILIO_FROM_NUMBER and not TWILIO_FROM_NUMBER.startswith('+'):
    TWILIO_FROM_NUMBER = f'+{TWILIO_FROM_NUMBER.lstrip("+")}'

_twilio_ready = bool(
    TWILIO_ACCOUNT_SID
    and TWILIO_AUTH_TOKEN
    and (TWILIO_SERVICE_SID or TWILIO_FROM_NUMBER)
)
_msg91_ready = bool(MSG91_AUTH_KEY and MSG91_TEMPLATE_ID)

if _sms_provider_raw == 'console':
    if _twilio_ready:
        SMS_PROVIDER = 'twilio'
    elif _msg91_ready:
        SMS_PROVIDER = 'msg91'
    else:
        SMS_PROVIDER = 'console'
else:
    SMS_PROVIDER = _sms_provider_raw

# Payments — Razorpay (https://dashboard.razorpay.com)
RAZORPAY_KEY_ID = config('RAZORPAY_KEY_ID', default='')
RAZORPAY_KEY_SECRET = config('RAZORPAY_KEY_SECRET', default='')
RAZORPAY_WEBHOOK_SECRET = config('RAZORPAY_WEBHOOK_SECRET', default='')

# Verification & Payments — Cashfree (credentials from env only)
CASHFREE_CLIENT_ID = config('CASHFREE_CLIENT_ID', default='')
CASHFREE_CLIENT_SECRET = config('CASHFREE_CLIENT_SECRET', default='')
CASHFREE_ENVIRONMENT = config('CASHFREE_ENVIRONMENT', default='')
CASHFREE_ENV = config('CASHFREE_ENV', default='sandbox')
CASHFREE_API_VERSION = config('CASHFREE_API_VERSION', default='2022-10-26')
CASHFREE_PAYMENT_API_VERSION = config('CASHFREE_PAYMENT_API_VERSION', default='2023-08-01')
CASHFREE_PAYMENTS_BASE_URL = config('CASHFREE_PAYMENTS_BASE_URL', default='')
CASHFREE_PAYOUTS_BASE_URL = config('CASHFREE_PAYOUTS_BASE_URL', default='')
CASHFREE_PAYMENT_WEBHOOK_SECRET = config('CASHFREE_PAYMENT_WEBHOOK_SECRET', default='')
CASHFREE_PAYOUT_WEBHOOK_SECRET = config('CASHFREE_PAYOUT_WEBHOOK_SECRET', default='')
CASHFREE_WEBHOOK_SECRET = config('CASHFREE_WEBHOOK_SECRET', default='')
SECURE_ID_BASE_URL = config('SECURE_ID_BASE_URL', default='')
SECURE_ID_API_KEY = config('SECURE_ID_API_KEY', default='')
SECURE_ID_API_SECRET = config('SECURE_ID_API_SECRET', default='')

# Compliance
KYC_AUTO_APPROVE = config('KYC_AUTO_APPROVE', default=False, cast=bool)
REFERRAL_REWARD_AMOUNT = config('REFERRAL_REWARD_AMOUNT', default=500, cast=int)
APP_SHARE_URL = config('APP_SHARE_URL', default='https://bullwave.in')
# Public URL for email action links (approve/reject). Use your deployed API URL or ngrok in dev.
BACKEND_PUBLIC_URL = _clean_env(config('BACKEND_PUBLIC_URL', default='http://127.0.0.1:8000'), strip_trailing_slash=True)

# Manual KYC admin email — set SMTP credentials in .env for production.
# If left empty, backend will default to: bullwaveteam5@gmail.com
ADMIN_KYC_EMAIL = _clean_env(config('ADMIN_KYC_EMAIL', default=''))
# F&O admin inbox — defaults to ADMIN_KYC_EMAIL when empty
ADMIN_FNO_EMAIL = _clean_env(config('ADMIN_FNO_EMAIL', default=''))
# Phone for auto-created Django reviewer used by email Approve/Reject links (optional)
KYC_EMAIL_REVIEWER_PHONE = _clean_env(config('KYC_EMAIL_REVIEWER_PHONE', default=''))
EMAIL_BACKEND = config('EMAIL_BACKEND', default='django.core.mail.backends.console.EmailBackend')
EMAIL_HOST = _clean_env(config('EMAIL_HOST', default=''))
EMAIL_PORT = config('EMAIL_PORT', default=587, cast=int)
EMAIL_HOST_USER = _clean_env(config('EMAIL_HOST_USER', default=''))
_raw_email_password = _clean_env(config('EMAIL_HOST_PASSWORD', default=''))
# Gmail app passwords are 16 chars; copy-paste often adds spaces or dashes.
EMAIL_HOST_PASSWORD = _raw_email_password.replace(' ', '').replace('-', '')
EMAIL_USE_TLS = config('EMAIL_USE_TLS', default=True, cast=bool)
DEFAULT_FROM_EMAIL = _clean_env(config('DEFAULT_FROM_EMAIL', default='noreply@bullwave.app'))

# Production email via API key (recommended over Gmail SMTP)
# Brevo: https://app.brevo.com/settings/keys/api
# SendGrid: https://app.sendgrid.com/settings/api_keys
EMAIL_PROVIDER = _clean_env(config('EMAIL_PROVIDER', default='smtp')).lower() or 'smtp'
BREVO_API_KEY = _ascii_env(config('BREVO_API_KEY', default=''))
BREVO_FROM_EMAIL = _clean_env(config('BREVO_FROM_EMAIL', default=''))
BREVO_FROM_NAME = _clean_env(config('BREVO_FROM_NAME', default='BullWave Capital')) or 'BullWave Capital'
SENDGRID_API_KEY = _ascii_env(config('SENDGRID_API_KEY', default=''))
SENDGRID_FROM_EMAIL = _clean_env(config('SENDGRID_FROM_EMAIL', default=''))

FNO_MIN_PORTFOLIO_VALUE = config('FNO_MIN_PORTFOLIO_VALUE', default=50000, cast=int)
KITE_API_KEY = config('KITE_API_KEY', default='')
KITE_API_SECRET = config('KITE_API_SECRET', default='')
DHAN_CLIENT_ID = config('DHAN_CLIENT_ID', default='')
DHAN_ACCESS_TOKEN = config('DHAN_ACCESS_TOKEN', default='')
