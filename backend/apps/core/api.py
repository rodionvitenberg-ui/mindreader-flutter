import hashlib
import json
import re
import uuid
from datetime import timedelta

from django.core.exceptions import RequestDataTooBig, TooManyFilesSent
from django.db import transaction
from django.utils import timezone
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import serializers
from rest_framework.decorators import api_view, permission_classes
from rest_framework.exceptions import APIException
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import exception_handler

from .models import Counter, Operation


IDEMPOTENCY = OpenApiParameter("Idempotency-Key", str, OpenApiParameter.HEADER, required=True)


class Problem(APIException):
    def __init__(self, code, status, detail, extra=None):
        self.status_code = status
        self.extra = extra or {}
        super().__init__(detail, code)


def error_response(exc, context):
    if isinstance(exc, (RequestDataTooBig, TooManyFilesSent)):
        exc = Problem("request_too_large", 413, "Request exceeds the upload limit.")
    response = exception_handler(exc, context)
    if response is not None:
        data = response.data
        detail = data.get("detail") if isinstance(data, dict) else None
        code = getattr(detail, "code", None)
        response.data = {
            "code": code or {400: "invalid_request", 404: "not_found"}.get(response.status_code, "request_failed"),
            "detail": detail or "The request could not be accepted.",
            "requestId": getattr(context.get("request"), "api_request_id", None) or str(uuid.uuid4()),
        }
        if isinstance(exc, Problem) and exc.extra:
            response.data.update(exc.extra)
        if detail is None:
            response.data["fields"] = data
    return response


def checked(serializer_class, data):
    serializer = serializer_class(data=data)
    serializer.is_valid(raise_exception=True)
    return serializer.validated_data


def _window_bounds(seconds=60):
    now = timezone.now()
    window = now.replace(microsecond=0) - timedelta(seconds=int(now.timestamp()) % seconds)
    return window, window + timedelta(seconds=seconds)


def rate_limit(key, limit, seconds=60):
    window, _ = _window_bounds(seconds)
    with transaction.atomic():
        row, _ = Counter.objects.select_for_update().get_or_create(key=key, window=window)
        if row.count >= limit:
            raise Problem("rate_limited", 429, "Request limit reached.")
        row.count += 1
        row.save(update_fields=["count"])


def quota_peek(key, limit, seconds=86400):
    window, reset_at = _window_bounds(seconds)
    row = Counter.objects.filter(key=key, window=window).first()
    used = row.count if row else 0
    return {
        "used": used,
        "limit": limit,
        "remaining": max(0, limit - used),
        "resetAt": reset_at.isoformat(),
    }


def consume_quota(key, limit, seconds=86400, *, code="quota_exceeded", detail="Daily quota reached."):
    window, reset_at = _window_bounds(seconds)
    with transaction.atomic():
        row, _ = Counter.objects.select_for_update().get_or_create(key=key, window=window)
        if row.count >= limit:
            raise Problem(
                code,
                429,
                detail,
                extra={
                    "used": row.count,
                    "limit": limit,
                    "remaining": 0,
                    "resetAt": reset_at.isoformat(),
                },
            )
        row.count += 1
        row.save(update_fields=["count"])
        return {
            "used": row.count,
            "limit": limit,
            "remaining": max(0, limit - row.count),
            "resetAt": reset_at.isoformat(),
        }


def _client_ip(request):
    import os
    if os.getenv("TRUST_PROXY_HTTPS") == "true":
        real_ip = (request.META.get("HTTP_X_REAL_IP") or "").strip()
        if real_ip:
            return real_ip
        forwarded = (request.META.get("HTTP_X_FORWARDED_FOR") or "").strip()
        if forwarded:
            parts = [p.strip() for p in forwarded.split(",") if p.strip()]
            if parts:
                return parts[-1]
    return request.META.get("REMOTE_ADDR", "unknown")


def ip_limit(request, scope, limit):
    address = _client_ip(request)
    digest = hashlib.sha256(address.encode()).hexdigest()[:32]
    rate_limit(f"ip:{scope}:{digest}", limit)


def operation(request, scope, payload):
    key = request.headers.get("Idempotency-Key", "")
    if not re.fullmatch(r"[A-Za-z0-9_.:-]{1,128}", key):
        raise Problem("idempotency_key_required", 400, "Supply a valid Idempotency-Key header.")
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), default=str)
    fingerprint = hashlib.sha256(canonical.encode()).hexdigest()
    row, created = Operation.objects.select_for_update().get_or_create(
        owner=request.auth.principal, scope=scope, key=key, defaults={"fingerprint": fingerprint}
    )
    if row.fingerprint != fingerprint:
        raise Problem("idempotency_conflict", 409, "This key is already bound to different data.")
    if not created and row.status_code is None:
        raise Problem("operation_in_progress", 409, "This operation has already started.")
    return row, created


def finish(row, data, status=200):
    row.response, row.status_code = data, status
    row.save(update_fields=["response", "status_code"])
    return Response(data, status=status)


def replay(row):
    return Response(row.response, status=row.status_code)


class HealthSerializer(serializers.Serializer):
    status = serializers.CharField()


@extend_schema(responses=HealthSerializer)
@api_view(["GET"])
@permission_classes([AllowAny])
def health(request):
    from django.db import OperationalError, connection
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
    except OperationalError:
        return Response({"status": "unavailable"}, status=503)
    return Response({"status": "ok"})


class PublicConfigSerializer(serializers.Serializer):
    systems = serializers.ListField(child=serializers.CharField())
    guestAccess = serializers.BooleanField()
    emailVerification = serializers.BooleanField()
    devPayments = serializers.BooleanField()
    proOffer = serializers.DictField()


@extend_schema(responses=PublicConfigSerializer)
@api_view(["GET"])
@permission_classes([AllowAny])
def public_config(request):
    import os
    from django.conf import settings
    from apps.payments.pro_service import pro_offer_snapshot

    dev_payments = (
        not settings.PRODUCTION
        and os.getenv("PAYMENTS_ENABLE_DEV") == "true"
        and len(os.getenv("PAYMENTS_DEV_WEBHOOK_SECRET", "")) >= 32
    )
    return Response({
        "systems": ["tarot", "lenormand", "runes"],
        "guestAccess": True,
        "emailVerification": settings.EMAIL_VERIFICATION_ENABLED,
        "devPayments": dev_payments,
        "proOffer": pro_offer_snapshot(),
    })
