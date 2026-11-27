import hmac
from datetime import timedelta

from django.conf import settings
from django.utils import timezone
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from apps.core.api import Problem, checked, ip_limit

from .models import TelegramCheckInReminder, TelegramSubscriber
from .service import _norm_lang, handle_bot_update, verify_webapp_init_data


class CheckInScheduleInput(serializers.Serializer):
    initData = serializers.CharField(max_length=4096)
    days = serializers.ChoiceField((3, 7, 14), default=7)
    spreadTitle = serializers.CharField(max_length=160, required=False, allow_blank=True, default="")


class CheckInScheduleOutput(serializers.Serializer):
    id = serializers.UUIDField()
    dueAt = serializers.DateTimeField()


@extend_schema(request=OpenApiTypes.OBJECT, responses={200: OpenApiTypes.OBJECT})
@api_view(["POST"])
@permission_classes([AllowAny])
def webhook(request):
    """Receives Telegram Bot API webhook updates (verified via secret token header)."""
    expected = (settings.TELEGRAM_WEBHOOK_SECRET or "").strip()
    if expected:
        provided = (request.headers.get("X-Telegram-Bot-Api-Secret-Token") or "").strip()
        if not provided or not hmac.compare_digest(expected, provided):
            raise Problem("forbidden", 403, "Invalid Telegram webhook secret.")
    elif settings.PRODUCTION:
        raise Problem("telegram_unconfigured", 503, "TELEGRAM_WEBHOOK_SECRET is not configured.")

    payload = request.data if isinstance(request.data, dict) else {}
    result = handle_bot_update(payload)
    return Response({"ok": True, **result})


@extend_schema(request=CheckInScheduleInput, responses={201: CheckInScheduleOutput})
@api_view(["POST"])
@permission_classes([AllowAny])
def schedule_checkin(request):
    """Schedules a 3/7/14-day Zeigarnik check-in reminder from the Telegram Mini App."""
    ip_limit(request, "tg_checkin", 20)
    data = checked(CheckInScheduleInput, request.data)
    token = (settings.TELEGRAM_BOT_TOKEN or "").strip()
    if not token:
        raise Problem("telegram_unconfigured", 503, "Telegram bot token is not configured.")

    verified = verify_webapp_init_data(data["initData"], token)
    if verified is None or not isinstance(verified.get("user_obj"), dict):
        raise Problem("invalid_telegram_auth", 401, "Invalid Telegram Mini App initData.")

    user = verified["user_obj"]
    chat_id = user.get("id")
    if not isinstance(chat_id, int):
        raise Problem("invalid_telegram_auth", 401, "Missing Telegram user id.")

    lang = _norm_lang(user.get("language_code"))
    sub, _ = TelegramSubscriber.objects.get_or_create(
        chat_id=chat_id,
        defaults={"language_code": lang, "active": True},
    )
    if not sub.active:
        sub.active = True
        sub.save(update_fields=["active", "updated_at"])

    due_at = timezone.now() + timedelta(days=data["days"])
    row = TelegramCheckInReminder.objects.create(
        subscriber=sub,
        spread_title=data.get("spreadTitle", "").strip(),
        due_at=due_at,
    )
    return Response({"id": str(row.pk), "dueAt": row.due_at.isoformat()}, status=201)
