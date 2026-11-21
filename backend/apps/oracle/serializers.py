from rest_framework import serializers

from apps.core.cards import ORIENTATIONS, SYSTEM_SIZES

KINDS = ("divinationSpread", "natalChartReading", "synastryReading", "horoscopeReading", "zodiacReading")


class AstralContext(serializers.Serializer):
    schemaVersion = serializers.ChoiceField([1])
    summary = serializers.CharField(max_length=4000)


class BasePosition(serializers.Serializer):
    position = serializers.IntegerField(min_value=0, max_value=11)
    role = serializers.CharField(max_length=500)
    note = serializers.CharField(max_length=2000, required=False, allow_blank=True)


class ReadingInput(serializers.Serializer):
    schemaVersion = serializers.ChoiceField([1], default=1)
    clientSessionId = serializers.CharField(max_length=128, required=False, allow_blank=True)
    kind = serializers.ChoiceField(KINDS, default="divinationSpread")
    system = serializers.ChoiceField(SYSTEM_SIZES, required=False)
    source = serializers.ChoiceField(("digital", "physical"), default="digital")
    mode = serializers.ChoiceField(("standard", "quickScan", "guidedSpread", "liveOracle"), default="standard")
    spreadId = serializers.CharField(max_length=64, required=False, allow_blank=True)
    positions = BasePosition(many=True, max_length=12, required=False)
    question = serializers.CharField(max_length=2000, required=False, allow_blank=True)
    notes = serializers.ListField(child=serializers.CharField(max_length=500), max_length=12, required=False)
    subject = serializers.ChoiceField(("self", "other"), default="self")
    selfContext = serializers.CharField(max_length=2000, required=False, allow_blank=True)
    otherContext = serializers.CharField(max_length=2000, required=False, allow_blank=True)
    astralContext = AstralContext(required=False)
    personality = serializers.SlugField(default="default")

    def validate(self, attrs):
        positions = attrs.get("positions", [])
        if attrs["kind"] == "divinationSpread":
            if not attrs.get("system") or attrs.get("astralContext"):
                raise serializers.ValidationError("A card reading requires a divination system.")
            if not positions and attrs["mode"] != "liveOracle":
                raise serializers.ValidationError("Declare the base positions before starting the reading.")
            if [p["position"] for p in positions] != list(range(len(positions))):
                raise serializers.ValidationError("Positions must be contiguous and in zero-based order.")
        elif positions or attrs.get("system") or attrs.get("spreadId") or not attrs.get("astralContext"):
            raise serializers.ValidationError("An Astral reading requires only its own context.")
        return attrs


class CardInput(serializers.Serializer):
    cardId = serializers.CharField(max_length=20)
    orientation = serializers.ChoiceField(ORIENTATIONS)


class CardUpdate(CardInput):
    position = serializers.IntegerField(min_value=0, max_value=14)
    role = serializers.CharField(max_length=500, required=False)
    note = serializers.CharField(max_length=2000, required=False, allow_blank=True)
    clarifier = serializers.BooleanField(default=False)


class CardOutput(CardInput):
    source = serializers.ChoiceField(("digital", "physical"))
    confirmed = serializers.BooleanField()


class PositionOutput(BasePosition):
    position = serializers.IntegerField(min_value=0, max_value=14)
    card = CardOutput(allow_null=True)
    clarifier = serializers.BooleanField()
    clarification = serializers.CharField(allow_blank=True)


class MessageInput(serializers.Serializer):
    text = serializers.CharField(max_length=2000)


class MessageOutput(serializers.Serializer):
    role = serializers.ChoiceField(("user", "oracle", "system"))
    text = serializers.CharField()
    slotIndex = serializers.IntegerField(required=False)


class Synthesis(serializers.Serializer):
    narrative = serializers.CharField(max_length=5000)
    elementalAlchemy = serializers.CharField(max_length=3000)
    verdict = serializers.CharField(max_length=3000)
    followUp = serializers.CharField(max_length=2000)


class ReadingOutput(serializers.Serializer):
    sessionId = serializers.UUIDField()
    clientSessionId = serializers.CharField(allow_blank=True)
    schemaVersion = serializers.IntegerField()
    kind = serializers.CharField()
    system = serializers.CharField(allow_null=True)
    source = serializers.CharField()
    mode = serializers.CharField()
    spreadId = serializers.CharField(allow_blank=True)
    question = serializers.CharField(allow_blank=True)
    subject = serializers.CharField()
    subjectContext = serializers.CharField(allow_blank=True)
    notes = serializers.ListField(child=serializers.CharField())
    positions = PositionOutput(many=True)
    messages = MessageOutput(many=True)
    synthesis = Synthesis(allow_null=True)
    astralContext = AstralContext(allow_null=True)
    personality = serializers.SlugField()
    createdAt = serializers.DateTimeField()
    updatedAt = serializers.DateTimeField()


class Turn(serializers.Serializer):
    text = serializers.CharField()
    action = serializers.CharField()
    position = serializers.IntegerField(required=False)


class PersonalityOutput(serializers.Serializer):
    id = serializers.SlugField()
    name = serializers.CharField()
    description = serializers.CharField()
