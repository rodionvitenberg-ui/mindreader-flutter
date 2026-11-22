import hashlib
import secrets
import uuid
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.decorators import api_view, permission_classes
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from apps.core.api import Problem, checked, ip_limit, rate_limit
from apps.entitlements.models import Grant, active_grants

from .authentication import AccessTokenAuthentication, digest_token, issue_token
from .models import EmailChallenge, HandoffToken, Principal


class EmailRequest(serializers.Serializer):
    email = serializers.EmailField(max_length=254)


class EmailStartResponse(serializers.Serializer):
    devCode = serializers.CharField(required=False)


class EmailProof(serializers.Serializer):
    token = serializers.RegexField(r"^[A-Za-z0-9_-]{6,64}$")


class Identity(serializers.Serializer):
    id = serializers.UUIDField()
    verified = serializers.BooleanField()
    email = serializers.EmailField(allow_null=True)


class TokenResponse(Identity):
    token = serializers.CharField()
    expiresAt = serializers.DateTimeField()


class HandoffResponse(serializers.Serializer):
    code = serializers.CharField()
    expiresAt = serializers.DateTimeField()


class HandoffExchangeRequest(serializers.Serializer):
    code = serializers.RegexField(r"^[A-Za-z0-9_-]{16,128}$")


def identity(principal):
    return {
        "id": str(principal.pk),
        "verified": principal.is_verified,
        "email": principal.verified_email or None,
    }


def login(principal, status=200):
    token, expires = issue_token(principal)
    return Response({**identity(principal), "token": token, "expiresAt": expires}, status=status)


def _optional_guest_principal(request):
    """Returns the caller's unverified guest Principal if a valid Bearer header was supplied."""
    if request.auth is not None:
        p = request.auth.principal
        return p if not p.is_verified else None
    try:
        res = AccessTokenAuthentication().authenticate(request)
    except AuthenticationFailed:
        return None
    if res is None:
        return None
    _, token = res
    return token.principal if not token.principal.is_verified else None


@extend_schema(request=None, responses={201: TokenResponse})
@api_view(["POST"])
@permission_classes([AllowAny])
def guest(request):
    ip_limit(request, "guest", 12)
    return login(Principal.objects.create(), 201)


@extend_schema(request=EmailRequest, responses={202: EmailStartResponse})
@api_view(["POST"])
@permission_classes([AllowAny])
def email_start(request):
    if not settings.EMAIL_VERIFICATION_ENABLED:
        raise Problem("email_unavailable", 503, "Email verification is unavailable.")
    ip_limit(request, "email_start", 6)
    email = checked(EmailRequest, request.data)["email"].lower()
    rate_limit(f"email:{hashlib.sha256(email.encode()).hexdigest()}", 3, 3600)
    value = secrets.token_urlsafe(32)
    challenge = EmailChallenge.objects.create(
        email=email, digest=digest_token(value), expires_at=timezone.now() + timedelta(minutes=15),
    )
    try:
        send_mail("Tarot Tree sign-in", f"Single-use code: {value}", settings.DEFAULT_FROM_EMAIL, [email])
    except (OSError, ValueError):
        challenge.delete()
        raise Problem("email_unavailable", 503, "Email verification is unavailable.") from None
    if getattr(settings, "AUTH_DEV_SHOW_CODE", False):
        return Response({"devCode": value}, status=202)
    return Response(status=202)


@extend_schema(request=EmailProof, responses=TokenResponse)
@api_view(["POST"])
@permission_classes([AllowAny])
def email_verify(request):
    ip_limit(request, "email_verify", 12)
    value = checked(EmailProof, request.data)["token"]
    guest_principal = _optional_guest_principal(request)
    with transaction.atomic():
        challenge = EmailChallenge.objects.select_for_update().filter(
            digest=digest_token(value), used_at__isnull=True, expires_at__gt=timezone.now(),
        ).first()
        if challenge is None:
            raise Problem("invalid_verification", 400, "Invalid or expired verification code.")
        principal, _ = Principal.objects.get_or_create(verified_email=challenge.email)
        principal = Principal.objects.select_for_update().get(pk=principal.pk)
        if principal.user_id is None:
            principal.user = get_user_model().objects.create_user(
                username=f"account-{uuid.uuid4()}", email=challenge.email,
            )
            principal.save(update_fields=["user"])
        if not principal.is_verified:
            raise Problem("account_unavailable", 403, "Account is unavailable.")
        # Carry over any free gift grants claimed while browsing as a guest.
        if guest_principal is not None and guest_principal.pk != principal.pk:
            guest_free_decks = active_grants(guest_principal).filter(
                source=Grant.Source.FREE
            ).values_list("deck_id", flat=True)
            for deck_id in guest_free_decks:
                Grant.objects.get_or_create(
                    owner=principal,
                    deck_id=deck_id,
                    source=Grant.Source.FREE,
                    revoked_at__isnull=True,
                )
        challenge.used_at = timezone.now()
        challenge.save(update_fields=["used_at"])
        return login(principal)


@extend_schema(request=None, responses={201: HandoffResponse})
@api_view(["POST"])
def handoff_create(request):
    principal = request.auth.principal
    if not principal.is_verified:
        raise Problem("verified_account_required", 403, "Verify an account before starting web checkout.")
    rate_limit(f"handoff:{principal.pk}", 20)
    raw = secrets.token_urlsafe(32)
    expires = timezone.now() + timedelta(minutes=5)
    HandoffToken.objects.create(principal=principal, digest=digest_token(raw), expires_at=expires)
    return Response({"code": raw, "expiresAt": expires.isoformat()}, status=201)


@extend_schema(request=HandoffExchangeRequest, responses=TokenResponse)
@api_view(["POST"])
@permission_classes([AllowAny])
def handoff_exchange(request):
    ip_limit(request, "handoff_exchange", 20)
    raw = checked(HandoffExchangeRequest, request.data)["code"]
    with transaction.atomic():
        token = (
            HandoffToken.objects.select_for_update()
            .select_related("principal__user")
            .filter(digest=digest_token(raw), used_at__isnull=True, expires_at__gt=timezone.now())
            .first()
        )
        if token is None or not token.principal.is_verified:
            raise Problem("invalid_handoff", 400, "Invalid or expired handoff code.")
        token.used_at = timezone.now()
        token.save(update_fields=["used_at"])
        return login(token.principal)


@extend_schema(responses=Identity)
@api_view(["GET"])
def me(request):
    return Response(identity(request.auth.principal))


@extend_schema(request=None, responses={204: None})
@api_view(["POST"])
def logout(request):
    request.auth.revoked_at = timezone.now()
    request.auth.save(update_fields=["revoked_at"])
    return Response(status=204)
