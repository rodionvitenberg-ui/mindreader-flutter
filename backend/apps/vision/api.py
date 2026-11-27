import hashlib
import json

from django.db import transaction
from django.shortcuts import get_object_or_404
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response

from apps.ai_gateway.routing import recognize as route_vision
from apps.core.api import IDEMPOTENCY, Problem, checked, finish, operation, rate_limit, replay
from apps.core.cards import validate_card
from apps.oracle.service import owned, place, position_data, require_idle

from .images import MAX_BATCH_BYTES, normalize_image
from .models import Recognition
from .serializers import BatchOutput, Decision, DecisionOutput, Metadata, ProviderResult, Result, Upload
from .vlm_service import recognize_spread_with_vlm


def result_data(row):
    return {
        "requestId": str(row.pk), "sessionId": str(row.reading_id), "itemId": row.item_id,
        "trackId": row.track_id or None, "provider": row.provider or None, "status": row.status,
        "candidates": row.candidates, "requiresConfirmation": not row.decision and row.status in {"recognized", "ambiguous"},
        "decision": row.decision or None,
    }


def process_upload(request, *, single):
    form = request.data
    if getattr(request, "vision_upload_too_large", False):
        raise Problem("request_too_large", 413, "Request exceeds the upload limit.")
    data = checked(Upload, {**form.dict(), "images": request.FILES.getlist("images")})
    files = data["images"]
    if (single and len(files) != 1) or sum(image.size for image in files) > MAX_BATCH_BYTES:
        raise serializers.ValidationError({"images": "Invalid image count or total upload exceeds 20 MiB."})
    reading = owned(request, data["sessionId"])
    if reading.kind != "divinationSpread":
        raise Problem("invalid_reading", 400, "This reading has no cards.")
    try:
        raw_items = json.loads(data["items"])
    except (ValueError, RecursionError):
        raise serializers.ValidationError({"items": "Expected JSON metadata."}) from None
    if not isinstance(raw_items, list) or len(raw_items) != len(files):
        raise serializers.ValidationError({"items": "Supply one metadata entry per image."})
    items = [checked(Metadata, item) for item in raw_items]
    tracks = [item["trackId"] for item in items if "trackId" in item]
    if len({item["itemId"] for item in items}) != len(items) or len(set(tracks)) != len(tracks):
        raise serializers.ValidationError({"items": "Item and track identifiers must be unique in a batch."})

    payload = {"items": items, "deckId": data.get("deckId")}
    with transaction.atomic():
        rate_limit(f"vision-upload:{reading.owner_id}", 16 if request.auth.principal.is_verified else 6, 60)
    inputs = []
    for image, item in zip(files, items):
        pixels = normalize_image(image, item["rotationDegrees"])
        inputs.append({"itemId": item["itemId"], "mimeType": "image/jpeg", "bytes": pixels})
    payload["imageHashes"] = [hashlib.sha256(item["bytes"]).hexdigest() for item in inputs]
    with transaction.atomic():
        reading = owned(request, reading.pk, lock=True)
        op, fresh = operation(request, f"vision:{reading.pk}", payload)
        if not fresh:
            return replay(op)
        rate_limit(f"vision:{reading.owner_id}", 100 if request.auth.principal.is_verified else 20, 86400)
        rows = Recognition.objects.bulk_create([
            Recognition(reading=reading, item_id=item["itemId"], track_id=item.get("trackId", ""))
            for item in items
        ])

    error = None
    try:
        output, provider = route_vision(inputs, system=reading.system, deck_id=data.get("deckId"))
        validated = [checked(ProviderResult, output[row.item_id]) for row in rows]
        for item in validated:
            for candidate in item["candidates"]:
                validate_card(candidate["cardId"], reading.system, candidate["orientation"])
        for row, item in zip(rows, validated):
            row.status, row.candidates, row.provider = item["status"], item["candidates"], provider
    except (Problem, serializers.ValidationError) as exc:
        error = exc.get_codes() if isinstance(exc, Problem) else "provider_invalid_response"
        for row in rows:
            row.status = "unavailable" if error in {"provider_unavailable", "provider_busy", "provider_quota_exhausted"} else "error"
    with transaction.atomic():
        owned(request, reading.pk, lock=True)
        Recognition.objects.bulk_update(rows, ["status", "candidates", "provider"])
        response = {"results": [result_data(row) for row in rows]}
        if error:
            response["error"] = error
        return finish(op, response)


