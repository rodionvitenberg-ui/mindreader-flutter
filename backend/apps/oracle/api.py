from django.conf import settings
from django.db import transaction
from django.shortcuts import get_object_or_404
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import generics, serializers, status
from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response

from apps.core.api import (IDEMPOTENCY, Problem, checked, consume_quota, finish,
                           operation, quota_peek, rate_limit, replay)

from .models import Personality, Position, Reading
from .proxy_service import complete_oracle_prompt, transcribe_audio_bytes
from .serializers import (CardUpdate, MessageInput, PersonalityOutput, PositionOutput,
                          ReadingContext, ReadingInput, ReadingOutput, Synthesis, Turn)
from .service import owned, place, position_data, reading_data, require_idle, run_turn


@extend_schema_view(
    get=extend_schema(responses=ReadingOutput(many=True)),
    post=extend_schema(request=ReadingInput, responses={201: ReadingOutput}, parameters=[IDEMPOTENCY]),
)
class Sessions(generics.GenericAPIView):
    serializer_class = ReadingOutput

    def get(self, request):
        readings = Reading.objects.filter(owner=request.auth.principal).select_related("personality").order_by("-updated_at", "-id")
        page = self.paginate_queryset(readings)
        return self.get_paginated_response([reading_data(reading) for reading in page])

    def post(self, request):
        data = checked(ReadingInput, request.data)
        with transaction.atomic():
            op, fresh = operation(request, "reading:create", data)
            if not fresh:
                return replay(op)
            principal = request.auth.principal
            rate_limit(f"readings:{principal.pk}", 100 if principal.is_verified else 20, 86400)
            personality = get_object_or_404(Personality, slug=data["personality"], enabled=True)
            client_id = data.get("clientSessionId", "")
            if client_id:
                type(principal).objects.select_for_update().get(pk=principal.pk)
                if Reading.objects.filter(owner=principal, client_session_id=client_id).exists():
                    raise Problem("client_session_conflict", 409, "Open the existing reading instead.")
            reading = Reading.objects.create(
                owner=principal, client_session_id=client_id, personality=personality, kind=data["kind"],
                system=data.get("system", ""), spread_id=data.get("spreadId", ""),
                source=data["source"], mode=data["mode"], question=data.get("question", ""),
                notes=data.get("notes", []), subject=data["subject"], astral_context=data.get("astralContext"),
                subject_context=data.get("selfContext" if data["subject"] == "self" else "otherContext", ""),
            )
            Position.objects.bulk_create([
                Position(reading=reading, index=p["position"], role=p["role"], note=p.get("note", ""))
                for p in data.get("positions", [])
            ])
            return finish(op, reading_data(reading, full=True), status.HTTP_201_CREATED)


@extend_schema(methods=["GET"], responses=ReadingOutput)
@extend_schema(methods=["PATCH"], request=ReadingContext, responses=ReadingOutput)
@extend_schema(methods=["DELETE"], responses={204: None})
@api_view(["GET", "PATCH", "DELETE"])
def session(request, session_id):
    if request.method == "GET":
        return Response(reading_data(owned(request, session_id), full=True))
    with transaction.atomic():
        reading = owned(request, session_id, lock=True)
        require_idle(reading)
        if request.method == "PATCH":
            if reading.synthesis or reading.messages.exists():
                raise Problem("context_locked", 409, "The reading has already started its Oracle conversation.")
            data = checked(ReadingContext, request.data)
            subject = data.get("subject", reading.subject)
            key = "selfContext" if subject == "self" else "otherContext"
            reading.subject_context = data.get(key, reading.subject_context if reading.subject == subject else "")
            reading.subject = subject
            reading.question = data.get("question", reading.question)
            reading.notes = data.get("notes", reading.notes)
            reading.save(update_fields=["subject", "subject_context", "question", "notes", "updated_at"])
            return Response(reading_data(reading, full=True))
        # Clear replay records with reading snapshots or generated content as well.
        ops = request.auth.principal.operation_set
        ops.filter(response__sessionId=str(session_id)).delete()
        ops.filter(scope__contains=str(session_id)).delete()
        reading.delete()
    return Response(status=204)


@extend_schema(request=CardUpdate, responses=PositionOutput, parameters=[IDEMPOTENCY])
@api_view(["POST"])
def cards(request, session_id):
    data = checked(CardUpdate, request.data)
    with transaction.atomic():
        reading = owned(request, session_id, lock=True)
        op, fresh = operation(request, f"card:{session_id}", data)
        if not fresh:
            return replay(op)
        if reading.source == "physical" and not (data["clarifier"] and reading.mode == "standard"):
            raise Problem("physical_confirmation_required", 409, "Use the Vision confirmation endpoint.")
        return finish(op, position_data(place(reading, data, source="digital")))


@extend_schema(request=None, responses=Synthesis, parameters=[IDEMPOTENCY])
@api_view(["POST"])
def synthesize(request, session_id):
    return run_turn(request, session_id, "synthesize", {})


@extend_schema(request=MessageInput, responses=Turn, parameters=[IDEMPOTENCY])
@api_view(["POST"])
def messages(request, session_id):
    return run_turn(request, session_id, "messages", checked(MessageInput, request.data))


@extend_schema(request=MessageInput, responses=Turn, parameters=[IDEMPOTENCY])
@api_view(["POST"])
def clarify(request, session_id, position):
    return run_turn(request, session_id, "clarify", checked(MessageInput, request.data), index=position)


