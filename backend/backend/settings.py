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
    ALLOWED_HOSTS = ["3.107.192.232", "127.0.0.1","localhost",]
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {'class': 'logging.StreamHandler'},
        # Mirrors WARNING+ records into `core.models.SystemLog` so they show
        # up in the admin panel's Logs page. Wired onto the root logger below
        # so it catches every `bullwave.*` logger project-wide (KYC,
        # payments, market data, unhandled DRF exceptions via
        # `bullwave.errors`, etc.) without having to list each one.
        'db': {'class': 'core.log_handler.DatabaseLogHandler', 'level': 'WARNING'},
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
        # SMS/email delivery diagnostics. Needs INFO explicitly: the root
        # logger sits at WARNING, so successful-send lines (which carry the
        # provider's accept/reject status — e.g. Infobip's PENDING_ACCEPTED
        # vs REJECTED_NOT_ENOUGH_CREDITS) were being dropped, leaving no way
        # to tell "provider accepted it" from "provider silently refused it"
        # when a user reports an OTP never arriving.
        'bullwave.integrations': {
            'handlers': ['console'],
            'level': 'INFO',
        },
    },
    'root': {
        'handlers': ['console', 'db'],
        'level': 'WARNING',
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
    'core',
    'accounts.apps.AccountsConfig',
    'kyc',
    'payments',
    'finance',
    'stocks.apps.StocksConfig',
    'engagement',
    'education',
    'ai',
    'adminpanel',
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
        'PASSWORD': config('DB_PASSWORD', default='Bullwave1234'),
        'HOST': config('DB_HOST', default='database-1.c9ivmu0m4uxk.ap-southeast-2.rds.amazonaws.com'),
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
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
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
    'EXCEPTION_HANDLER': 'core.exception_handler.custom_exception_handler',
}
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=7),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=30),
    'ROTATE_REFRESH_TOKENS': True,
}
CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOWED_ORIGINS = config(
    'CORS_ALLOWED_ORIGINS',
    # Includes the Vite dev-server default port (5173) so the separate
    # admin-panel React app can call this API from a local dev machine even
    # when DEBUG=False (where CORS_ALLOW_ALL_ORIGINS no longer applies).
    # Add your deployed admin-panel URL to the CORS_ALLOWED_ORIGINS env var
    # in production.
    default='http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173',
    cast=lambda v: [origin.strip() for origin in v.split(',') if origin.strip()],
)
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'bullwave-cache',
    }
}
OTP_EXPIRY_MINUTES = config('OTP_EXPIRY_MINUTES', default=5, cast=int)
AI_PROVIDER = config('AI_PROVIDER', default='ollama')
OPENAI_API_KEY = _ascii_env(config('OPENAI_API_KEY', default=''))
OPENAI_ORG_ID = _ascii_env(config('OPENAI_ORG_ID', default=''))
OPENAI_PROJECT_ID = _ascii_env(config('OPENAI_PROJECT_ID', default=''))
OPENAI_MODEL = config('OPENAI_MODEL', default='gpt-4o-mini')
AI_VOICE_PROVIDER = config('AI_VOICE_PROVIDER', default='auto')
OPENAI_TTS_MODEL = config('OPENAI_TTS_MODEL', default='tts-1')
OPENAI_TTS_VOICE = config('OPENAI_TTS_VOICE', default='shimmer')
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
ELEVENLABS_API_KEY = config('ELEVENLABS_API_KEY', default='')
ELEVENLABS_VOICE_ID = config('ELEVENLABS_VOICE_ID', default='')
ELEVENLABS_MODEL_ID = config('ELEVENLABS_MODEL_ID', default='eleven_turbo_v2_5')
ELEVENLABS_TIMEOUT = config('ELEVENLABS_TIMEOUT', default=45, cast=int)
KOTAK_NEO_ACCESS_TOKEN = config('KOTAK_NEO_ACCESS_TOKEN', default='') or config(
    'KOTAK_NEO_CONSUMER_KEY', default=''
)
KOTAK_NEO_BASE_URL = config('KOTAK_NEO_BASE_URL', default='https://mis.kotaksecurities.com')
KOTAK_NEO_QUOTE_CACHE_SECONDS = config('KOTAK_NEO_QUOTE_CACHE_SECONDS', default=15, cast=int)
KOTAK_NEO_UNIVERSE_CACHE_SECONDS = config('KOTAK_NEO_UNIVERSE_CACHE_SECONDS', default=15, cast=int)
KOTAK_NEO_BATCH_SIZE = config('KOTAK_NEO_BATCH_SIZE', default=50, cast=int)
MARKET_DATA_PROVIDER = config('MARKET_DATA_PROVIDER', default='auto')
ALPHA_VANTAGE_API_KEY = config('ALPHA_VANTAGE_API_KEY', default='')
ALPHA_VANTAGE_REQUEST_DELAY_SECONDS = config('ALPHA_VANTAGE_REQUEST_DELAY_SECONDS', default=12, cast=int)
ALPHA_VANTAGE_QUOTE_CACHE_SECONDS = config('ALPHA_VANTAGE_QUOTE_CACHE_SECONDS', default=120, cast=int)
ALPHA_VANTAGE_MAX_QUOTES_PER_REFRESH = config('ALPHA_VANTAGE_MAX_QUOTES_PER_REFRESH', default=5, cast=int)
FINNHUB_API_KEY = config('FINNHUB_API_KEY', default='')
MARKET_QUOTE_CACHE_SECONDS = config('MARKET_QUOTE_CACHE_SECONDS', default=30, cast=int)
MARKET_UNIVERSE_CACHE_SECONDS = config('MARKET_UNIVERSE_CACHE_SECONDS', default=60, cast=int)
NEWS_CACHE_MINUTES = config('NEWS_CACHE_MINUTES', default=15, cast=int)
TRADINGVIEW_API_KEY = config('TRADINGVIEW_API_KEY', default='')
TRADINGVIEW_CHARTING_LIBRARY_URL = config('TRADINGVIEW_CHARTING_LIBRARY_URL', default='')
TRADINGVIEW_UDF_BASE_URL = config('TRADINGVIEW_UDF_BASE_URL', default='')
TRADINGVIEW_DEFAULT_EXCHANGE = config('TRADINGVIEW_DEFAULT_EXCHANGE', default='NSE')
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
INFOBIP_BASE_URL = _clean_env(config('INFOBIP_BASE_URL', default=''))
INFOBIP_API_KEY = _ascii_env(config('INFOBIP_API_KEY', default=''))
INFOBIP_SENDER = _clean_env(config('INFOBIP_SENDER', default='BullWave')) or 'BullWave'
# WhatsApp OTP delivery via Infobip. Useful in India specifically, where
# plain SMS requires DLT sender/template registration but WhatsApp does not
# — it uses Meta-approved message templates instead.
# OTP_CHANNEL=whatsapp switches OTP delivery to WhatsApp; SMS stays the
# default so existing deployments are unaffected.
OTP_CHANNEL = _clean_env(config('OTP_CHANNEL', default='sms')).lower() or 'sms'
INFOBIP_WHATSAPP_SENDER = _clean_env(config('INFOBIP_WHATSAPP_SENDER', default=''))
INFOBIP_WHATSAPP_TEMPLATE = _clean_env(config('INFOBIP_WHATSAPP_TEMPLATE', default=''))
INFOBIP_WHATSAPP_LANGUAGE = _clean_env(config('INFOBIP_WHATSAPP_LANGUAGE', default='en')) or 'en'
# Authentication-category WhatsApp templates carry a "copy code" button whose
# parameter must repeat the OTP. Set to False for a plain body-only template.
INFOBIP_WHATSAPP_HAS_BUTTON = config('INFOBIP_WHATSAPP_HAS_BUTTON', default=True, cast=bool)
if INFOBIP_BASE_URL and not INFOBIP_BASE_URL.startswith('http'):
    INFOBIP_BASE_URL = f'https://{INFOBIP_BASE_URL}'