@extend_schema(request={"multipart/form-data": Upload}, responses=BatchOutput, parameters=[IDEMPOTENCY])
@api_view(["POST"])
@parser_classes([MultiPartParser])
def recognize(request):
    return process_upload(request, single=True)


@extend_schema(request={"multipart/form-data": Upload}, responses=BatchOutput, parameters=[IDEMPOTENCY])
@api_view(["POST"])
@parser_classes([MultiPartParser])
def recognize_batch(request):
    return process_upload(request, single=False)


@extend_schema(responses=Result)
@api_view(["GET"])
def result(request, request_id):
    return Response(result_data(get_object_or_404(
        Recognition, pk=request_id, reading__owner=request.auth.principal,
    )))


@extend_schema(request=Decision, responses=DecisionOutput, parameters=[IDEMPOTENCY])
@api_view(["POST"])
def confirm(request):
    data = checked(Decision, request.data)
    with transaction.atomic():
        reading = owned(request, data["sessionId"], lock=True)
        op, fresh = operation(request, f"confirm:{reading.pk}", data)
        if not fresh:
            return replay(op)
        require_idle(reading)
        action = data["action"]
        row = (
            get_object_or_404(Recognition.objects.select_for_update(), pk=data["requestId"], reading=reading)
            if "requestId" in data else None
        )
        if row and (row.decision or row.status == "recognizing"):
            raise Problem("decision_unavailable", 409, "This recognition is not awaiting a decision.")
        if action == "confirm":
            match = next((c for c in row.candidates if c["cardId"] == data.get("cardId")), None)
            if match is None and "cardId" not in data and len(row.candidates) == 1:
                match = row.candidates[0]
            if match is None:
                raise Problem("candidate_required", 400, "Choose a candidate or send a correction.")
            data["cardId"] = match["cardId"]
            data.setdefault("orientation", match["orientation"])
            if data["orientation"] == "unknown":
                raise Problem("orientation_required", 400, "Choose the orientation.")
        position = None if action == "reject" else place(
            reading, data, source="physical", track=row.track_id if row else "",
        )
        if row:
            row.decision, row.confirmed_position = action, position
            row.save(update_fields=["decision", "confirmed_position"])
        return finish(op, {"decision": action, "position": position_data(position) if position else None})


class ScanSpreadInput(serializers.Serializer):
    image = serializers.FileField()
    mode = serializers.ChoiceField(
        ("quick_scan", "guided_single", "live_oracle"),
        default="quick_scan",
    )
    expectedCount = serializers.IntegerField(min_value=1, max_value=12, required=False, allow_null=True)
    rotationDegrees = serializers.ChoiceField((0, 90, 180, 270), default=0)


@extend_schema(request={"multipart/form-data": ScanSpreadInput}, responses={200: OpenApiTypes.OBJECT})
@api_view(["POST"])
@parser_classes([MultiPartParser])
def scan_spread(request):
    """End-to-end physical spread scanner: enginetaro crops (reading order) -> Cloud VLM."""
    if getattr(request, "vision_upload_too_large", False):
        raise Problem("request_too_large", 413, "Request exceeds the upload limit.")
    data = checked(ScanSpreadInput, {**request.data.dict(), "image": request.FILES.get("image")})
    principal = request.auth.principal
    with transaction.atomic():
        rate_limit(f"vision-scan-min:{principal.pk}", 20 if principal.has_active_pro else 8, 60)
        rate_limit(f"vision-scan-day:{principal.pk}", 200 if principal.has_active_pro else 20, 86400)

    jpeg = normalize_image(data["image"], data["rotationDegrees"])
    scan = recognize_spread_with_vlm(
        jpeg,
        mode=data["mode"],
        expected_count=data.get("expectedCount"),
    )
    return Response(
        {
            "mode": scan.mode,
            "strategy": scan.strategy,
            "provider": scan.provider,
            "cropCount": scan.crop_count,
            "cards": [
                {
                    "index": c.index,
                    "cardId": c.card_id,
                    "deckIndex": c.deck_index,
                    "name": c.name,
                    "reversed": c.orientation == "reversed",
                    "orientation": c.orientation,
                    "confidence": c.confidence,
                    "centerNorm": c.center_norm,
                    "isLandscape": c.is_landscape,
                }
                for c in scan.cards
            ],
            "warnings": scan.warnings,
        },
        status=200,
    )
