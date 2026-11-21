from rest_framework import serializers

from apps.core.cards import supported_id
from apps.oracle.serializers import CardUpdate, PositionOutput


def identifier(value):
    if not supported_id(value):
        raise serializers.ValidationError("Use a stable item or track identifier.")


class Metadata(serializers.Serializer):
    itemId = serializers.CharField(max_length=100, validators=[identifier])
    trackId = serializers.CharField(max_length=100, required=False, validators=[identifier])
    rotationDegrees = serializers.ChoiceField((0, 90, 180, 270), default=0)


class Upload(serializers.Serializer):
    sessionId = serializers.UUIDField()
    images = serializers.ListField(child=serializers.FileField(), max_length=12, allow_empty=False)
    items = serializers.CharField(help_text="JSON array of ordered item metadata matching the images.")
    deckId = serializers.CharField(required=False, max_length=100, validators=[identifier])


class Score(serializers.Serializer):
    type = serializers.ChoiceField(("similarity", "confidence"))
    value = serializers.FloatField()

    def validate(self, attrs):
        import math

        value = attrs["value"]
        if not math.isfinite(value) or (attrs["type"] == "confidence" and not 0 <= value <= 1):
            raise serializers.ValidationError("Invalid score.")
        return attrs


class Candidate(serializers.Serializer):
    cardId = serializers.CharField(max_length=20)
    orientation = serializers.ChoiceField(("upright", "reversed", "unknown"), default="unknown")
    score = Score(required=False, allow_null=True)


class ProviderResult(serializers.Serializer):
    status = serializers.ChoiceField(("recognized", "ambiguous", "unknown"))
    candidates = Candidate(many=True, max_length=8)

    def validate(self, attrs):
        candidates = attrs["candidates"]
        count = len({candidate["cardId"] for candidate in candidates})
        if count != len(candidates) or (attrs["status"] == "recognized" and count != 1):
            raise serializers.ValidationError("Invalid recognition candidates.")
        if attrs["status"] == "unknown" and count:
            raise serializers.ValidationError("Unknown results cannot identify a card.")
        return attrs


class Result(serializers.Serializer):
    requestId = serializers.UUIDField()
    sessionId = serializers.UUIDField()
    itemId = serializers.CharField()
    trackId = serializers.CharField(allow_null=True)
    provider = serializers.CharField(allow_null=True)
    status = serializers.CharField()
    candidates = Candidate(many=True)
    requiresConfirmation = serializers.BooleanField()
    decision = serializers.CharField(allow_null=True)


class BatchOutput(serializers.Serializer):
    results = Result(many=True)
    error = serializers.CharField(required=False)


class Decision(CardUpdate):
    sessionId = serializers.UUIDField()
    requestId = serializers.UUIDField(required=False)
    action = serializers.ChoiceField(("confirm", "reject", "correct", "manual"))
    position = serializers.IntegerField(min_value=0, max_value=14, required=False)
    cardId = serializers.CharField(max_length=20, required=False)
    orientation = serializers.ChoiceField(("upright", "reversed"), required=False)

    def validate(self, attrs):
        action = attrs["action"]
        if ("requestId" in attrs) != (action != "manual"):
            raise serializers.ValidationError("Provide a recognition request for confirm, correct or reject.")
        needed = {"reject": (), "confirm": ("position",),
                  "correct": ("position", "cardId", "orientation"),
                  "manual": ("position", "cardId", "orientation")}[action]
        if any(field not in attrs for field in needed):
            raise serializers.ValidationError("This decision requires a position, card or orientation.")
        return attrs


class DecisionOutput(serializers.Serializer):
    decision = serializers.CharField()
    position = PositionOutput(allow_null=True)
