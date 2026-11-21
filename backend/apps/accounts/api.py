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
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from apps.core.api import Problem, checked, ip_limit, rate_limit

from .authentication import digest_token, issue_token
from .models import EmailChallenge, Principal


class EmailRequest(serializers.Serializer):
    email = serializers.EmailField(max_length=254)


class EmailProof(serializers.Serializer):
    token = serializers.RegexField(r"^[A-Za-z0-9_-]{43}$")


class Identity(serializers.Serializer):
    id = serializers.UUIDField()
    verified = serializers.BooleanField()


class TokenResponse(Identity):
    token = serializers.CharField()
    expiresAt = serializers.DateTimeField()


def identity(principal):
    return {"id": str(principal.pk), "verified": principal.is_verified}


def login(principal, status=200):
    token, expires = issue_token(principal)
    return Response({**identity(principal), "token": token, "expiresAt": expires}, status=status)


@extend_schema(request=None, responses={201: TokenResponse})
@api_view(["POST"])
@permission_classes([AllowAny])
def guest(request):
    ip_limit(request, "guest", 12)
    return login(Principal.objects.create(), 201)


@extend_schema(request=EmailRequest, responses={202: None})
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
    return Response(status=202)


@extend_schema(request=EmailProof, responses=TokenResponse)
@api_view(["POST"])
@permission_classes([AllowAny])
def email_verify(request):
    ip_limit(request, "email_verify", 12)
    value = checked(EmailProof, request.data)["token"]
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
        challenge.used_at = timezone.now()
        challenge.save(update_fields=["used_at"])
        return login(principal)


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
