import os
from pathlib import Path
from urllib.parse import unquote, urlsplit

from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent
ENVIRONMENT = os.environ.get("DJANGO_ENV", "production")
if ENVIRONMENT not in {"development", "test", "production"}:
    raise ImproperlyConfigured("Invalid DJANGO_ENV.")
PRODUCTION = ENVIRONMENT == "production"
DEBUG = ENVIRONMENT == "development" and os.getenv("DJANGO_DEBUG") == "true"
SECRET_KEY = os.getenv("DJANGO_SECRET_KEY") or (
    "" if PRODUCTION else "development-only-tarot-tree-key-do-not-deploy"
)
if PRODUCTION and len(SECRET_KEY) < 50:
    raise ImproperlyConfigured("Set a strong DJANGO_SECRET_KEY.")

def env_list(name, default=""):
    return [part.strip() for part in os.getenv(name, default).split(",") if part.strip()]

ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS", "" if PRODUCTION else "localhost,127.0.0.1")
if PRODUCTION and (not ALLOWED_HOSTS or "*" in ALLOWED_HOSTS):
    raise ImproperlyConfigured("Set explicit DJANGO_ALLOWED_HOSTS.")

database = os.getenv("DATABASE_URL")
if ENVIRONMENT == "test" and os.getenv("TAROT_TEST_SQLITE") == "1":
    DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": ":memory:"}}
else:
    dsn = urlsplit(database or "")
    if dsn.scheme not in {"postgres", "postgresql"} or not dsn.path.strip("/"):
        raise ImproperlyConfigured("Set a PostgreSQL DATABASE_URL.")
    DATABASES = {"default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": unquote(dsn.path[1:]), "USER": unquote(dsn.username or ""),
        "PASSWORD": unquote(dsn.password or ""), "HOST": dsn.hostname or "",
        "PORT": dsn.port or 5432,
    }}

INSTALLED_APPS = [
    "django.contrib.admin", "django.contrib.auth", "django.contrib.contenttypes",
    "django.contrib.sessions", "django.contrib.messages", "django.contrib.staticfiles",
    "rest_framework", "drf_spectacular", "corsheaders",
    "apps.core", "apps.accounts", "apps.ai_gateway", "apps.oracle", "apps.vision",
    "apps.catalog", "apps.store", "apps.entitlements", "apps.payments", "apps.telegram_bot",
]
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "apps.core.http.api_headers",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]
ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
TEMPLATES = [{
    "BACKEND": "django.template.backends.django.DjangoTemplates", "APP_DIRS": True,
    "OPTIONS": {"context_processors": [
        "django.template.context_processors.request",
        "django.contrib.auth.context_processors.auth",
        "django.contrib.messages.context_processors.messages",
    ]},
}]
TIME_ZONE = "UTC"
USE_TZ = True
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_ROOT = Path(os.getenv("TAROT_STORAGE_ROOT", BASE_DIR / ".storage"))
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
    "deck_packages": {"BACKEND": "apps.catalog.models.PrivateFileStorage"},
}
DATA_UPLOAD_MAX_MEMORY_SIZE = 1024 * 1024
FILE_UPLOAD_MAX_MEMORY_SIZE = 1024 * 1024
DATA_UPLOAD_MAX_NUMBER_FILES = 24
from corsheaders.defaults import default_headers

CORS_ALLOWED_ORIGINS = env_list("CORS_ALLOWED_ORIGINS")
CORS_ALLOW_HEADERS = (*default_headers, "idempotency-key")
CSRF_TRUSTED_ORIGINS = env_list("DJANGO_CSRF_TRUSTED_ORIGINS")
if ENVIRONMENT == "development" and not CORS_ALLOWED_ORIGINS:
    CORS_ALLOWED_ORIGIN_REGEXES = [r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"]
AUTH_DEV_SHOW_CODE = (not PRODUCTION) and os.getenv("AUTH_DEV_SHOW_CODE") == "true"
SECURE_SSL_REDIRECT = PRODUCTION
SESSION_COOKIE_SECURE = PRODUCTION
CSRF_COOKIE_SECURE = PRODUCTION
SECURE_HSTS_SECONDS = 31536000 if PRODUCTION else 0
SECURE_HSTS_INCLUDE_SUBDOMAINS = PRODUCTION
SECURE_HSTS_PRELOAD = PRODUCTION
SECURE_PROXY_SSL_HEADER = (
    ("HTTP_X_FORWARDED_PROTO", "https") if os.getenv("TRUST_PROXY_HTTPS") == "true" else None
)
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": f"django.contrib.auth.password_validation.{validator}"}
    for validator in (
        "UserAttributeSimilarityValidator", "MinimumLengthValidator",
        "CommonPasswordValidator", "NumericPasswordValidator",
    )
]

