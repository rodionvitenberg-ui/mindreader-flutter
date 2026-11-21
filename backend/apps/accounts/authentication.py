import hashlib
import secrets
from datetime import timedelta

from django.contrib.auth.models import AnonymousUser
from django.utils import timezone
from drf_spectacular.extensions import OpenApiAuthenticationExtension
from rest_framework.authentication import BaseAuthentication, get_authorization_header
from rest_framework.exceptions import AuthenticationFailed

from .models import AccessToken


def digest_token(raw):
    return hashlib.sha256(raw.encode()).hexdigest()


def issue_token(principal):
    value = secrets.token_urlsafe(32)
    expires = timezone.now() + timedelta(days=30 if principal.is_verified else 7)
    AccessToken.objects.create(principal=principal, digest=digest_token(value), expires_at=expires)
    return value, expires.isoformat()


class GuestUser(AnonymousUser):
    is_authenticated = True


class AccessTokenAuthentication(BaseAuthentication):
    def authenticate_header(self, request):
        return "Bearer"

    def authenticate(self, request):
        auth = get_authorization_header(request).split()
        if not auth:
            return None
        if len(auth) != 2 or auth[0].lower() != b"bearer" or len(auth[1]) > 128:
            raise AuthenticationFailed("Invalid access token.")
        try:
            digest = digest_token(auth[1].decode("ascii"))
            token = AccessToken.objects.select_related("principal__user").get(
                digest=digest, revoked_at__isnull=True, expires_at__gt=timezone.now()
            )
        except (AccessToken.DoesNotExist, UnicodeError):
            raise AuthenticationFailed("Invalid or expired access token.") from None
        user = token.principal.user
        if user and not user.is_active:
            raise AuthenticationFailed("Inactive account.")
        return user or GuestUser(), token


class BearerScheme(OpenApiAuthenticationExtension):
    target_class = "apps.accounts.authentication.AccessTokenAuthentication"
    name = "tarotBearer"

    def get_security_definition(self, auto_schema):
        return {"type": "http", "scheme": "bearer"}
