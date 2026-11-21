import json
from datetime import timedelta

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone

from apps.ai_gateway.routing import generate
from apps.core.api import Problem, finish, operation, rate_limit, replay
from apps.core.cards import CARDS, validate_card

from .models import Message, Position, Reading
from .serializers import Synthesis

ACTIONS = {"respond", "suggestSpread", "requestNextCard", "requestClarifier",
           "requestReveal", "askQuestion", "summarizeSpread", "completeReading", "none"}


def owned(request, session_id, *, lock=False):
    queryset = Reading.objects.filter(owner=request.auth.principal)
    if lock:
        queryset = queryset.select_for_update()
    return get_object_or_404(queryset, pk=session_id)


def position_data(position):
    return {
        "position": position.index, "role": position.role, "note": position.note,
        "clarifier": position.clarifier, "clarifierQuestion": position.clarifier_question,
        "clarification": position.clarification,
        "card": {
            "cardId": position.card_id, "orientation": position.orientation,
            "source": position.source, "confirmed": True,
        } if position.card_id else None,
    }


def message_data(message):
    result = {"role": message.role, "text": message.text}
    if message.slot_index is not None:
        result["slotIndex"] = message.slot_index
    return result


def reading_data(reading, *, full=False):
    return {
        "sessionId": str(reading.pk), "schemaVersion": 1, "kind": reading.kind,
        "clientSessionId": reading.client_session_id, "system": reading.system or None,
        "source": reading.source, "mode": reading.mode, "spreadId": reading.spread_id,
        "question": reading.question, "subject": reading.subject, "subjectContext": reading.subject_context,
        "notes": reading.notes, "personality": reading.personality.slug,
        "synthesis": reading.synthesis, "astralContext": reading.astral_context,
        "createdAt": reading.created_at.isoformat(), "updatedAt": reading.updated_at.isoformat(),
        "positions": [position_data(position) for position in reading.positions.all()] if full else [],
        "messages": [message_data(message) for message in reading.messages.all()] if full else [],
    }


def require_idle(reading):
    if reading.active_operation_id is None:
        return
    active = reading.active_operation
    if active.created_at > timezone.now() - timedelta(minutes=10):
        raise Problem("reading_busy", 409, "An Oracle turn is in progress.")
    active.response = {"code": "operation_outcome_unknown", "detail": "The original outcome could not be recovered.",
                       "requestId": str(active.pk)}
    active.status_code = 503
    active.save(update_fields=["response", "status_code"])
    reading.active_operation = None
    reading.save(update_fields=["active_operation", "updated_at"])


def place(reading, data, *, source, track=""):
    require_idle(reading)
    if reading.kind != "divinationSpread":
        raise Problem("invalid_reading", 400, "This reading has no cards.")
    validate_card(data["cardId"], reading.system, data["orientation"])
    index = data["position"]
    position = reading.positions.filter(index=index).first()
    if track and reading.positions.filter(track_id=track).exclude(index=index).exists():
        raise Problem("track_already_confirmed", 409, "This track already belongs to another position.")
    if position is None:
        if index != reading.positions.count():
            raise Problem("position_unavailable", 409, "Use the next available position.")
        clarifier = data.get("clarifier", False)
        if clarifier:
            if reading.synthesis is None and reading.mode != "liveOracle":
                raise Problem("synthesis_required", 409, "Synthesize the base reading first.")
            if reading.positions.filter(clarifier=True).count() >= 3:
                raise Problem("clarifier_limit", 409, "The reading already has three clarifiers.")
        elif reading.mode != "liveOracle" or index >= 12 or reading.positions.filter(clarifier=True).exists():
            raise Problem("position_unavailable", 409, "Declare this base position when starting the reading.")
        role = data.get("role", f"Clarifier {reading.positions.filter(clarifier=True).count() + 1}" if clarifier else "")
        if not role:
            raise Problem("position_role_required", 400, "Supply the position role.")
        position = Position(reading=reading, index=index, role=role, clarifier=clarifier)
    if position.clarifier != data.get("clarifier", False):
        raise Problem("position_kind_conflict", 409, "The declared position kind does not match.")
    if position.card_id:
        if (position.card_id, position.orientation, position.source, position.track_id) != (
            data["cardId"], data["orientation"], source, track
        ):
            raise Problem("position_already_filled", 409, "This position is already confirmed.")
        return position
    position.card_id, position.orientation, position.source, position.track_id = (
        data["cardId"], data["orientation"], source, track
    )
    if "note" in data:
        position.note = data["note"]
    position.save()
    reading.save(update_fields=["updated_at"])
    return position