INFOBIP_BASE_URL = INFOBIP_BASE_URL.rstrip('/')
_infobip_ready = bool(INFOBIP_BASE_URL and INFOBIP_API_KEY)
if _sms_provider_raw == 'console':
    if _infobip_ready:
        SMS_PROVIDER = 'infobip'
    elif _twilio_ready:
        SMS_PROVIDER = 'twilio'
    elif _msg91_ready:
        SMS_PROVIDER = 'msg91'
    else:
        SMS_PROVIDER = 'console'
else:
    SMS_PROVIDER = _sms_provider_raw
BREVO_API_KEY = _ascii_env(config('BREVO_API_KEY', default=''))
BREVO_SENDER_EMAIL = _clean_env(config('BREVO_SENDER_EMAIL', default=''))
BREVO_SENDER_NAME = _clean_env(config('BREVO_SENDER_NAME', default='Capital Bullwave'))
EMAIL_OTP_EXPIRY_MINUTES = config('EMAIL_OTP_EXPIRY_MINUTES', default=10, cast=int)
RAZORPAY_KEY_ID = config('RAZORPAY_KEY_ID', default='')
RAZORPAY_KEY_SECRET = config('RAZORPAY_KEY_SECRET', default='')
RAZORPAY_WEBHOOK_SECRET = config('RAZORPAY_WEBHOOK_SECRET', default='')
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
EKO_DEVELOPER_KEY = config('EKO_DEVELOPER_KEY', default='')
EKO_KEY = config('EKO_KEY', default='') or config('EKO_ACCESS_KEY', default='')
EKO_INITIATOR_ID = config('EKO_INITIATOR_ID', default='')
EKO_USER_CODE = config('EKO_USER_CODE', default='')
EKO_ENV = config('EKO_ENV', default='') or config('EKO_ENVIRONMENT', default='sandbox')
EKO_BASE_URL = config('EKO_BASE_URL', default='')
EKO_API_VERSION = config('EKO_API_VERSION', default='v3')
KYC_AUTO_APPROVE = config('KYC_AUTO_APPROVE', default=False, cast=bool)
REFERRAL_REWARD_AMOUNT = config('REFERRAL_REWARD_AMOUNT', default=500, cast=int)
APP_SHARE_URL = config('APP_SHARE_URL', default='https://bullwave.in')
BACKEND_PUBLIC_URL = _clean_env(config('BACKEND_PUBLIC_URL', default='http://127.0.0.1:8000'), strip_trailing_slash=True)
ADMIN_KYC_EMAIL = _clean_env(config('ADMIN_KYC_EMAIL', default=''))
ADMIN_FNO_EMAIL = _clean_env(config('ADMIN_FNO_EMAIL', default=''))
KYC_EMAIL_REVIEWER_PHONE = _clean_env(config('KYC_EMAIL_REVIEWER_PHONE', default=''))
EMAIL_BACKEND = config('EMAIL_BACKEND', default='django.core.mail.backends.console.EmailBackend')
EMAIL_HOST = _clean_env(config('EMAIL_HOST', default=''))
EMAIL_PORT = config('EMAIL_PORT', default=587, cast=int)
EMAIL_HOST_USER = _clean_env(config('EMAIL_HOST_USER', default=''))
_raw_email_password = _clean_env(config('EMAIL_HOST_PASSWORD', default=''))
EMAIL_HOST_PASSWORD = _raw_email_password.replace(' ', '').replace('-', '')
EMAIL_USE_TLS = config('EMAIL_USE_TLS', default=True, cast=bool)
DEFAULT_FROM_EMAIL = _clean_env(config('DEFAULT_FROM_EMAIL', default='noreply@bullwave.app'))
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
