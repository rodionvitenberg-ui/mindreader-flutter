#!/usr/bin/env python3
"""Deterministic asset mapper: TarotCards/tarot/<deck>/720px/* -> assets/decks/<deck_id>/NN.jpg

Maps every card of the 7 open-source decks onto the app's internal 0-77 ids
(Majors 00-21, Wands 22-35, Cups 36-49, Swords 50-63, Pentacles 64-77),
re-encoding to RGB JPEG (max width 520px, quality 86) so the APK stays light.

Per-deck resolver rules:
  - rider_waite / soimoi / visconti_sforza: RWS filename prefix == internal id;
    missing scans (Visconti Devil/Tower, a few minors) simply fall back to the
    procedural face in the app.
  - marseille / vieville: French majors with HISTORICAL numbering
    (VIII Justice, XI Strength) -> remapped by canonical name so the artwork
    always matches the app's RWS-ordered card title.
  - oswald_wirth: majors only (22 cards).
  - etteilla: own divinatory numbering 1-78 -> positional mapping NN -> NN-1;
    cards 49/63/78 are missing on Wikimedia Commons (procedural fallback).
  - Cover.jpg -> back.jpg (real card back) where present.

Idempotent: re-running overwrites the same outputs. Never touches
TarotCards/scripts/ (sola-busca, tarot-nouveau are strictly excluded).
"""

import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "TarotCards", "tarot")
DST = os.path.join(ROOT, "assets", "decks")

MAX_WIDTH = 450
JPEG_QUALITY = 80

SUIT_BASE = {"Wands": 22, "Cups": 36, "Swords": 50, "Pents": 64}

# French major-arcana names -> internal RWS id (handles historical ordering).
FRENCH_MAJORS = {
    "Le_Mat": 0,
    "Le_Bateleur": 1,
    "La_Papesse": 2,
    "L_Imperatrice": 3,
    "L_Empereur": 4,
    "Le_Pape": 5,
    "L_Amoureux": 6,
    "Le_Chariot": 7,
    "La_Justice": 11,
    "L_Ermite": 9,
    "La_Roue_de_Fortune": 10,
    "La_Force": 8,
    "Le_Pendu": 12,
    "La_Mort": 13,
    "Temperance": 14,
    "Le_Diable": 15,
    "La_Maison_Dieu": 16,
    "L_Etoile": 17,
    "La_Lune": 18,
    "Le_Soleil": 19,
    "Le_Jugement": 20,
    "Le_Monde": 21,
}


def _split_prefix(name: str):
    """'07_Le_Chariot.jpg' -> (7, 'Le_Chariot') or None."""
    try:
        num, rest = name.split("_", 1)
        return int(num), rest
    except ValueError:
        return None


def resolve(deck: str, filename: str):
    """Internal card id for a 720px source file, or None (cover/misc)."""
    stem, ext = os.path.splitext(filename)
    parts = _split_prefix(stem)
    if parts is None:
        # RWS-style minors carry no numeric prefix: Wands01, Cups01, ...
        for suit, base in SUIT_BASE.items():
            if stem.startswith(suit):
                return base + int(stem[len(suit):]) - 1
        return None
    num, rest = parts

    if deck in ("rider-waite", "soimoi", "visconti-sforza"):
        if num <= 21:
            return num
        for suit, base in SUIT_BASE.items():
            if rest.startswith(suit):
                return base + int(rest[len(suit):]) - 1
        return None

    if deck == "oswald-wirth":
        return num if num <= 21 else None

    if deck in ("marseille", "vieville"):
        if num <= 21:
            return FRENCH_MAJORS.get(rest, num)
        for suit, base in SUIT_BASE.items():
            if rest.startswith(suit):
                return base + int(rest[len(suit):]) - 1
        return None

    if deck == "etteilla":
        # Own divinatory numbering 1-78 -> positional slot NN-1.
        return num - 1 if 1 <= num <= 78 else None

    return None


def process(deck: str, deck_id: str):
    src_dir = os.path.join(SRC, deck, "720px")
    dst_dir = os.path.join(DST, deck_id)
    os.makedirs(dst_dir, exist_ok=True)
    mapped = {}
    cover = None
    for filename in sorted(os.listdir(src_dir)):
        path = os.path.join(src_dir, filename)
        if not os.path.isfile(path):
            continue
        stem, ext = os.path.splitext(filename)
        if stem in ("Cover", "Cover_Rare"):
            cover = path
            continue
        card_id = resolve(deck, filename)
        if card_id is None or not (0 <= card_id <= 77):
            continue
        out = os.path.join(dst_dir, f"{card_id:02d}.jpg")
        with Image.open(path) as im:
            im = im.convert("RGB")
            if im.width > MAX_WIDTH:
                h = round(im.height * MAX_WIDTH / im.width)
                im = im.resize((MAX_WIDTH, h), Image.LANCZOS)
            im.save(out, "JPEG", quality=JPEG_QUALITY, optimize=True)
        mapped[card_id] = filename
    if cover is not None:
        out = os.path.join(dst_dir, "back.jpg")
        with Image.open(cover) as im:
            im = im.convert("RGB")
            if im.width > MAX_WIDTH:
                h = round(im.height * MAX_WIDTH / im.width)
                im = im.resize((MAX_WIDTH, h), Image.LANCZOS)
            im.save(out, "JPEG", quality=JPEG_QUALITY, optimize=True)
    missing = sorted(set(range(78)) - set(mapped))
    print(f"[{deck_id:16s}] {len(mapped):2d}/78 cards, "
          f"missing ids: {missing or '-'}")
    return mapped


def main():
    decks = [
        ("rider-waite", "rider_waite"),
        ("marseille", "marseille"),
        ("oswald-wirth", "oswald_wirth"),
        ("etteilla", "etteilla"),
        ("visconti-sforza", "visconti_sforza"),
        ("vieville", "vieville"),
        ("soimoi", "soimoi"),
    ]
    for deck, deck_id in decks:
        process(deck, deck_id)


if __name__ == "__main__":
    sys.exit(main())
