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
    "apps.core", "apps.accounts",
]
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
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
DATA_UPLOAD_MAX_MEMORY_SIZE = 1024 * 1024
FILE_UPLOAD_MAX_MEMORY_SIZE = 1024 * 1024
DATA_UPLOAD_MAX_NUMBER_FILES = 24
CORS_ALLOWED_ORIGINS = env_list("CORS_ALLOWED_ORIGINS")
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
EMAIL_USE_TLS = True
EMAIL_TIMEOUT = 5
DEFAULT_FROM_EMAIL = os.getenv("DEFAULT_FROM_EMAIL", "tarot@example.invalid")
if PRODUCTION and EMAIL_VERIFICATION_ENABLED and not EMAIL_HOST:
    raise ImproperlyConfigured("Set SMTP configuration before enabling email verification.")

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": ["apps.accounts.authentication.AccessTokenAuthentication"],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 30,
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "EXCEPTION_HANDLER": "apps.core.api.error_response",
}
SPECTACULAR_SETTINGS = {"TITLE": "Tarot Tree API", "VERSION": "1.0.0", "SERVE_INCLUDE_SCHEMA": False}