@extend_schema(responses=PersonalityOutput(many=True))
@api_view(["GET"])
def personalities(request):
    return Response([
        {"id": p.slug, "name": p.name, "description": p.description}
        for p in Personality.objects.filter(enabled=True).order_by("slug")
    ])


class CompleteInput(serializers.Serializer):
    prompt = serializers.CharField(max_length=16000)
    systemPrompt = serializers.CharField(max_length=4000, required=False, allow_blank=True, default="")
    kind = serializers.ChoiceField(
        ("synthesis", "chat", "clarifier", "astral", "freeform", "guide"),
        required=False,
        default="chat",
    )
    temperature = serializers.FloatField(min_value=0.0, max_value=1.2, required=False, default=0.7)


class QuotaSnapshotSerializer(serializers.Serializer):
    used = serializers.IntegerField()
    limit = serializers.IntegerField()
    remaining = serializers.IntegerField()
    resetAt = serializers.DateTimeField()


class CompleteOutput(serializers.Serializer):
    text = serializers.CharField()
    provider = serializers.CharField()
    quota = QuotaSnapshotSerializer()


class TranscribeInput(serializers.Serializer):
    file = serializers.FileField()
    mimeType = serializers.CharField(max_length=120, required=False, allow_blank=True, default="")


class TranscribeOutput(serializers.Serializer):
    text = serializers.CharField()
    provider = serializers.CharField()
    quota = QuotaSnapshotSerializer()


class QuotaOverviewOutput(serializers.Serializer):
    isPro = serializers.BooleanField()
    oracle = QuotaSnapshotSerializer()
    stt = QuotaSnapshotSerializer()
    vision = QuotaSnapshotSerializer()


@extend_schema(responses=QuotaOverviewOutput)
@api_view(["GET"])
def quota(request):
    """Returns the authenticated user's live server-enforced daily AI quotas."""
    principal = request.auth.principal
    is_pro = principal.has_active_pro
    oracle_limit = settings.ORACLE_PRO_DAILY_LIMIT if is_pro else settings.ORACLE_FREE_DAILY_LIMIT
    stt_limit = settings.STT_PRO_DAILY_LIMIT if is_pro else settings.STT_FREE_DAILY_LIMIT
    vision_limit = 200 if is_pro else 20
    return Response({
        "isPro": is_pro,
        "oracle": quota_peek(f"oracle:{principal.pk}", oracle_limit, 86400),
        "stt": quota_peek(f"stt-day:{principal.pk}", stt_limit, 86400),
        "vision": quota_peek(f"vision-scan-day:{principal.pk}", vision_limit, 86400),
    })


@extend_schema(request=CompleteInput, responses=CompleteOutput)
@api_view(["POST"])
def complete(request):
    """Authenticated server-side Oracle LLM completion proxy with Free/PRO daily quotas."""
    data = checked(CompleteInput, request.data)
    principal = request.auth.principal
    is_pro = principal.has_active_pro
    daily_limit = settings.ORACLE_PRO_DAILY_LIMIT if is_pro else settings.ORACLE_FREE_DAILY_LIMIT
    minute_limit = 40 if is_pro else 12

    rate_limit(f"oracle-min:{principal.pk}", minute_limit, 60)
    quota_info = consume_quota(
        f"oracle:{principal.pk}",
        daily_limit,
        86400,
        code="quota_exceeded",
        detail="Daily Oracle AI quota reached. Upgrade to PRO for expanded daily readings.",
    )
    text, provider_name = complete_oracle_prompt(
        prompt=data["prompt"],
        system_prompt=data.get("systemPrompt") or None,
        temperature=data.get("temperature", 0.7),
    )
    return Response({
        "text": text,
        "provider": provider_name,
        "quota": quota_info,
    })


@extend_schema(request={"multipart/form-data": TranscribeInput}, responses=TranscribeOutput)
@api_view(["POST"])
@parser_classes([MultiPartParser])
def transcribe(request):
    """Authenticated server-side Cloud STT proxy (zero disk persistence, keys off-client)."""
    data = checked(TranscribeInput, {**request.data.dict(), "file": request.FILES.get("file")})
    upload = data["file"]
    if upload.size > settings.STT_MAX_UPLOAD_BYTES:
        raise Problem("request_too_large", 413, "Audio upload exceeds the maximum size.")
    principal = request.auth.principal
    is_pro = principal.has_active_pro
    daily_limit = settings.STT_PRO_DAILY_LIMIT if is_pro else settings.STT_FREE_DAILY_LIMIT
    minute_limit = 30 if is_pro else 10

    rate_limit(f"stt-min:{principal.pk}", minute_limit, 60)
    quota_info = consume_quota(
        f"stt-day:{principal.pk}",
        daily_limit,
        86400,
        code="quota_exceeded",
        detail="Daily voice transcription quota reached.",
    )
    raw_bytes = upload.read(settings.STT_MAX_UPLOAD_BYTES + 1)
    if len(raw_bytes) > settings.STT_MAX_UPLOAD_BYTES:
        raise Problem("request_too_large", 413, "Audio upload exceeds the maximum size.")
    mime = (data.get("mimeType") or getattr(upload, "content_type", "") or "audio/mp4").strip()
    filename = getattr(upload, "name", None) or "voice_note.m4a"
    text, provider_name = transcribe_audio_bytes(raw_bytes, mime_type=mime, filename=filename)
    return Response({
        "text": text,
        "provider": provider_name,
        "quota": quota_info,
    })
