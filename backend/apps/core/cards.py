import json
import re
from pathlib import Path

from rest_framework import serializers

SYSTEM_SIZES = {"tarot": 78, "lenormand": 36, "runes": 24}
CARDS = json.loads(Path(__file__).with_name("canonical_cards.json").read_text(encoding="utf-8"))
ORIENTATIONS = ("upright", "reversed")


def validate_card(card_id, system, orientation=None):
    if card_id not in CARDS or card_id.split(":")[0] != system:
        raise serializers.ValidationError({"cardId": "Expected a canonical ID for this system."})
    if orientation == "reversed" and not CARDS[card_id]["reversible"]:
        raise serializers.ValidationError({"orientation": "This card is always upright."})


def supported_id(text):
    return bool(re.fullmatch(r"[A-Za-z0-9_.:-]{1,100}", text))