EMAIL_VERIFICATION_ENABLED = os.getenv("EMAIL_VERIFICATION_ENABLED") == "true"
EMAIL_BACKEND = (
    "django.core.mail.backends.smtp.EmailBackend" if PRODUCTION
    else "django.core.mail.backends.locmem.EmailBackend" if ENVIRONMENT == "test"
    else "django.core.mail.backends.console.EmailBackend"
)
EMAIL_HOST = os.getenv("EMAIL_HOST", "")
EMAIL_PORT = int(os.getenv("EMAIL_PORT", "587"))
EMAIL_HOST_USER = os.getenv("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = os.getenv("EMAIL_HOST_PASSWORD", "")
EMAIL_USE_SSL = os.getenv("EMAIL_USE_SSL") == "true"
EMAIL_USE_TLS = (not EMAIL_USE_SSL) and os.getenv("EMAIL_USE_TLS", "true") == "true"
EMAIL_TIMEOUT = 5
DEFAULT_FROM_EMAIL = os.getenv("DEFAULT_FROM_EMAIL", "tarot@example.invalid")
if PRODUCTION and EMAIL_VERIFICATION_ENABLED and (not EMAIL_HOST or DEFAULT_FROM_EMAIL.endswith(".invalid")):
    raise ImproperlyConfigured("Set SMTP configuration before enabling email verification.")
if PRODUCTION and (not EMAIL_HOST or DEFAULT_FROM_EMAIL.endswith(".invalid")):
    import logging as _logging
    _logging.getLogger("tarottree.config").warning(
        "SMTP is not configured (EMAIL_HOST/DEFAULT_FROM_EMAIL) — PRO receipt emails will not be delivered."
    )

# --- PRO subscription, Solana verification, receipts & durable subscriber backup ---
PRO_SOLANA_WALLET = os.getenv("PRO_SOLANA_WALLET", "7oF9eiHf9vYAeEPyQsVoMYhvoq4tt7cuLM2yMXt9yWpu")
PRO_REQUIRE_SOLANA_MEMO = os.getenv("PRO_REQUIRE_SOLANA_MEMO") == "true"
SOLANA_RPC_URL = os.getenv("SOLANA_RPC_URL", "https://api.mainnet-beta.solana.com")
SOLANA_USDC_MINT = os.getenv("SOLANA_USDC_MINT", "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v")
SOLANA_FALLBACK_SOL_USD = float(os.getenv("SOLANA_FALLBACK_SOL_USD", "180.0"))
PRO_EARLY_SUPPORTER_LIMIT = int(os.getenv("PRO_EARLY_SUPPORTER_LIMIT", "100"))
PRO_EARLY_MONTHLY_MINOR = 499
PRO_STANDARD_MONTHLY_MINOR = 699
PRO_ANNUAL_MINOR = 3999
PRO_STANDARD_ANNUAL_MINOR = 5999
PRO_OWNER_NOTIFY_EMAIL = os.getenv("PRO_OWNER_NOTIFY_EMAIL", "")
PRO_OWNER_TELEGRAM_BOT_TOKEN = os.getenv("PRO_OWNER_TELEGRAM_BOT_TOKEN", "")
PRO_OWNER_TELEGRAM_CHAT_ID = os.getenv("PRO_OWNER_TELEGRAM_CHAT_ID", "")
PRO_LEDGER_BACKUP_PATH = Path(
    os.getenv("PRO_LEDGER_BACKUP_PATH", str(MEDIA_ROOT / "pro_subscribers_ledger.jsonl"))
)

# --- Unified DeepSeek / OpenAI-compatible AI keys (100% server-side, never in PWA) ---
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "")

