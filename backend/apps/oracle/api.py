from django.db import transaction
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import generics, status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from apps.core.api import Problem, checked, finish, operation, rate_limit, replay

from .models import Personality, Position, Reading
from .serializers import (CardUpdate, MessageInput, PersonalityOutput, PositionOutput,
                          ReadingInput, ReadingOutput, Synthesis, Turn)
from .service import owned, place, position_data, reading_data, require_idle, run_turn

IDEMPOTENCY = OpenApiParameter("Idempotency-Key", str, OpenApiParameter.HEADER, required=True)


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


@extend_schema(responses={200: ReadingOutput, 204: None})
@api_view(["GET", "DELETE"])
def session(request, session_id):
    if request.method == "GET":
        return Response(reading_data(owned(request, session_id), full=True))
    with transaction.atomic():
        reading = owned(request, session_id, lock=True)
        require_idle(reading)
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
