import hashlib
import secrets
import uuid
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
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


class RegisterRequest(serializers.Serializer):
    name = serializers.CharField(min_length=1, max_length=120, trim_whitespace=True)
    email = serializers.EmailField(max_length=254)
    password = serializers.CharField(min_length=8, max_length=128, write_only=True, trim_whitespace=False)
    receiptNumber = serializers.CharField(max_length=48, required=False, allow_blank=True, trim_whitespace=True)


class LoginRequest(serializers.Serializer):
    email = serializers.EmailField(max_length=254)
    password = serializers.CharField(min_length=1, max_length=128, write_only=True, trim_whitespace=False)


class EmailStartResponse(serializers.Serializer):
    devCode = serializers.CharField(required=False)


class EmailProof(serializers.Serializer):
    token = serializers.RegexField(r"^[A-Za-z0-9_-]{6,64}$")


class Identity(serializers.Serializer):
    id = serializers.UUIDField()
    verified = serializers.BooleanField()
    email = serializers.EmailField(allow_null=True)
    name = serializers.CharField(allow_null=True, required=False)
    emailConfirmed = serializers.BooleanField(required=False)
    isPro = serializers.BooleanField(required=False)
    proPlan = serializers.CharField(allow_null=True, required=False)
    proExpiresAt = serializers.DateTimeField(allow_null=True, required=False)
    earlySupporterSlot = serializers.IntegerField(allow_null=True, required=False)


class TokenResponse(Identity):
    token = serializers.CharField()
    expiresAt = serializers.DateTimeField()


class HandoffResponse(serializers.Serializer):
    code = serializers.CharField()
    expiresAt = serializers.DateTimeField()


class HandoffExchangeRequest(serializers.Serializer):
    code = serializers.RegexField(r"^[A-Za-z0-9_-]{16,128}$")


def identity(principal):
    name = principal.display_name or (principal.user.first_name if principal.user_id else "")
    active_pro = principal.has_active_pro
    return {
        "id": str(principal.pk),
        "verified": principal.is_verified,
        "email": principal.verified_email or None,
        "name": name or None,
        "emailConfirmed": bool(principal.email_confirmed),
        "isPro": active_pro,
        "proPlan": (principal.pro_plan or None) if active_pro else None,
        "proExpiresAt": principal.pro_expires_at.isoformat() if (active_pro and principal.pro_expires_at) else None,
        "earlySupporterSlot": principal.early_supporter_slot,
    }


def _migrate_guest_free_grants(guest_principal, principal):
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


@extend_schema(request=RegisterRequest, responses={201: TokenResponse})
@api_view(["POST"])
@permission_classes([AllowAny])
def register_account(request):
    ip_limit(request, "register", 10)
    data = checked(RegisterRequest, request.data)
    name = data["name"].strip()
    email = data["email"].strip().lower()
    password = data["password"]
    receipt_number = (data.get("receiptNumber") or "").strip().upper()
    try:
        validate_password(password)
    except DjangoValidationError as exc:
        raise Problem("weak_password", 400, " ".join(exc.messages)) from None
    guest_principal = _optional_guest_principal(request)
    with transaction.atomic():
        existing = Principal.objects.select_for_update().filter(verified_email=email).first()
        if existing is not None and existing.user_id is not None:
            raise Problem("email_already_registered", 409, "An account with this email already exists.")
        if existing is not None and existing.is_pro:
            from apps.payments.models import ProReceipt

            has_valid_receipt = bool(
                receipt_number
                and ProReceipt.objects.filter(
                    principal=existing,
                    receipt_number__iexact=receipt_number,
                ).exists()
            )
            if not has_valid_receipt:
                raise Problem(
                    "pro_claim_required",
                    403,
                    "This email already has an active PRO subscription. Enter your PRO receipt number from your receipt email to claim it.",
                )
        user = get_user_model().objects.create_user(
            username=f"account-{uuid.uuid4()}",
            email=email,
            password=password,
            first_name=name[:150],
        )
        if existing is not None:
            # Attach credentials to a verified pre-created PRO Principal after receipt proof.
            existing.user = user
            existing.display_name = name
            existing.email_confirmed = True
            existing.save(update_fields=["user", "display_name", "email_confirmed"])
            principal = existing
        else:
            principal = Principal.objects.create(
                user=user,
                verified_email=email,
                display_name=name,
                email_confirmed=False,
            )
        _migrate_guest_free_grants(guest_principal, principal)
        return login(principal, status=201)


@extend_schema(request=LoginRequest, responses={200: TokenResponse})
@api_view(["POST"])
@permission_classes([AllowAny])
def login_account(request):
    ip_limit(request, "login", 15)
    data = checked(LoginRequest, request.data)
    email = data["email"].strip().lower()
    password = data["password"]
    rate_limit(f"login:{hashlib.sha256(email.encode()).hexdigest()}", 10, 900)
    guest_principal = _optional_guest_principal(request)
    principal = Principal.objects.select_related("user").filter(verified_email=email).first()
    if (
        principal is None
        or principal.user_id is None
        or not principal.user.is_active
        or not principal.user.check_password(password)
    ):
        raise Problem("invalid_credentials", 401, "Invalid email or password.")
    with transaction.atomic():
        _migrate_guest_free_grants(guest_principal, principal)
        return login(principal, status=200)


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
            principal.email_confirmed = True
            principal.save(update_fields=["user", "email_confirmed"])
        elif not principal.email_confirmed:
            principal.email_confirmed = True
            principal.save(update_fields=["email_confirmed"])
        if not principal.is_verified:
            raise Problem("account_unavailable", 403, "Account is unavailable.")
        _migrate_guest_free_grants(guest_principal, principal)
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


@extend_schema(responses={200: Identity, 204: None})
@api_view(["GET", "DELETE"])
def me(request):
    if request.method == "DELETE":
        principal = request.auth.principal
        now = timezone.now()
        with transaction.atomic():
            principal = Principal.objects.select_for_update().select_related("user").get(pk=principal.pk)
            principal.tokens.filter(revoked_at__isnull=True).update(revoked_at=now)
            principal.handoffs.filter(used_at__isnull=True).update(used_at=now)
            if principal.user_id is not None:
                user = principal.user
                user.is_active = False
                user.email = ""
                user.first_name = ""
                user.set_unusable_password()
                user.save(update_fields=["is_active", "email", "first_name", "password"])
            principal.display_name = ""
            principal.email_confirmed = False
            principal.is_pro = False
            principal.pro_plan = Principal.ProPlan.NONE
            principal.pro_expires_at = now
            principal.verified_email = f"deleted-{principal.pk}@deleted.invalid"
            principal.save(
                update_fields=[
                    "display_name",
                    "email_confirmed",
                    "is_pro",
                    "pro_plan",
                    "pro_expires_at",
                    "verified_email",
                ]
            )
        return Response(status=204)
    return Response(identity(request.auth.principal))


@extend_schema(request=None, responses={204: None})
@api_view(["POST"])
def logout(request):
    request.auth.revoked_at = timezone.now()
    request.auth.save(update_fields=["revoked_at"])
    return Response(status=204)