# --- Cloud VLM card recognition (DeepSeek-V4.1-Flash supports image_url natively) ---
VISION_VLM_URL = os.getenv("VISION_VLM_URL", "https://api.deepseek.com/v1/chat/completions")
VISION_VLM_API_KEY = (
    os.getenv("VISION_VLM_API_KEY")
    or DEEPSEEK_API_KEY
    or os.getenv("ORACLE_LLM_API_KEY", "")
)
VISION_VLM_MODEL = os.getenv("VISION_VLM_MODEL", "deepseek-flash")
VISION_VLM_TIMEOUT = float(os.getenv("VISION_VLM_TIMEOUT", "25.0"))
VISION_MAX_CARDS_PER_SCAN = int(os.getenv("VISION_MAX_CARDS_PER_SCAN", "12"))

# --- Oracle LLM & Cloud STT server proxy (defaults to DeepSeek; supports Gemini / OpenAI / Whisper) ---
_ONLY_GEMINI_KEY = bool(os.getenv("GEMINI_API_KEY")) and not (
    DEEPSEEK_API_KEY or os.getenv("ORACLE_LLM_API_KEY") or os.getenv("VISION_VLM_API_KEY")
)
ORACLE_LLM_URL = os.getenv(
    "ORACLE_LLM_URL",
    "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
    if _ONLY_GEMINI_KEY
    else "https://api.deepseek.com/v1/chat/completions",
)
ORACLE_LLM_API_KEY = (
    os.getenv("ORACLE_LLM_API_KEY")
    or DEEPSEEK_API_KEY
    or os.getenv("VISION_VLM_API_KEY")
    or os.getenv("GEMINI_API_KEY", "")
)
ORACLE_LLM_MODEL = os.getenv(
    "ORACLE_LLM_MODEL",
    "gemini-2.5-flash" if _ONLY_GEMINI_KEY else "deepseek-chat",
)
ORACLE_LLM_TIMEOUT = float(os.getenv("ORACLE_LLM_TIMEOUT", "25.0"))

STT_API_URL = os.getenv("STT_API_URL", "")
STT_API_KEY = (
    os.getenv("STT_API_KEY")
    or DEEPSEEK_API_KEY
    or ORACLE_LLM_API_KEY
)
STT_API_MODEL = os.getenv("STT_API_MODEL", "whisper-large-v3")
STT_TIMEOUT = float(os.getenv("STT_TIMEOUT", "25.0"))
STT_MAX_UPLOAD_BYTES = int(os.getenv("STT_MAX_UPLOAD_BYTES", str(5 * 1024 * 1024)))

# --- Server-enforced daily AI quotas (Free vs PRO) ---
ORACLE_FREE_DAILY_LIMIT = int(os.getenv("ORACLE_FREE_DAILY_LIMIT", "15"))
ORACLE_PRO_DAILY_LIMIT = int(os.getenv("ORACLE_PRO_DAILY_LIMIT", "300"))
STT_FREE_DAILY_LIMIT = int(os.getenv("STT_FREE_DAILY_LIMIT", "25"))
STT_PRO_DAILY_LIMIT = int(os.getenv("STT_PRO_DAILY_LIMIT", "300"))

# --- Telegram Mini App & Reminder Bot (Phase E) ---
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_WEBHOOK_SECRET = os.getenv("TELEGRAM_WEBHOOK_SECRET", "")
TELEGRAM_MINIAPP_URL = os.getenv("TELEGRAM_MINIAPP_URL", "https://app.soshallitbe.cyou/")

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": ["apps.accounts.authentication.AccessTokenAuthentication"],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 30,
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "EXCEPTION_HANDLER": "apps.core.api.error_response",
}
SPECTACULAR_SETTINGS = {
    "TITLE": "Tarot Tree API", "VERSION": "1.0.0", "SERVE_INCLUDE_SCHEMA": False,
    "ENUM_NAME_OVERRIDES": {
        "CardOrientation": ["upright", "reversed"],
        "RecognitionOrientation": ["upright", "reversed", "unknown"],
    },
    "COMPONENT_SPLIT_REQUEST": True,
}