def prompt(reading, turn, text):
    persona = reading.personality
    rules = {"synthesize": "Return JSON containing narrative, elementalAlchemy, verdict and followUp as strings.",
             "messages": "Reply with prose. For Live Oracle you may return JSON with text, action and position.",
             "clarify": "Answer the clarification in prose, connecting it to the original spread."}
    context = {
        "question": reading.question, "subject": reading.subject,
        "subjectContext": reading.subject_context, "notes": reading.notes, "kind": reading.kind,
        "system": reading.system, "mode": reading.mode, "spreadId": reading.spread_id,
        "astralContext": reading.astral_context, "synthesis": reading.synthesis, "request": text,
        "positions": [dict(position_data(p), cardName=CARDS[p.card_id]["name"]) for p in reading.positions.exclude(card_id="")],
    }
    history = list(reading.messages.order_by("-id")[:12])
    messages = [{"role": "system", "content": f"{persona.system_prompt}\n{persona.style}\n{persona.language}\n{rules[turn]}"}]
    messages.extend({"role": "assistant" if m.role == "oracle" else "user", "content": m.text[:3000]}
                    for m in reversed(history))
    messages.append({"role": "user", "content": json.dumps(context, ensure_ascii=False)})
    return messages


def parse_answer(raw, turn, reading):
    if turn == "clarify":
        return {"text": raw, "action": "respond"}
    candidate = raw.strip()
    if candidate.startswith("```") and candidate.endswith("```"):
        candidate = candidate.split("\n", 1)[-1][:-3].strip()
    try:
        data = json.loads(candidate)
    except (ValueError, RecursionError):
        data = None
    if turn == "synthesize":
        output = Synthesis(data=data)
        if not output.is_valid():
            raise Problem("provider_invalid_response", 502, "Oracle returned an invalid synthesis.")
        return dict(output.validated_data)
    if reading.mode == "liveOracle" and isinstance(data, dict) and isinstance(data.get("text"), str):
        action = data.get("action")
        action = action if isinstance(action, str) and action in ACTIONS else "respond"
        result = {"text": data["text"], "action": action}
        index = data.get("position")
        if action in {"requestReveal", "requestNextCard"} and type(index) is int and 0 <= index < 15:
            result["position"] = index
        return result
    return {"text": raw, "action": "respond"}


def run_turn(request, session_id, turn, payload, index=None):
    text = payload.get("text", "")
    scope = f"{turn}:{session_id}" if index is None else f"{turn}:{session_id}:{index}"
    with transaction.atomic():
        reading = owned(request, session_id, lock=True)
        require_idle(reading)
        op, fresh = operation(request, scope, payload)
        if not fresh:
            return replay(op)
        if not reading.personality.enabled:
            raise Problem("personality_unavailable", 503, "This personality is disabled.")
        if turn == "synthesize":
            if reading.synthesis is not None:
                return finish(op, reading.synthesis)
            base = reading.positions.filter(clarifier=False)
            if reading.kind == "divinationSpread" and (not base.exists() or base.filter(card_id="").exists()):
                raise Problem("reading_incomplete", 409, "Reveal or confirm every base position first.")
        if turn == "clarify":
            position = get_object_or_404(reading.positions, index=index, clarifier=True)
            if not position.card_id or position.clarification:
                raise Problem("clarifier_unavailable", 409, "This clarifier is empty or already interpreted.")
        rate_limit(f"oracle:{reading.owner_id}", 100 if request.auth.principal.is_verified else 20, 86400)
        messages = prompt(reading, turn, text)
        reading.active_operation = op
        reading.save(update_fields=["active_operation", "updated_at"])
    try:
        raw, _provider = generate(messages, provider_id=reading.personality.provider_id,
                                  model=reading.personality.model_override or None)
        data = parse_answer(raw, turn, reading)
    except Problem as exc:
        with transaction.atomic():
            current = owned(request, session_id, lock=True)
            if current.active_operation_id == op.pk:
                current.active_operation = None
                current.save(update_fields=["active_operation", "updated_at"])
                return finish(op, {"code": exc.get_codes(), "detail": str(exc.detail),
                                   "requestId": str(op.pk)}, exc.status_code)
        raise Problem("operation_outcome_unknown", 503, "The generation is no longer active.") from None
    with transaction.atomic():
        current = owned(request, session_id, lock=True)
        if current.active_operation_id != op.pk:
            raise Problem("operation_outcome_unknown", 503, "The generation is no longer active.")
        if turn == "synthesize":
            current.synthesis = data
        else:
            if turn == "clarify":
                current.positions.filter(index=index).update(clarification=data["text"], clarifier_question=text)
            Message.objects.bulk_create([
                Message(reading=current, role="user", text=text, slot_index=index),
                Message(reading=current, role="oracle", text=data["text"], slot_index=index),
            ])
        current.active_operation = None
        current.save(update_fields=["active_operation", "synthesis", "updated_at"])
        return finish(op, data)
