"""Canonical Tarot card matcher for noisy VLM names, deck synonyms, and Roman numerals."""

from __future__ import annotations

import re
from dataclasses import dataclass

from apps.core.cards import CARDS


@dataclass(frozen=True)
class MatchedCard:
    card_id: str      # e.g. "tarot:17"
    deck_index: int   # 0..77 (matches Flutter tarotDeck index)
    name: str         # Canonical English name, e.g. "The Star"


_SUIT_ALIASES = {
    "coins": "pentacles",
    "coin": "pentacles",
    "disks": "pentacles",
    "disk": "pentacles",
    "discs": "pentacles",
    "deniers": "pentacles",
    "pentacle": "pentacles",
    "rods": "wands",
    "rod": "wands",
    "staves": "wands",
    "staff": "wands",
    "batons": "wands",
    "clubs": "wands",
    "wand": "wands",
    "chalices": "cups",
    "chalice": "cups",
    "goblets": "cups",
    "cup": "cups",
    "blades": "swords",
    "sword": "swords",
}

_RANK_ALIASES = {
    "1": "ace",
    "2": "two",
    "3": "three",
    "4": "four",
    "5": "five",
    "6": "six",
    "7": "seven",
    "8": "eight",
    "9": "nine",
    "10": "ten",
    "knave": "page",
    "princess": "page",
    "valet": "page",
    "prince": "knight",
    "cavalier": "knight",
}

_LEADING_NUMERAL_RE = re.compile(r"^(?:0|[ivxlcdm]{1,6}|\d{1,2})\s*[-.:)]*\s+", re.IGNORECASE)
_NON_ALNUM_RE = re.compile(r"[^a-z0-9\s]+")
_SPACES_RE = re.compile(r"\s+")


def _normalize(text: str) -> str:
    s = (text or "").strip().lower()
    s = _NON_ALNUM_RE.sub(" ", s)
    s = _SPACES_RE.sub(" ", s).strip()
    if s.startswith("the "):
        s = s[4:].strip()
    return s


def _build_lookup() -> tuple[dict[str, MatchedCard], dict[str, MatchedCard]]:
    by_id: dict[str, MatchedCard] = {}
    by_norm: dict[str, MatchedCard] = {}
    for card_id, meta in CARDS.items():
        if not card_id.startswith("tarot:"):
            continue
        idx = int(card_id.split(":")[1])
        mc = MatchedCard(card_id=card_id, deck_index=idx, name=meta["name"])
        by_id[card_id] = mc
        norm = _normalize(meta["name"])
        by_norm[norm] = mc
        by_norm[f"the {norm}"] = mc
    # Common Rider-Waite / Marseille / Thoth spelling variants
    extra = {
        "fool": "tarot:0",
        "juggler": "tarot:1",
        "popess": "tarot:2",
        "pope": "tarot:5",
        "fortitude": "tarot:8",
        "lust": "tarot:8",
        "wheel": "tarot:10",
        "fortune": "tarot:10",
        "adjustment": "tarot:11",
        "hanged": "tarot:12",
        "art": "tarot:14",
        "house of god": "tarot:16",
        "judgement": "tarot:20",
        "judgment": "tarot:20",
        "aeon": "tarot:20",
        "universe": "tarot:21",
    }
    for alias, cid in extra.items():
        if cid in by_id:
            by_norm[alias] = by_id[cid]
    return by_id, by_norm


_BY_ID, _BY_NORM = _build_lookup()


def canonical_tarot_prompt_catalog() -> str:
    """Compact canonical list of all 78 Tarot IDs + names for the VLM prompt."""
    ordered = sorted(_BY_ID.values(), key=lambda m: m.deck_index)
    return ", ".join(f"{m.card_id}={m.name}" for m in ordered)


def match_tarot_card(
    *,
    card_id: str | None = None,
    name: str | None = None,
) -> MatchedCard | None:
    """Resolves a VLM-provided cardId or card name to a canonical Tarot card, or None."""
    if isinstance(card_id, str):
        cid = card_id.strip().lower()
        if cid in _BY_ID:
            return _BY_ID[cid]
        if cid.isdigit() and f"tarot:{int(cid)}" in _BY_ID:
            return _BY_ID[f"tarot:{int(cid)}"]

    if not isinstance(name, str) or not name.strip():
        return None

    raw = name.strip()
    candidates = [raw, _LEADING_NUMERAL_RE.sub("", raw)]
    for cand in candidates:
        norm = _normalize(cand)
        if not norm:
            continue
        if norm in _BY_NORM:
            return _BY_NORM[norm]
        # Replace deck suit & rank synonyms (e.g. "Knave of Coins" -> "page of pentacles")
        words = [_RANK_ALIASES.get(w, _SUIT_ALIASES.get(w, w)) for w in norm.split()]
        rebuilt = " ".join(words)
        if rebuilt in _BY_NORM:
            return _BY_NORM[rebuilt]
        # Handle inverted minor format like "pentacles 3" or "cups queen"
        if len(words) == 2:
            swapped = f"{words[1]} of {words[0]}"
            if swapped in _BY_NORM:
                return _BY_NORM[swapped]
            direct = f"{words[0]} of {words[1]}"
            if direct in _BY_NORM:
                return _BY_NORM[direct]
    return None
