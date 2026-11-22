#!/usr/bin/env python3
"""Move the authored content (cards, runes, zodiac, spreads, lessons) into the
`l10n/*.tsv` dictionaries and rewrite the Dart data files to reference keys.

The script is idempotent: once a field holds a key (`nameKey: '...'`) it is
skipped on the next run. English text is added to `l10n/en.tsv`; the Russian
column of `GuideLine` data seeds `l10n/ru.tsv` (the rest is machine-translated
by `tool/translate_l10n.py`).
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"

STRINGS: dict[str, str] = {}
RU: dict[str, str] = {}


# ── TSV helpers ────────────────────────────────────────────────────────────
def unescape(value: str) -> str:
    return value.replace("\\n", "\n").replace("\\t", "\t").replace("\\\\", "\\")


def escape(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
        .replace("\r", "")
    )


def read_tsv(code: str) -> dict[str, str]:
    path = L10N / f"{code}.tsv"
    entries: dict[str, str] = {}
    if not path.exists():
        return entries
    for raw in path.read_text(encoding="utf-8").splitlines():
        if raw and not raw.startswith("#") and "\t" in raw:
            key, value = raw.split("\t", 1)
            entries[key.strip()] = unescape(value)
    return entries


def write_tsv(code: str, entries: dict[str, str], order: list[str]) -> None:
    path = L10N / f"{code}.tsv"
    lines = ["# key\ttext — edit this file, then run: python3 tool/gen_l10n_dart.py"]
    for key in order:
        if key in entries:
            lines.append(f"{key}\t{escape(entries[key])}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


# ── Mini Dart literal parser ───────────────────────────────────────────────
def skip_space(text: str, i: int) -> int:
    while i < len(text):
        if text[i] in " \t\r\n":
            i += 1
        elif text.startswith("//", i):
            i = text.find("\n", i)
            if i < 0:
                return len(text)
        else:
            break
    return i


def parse_string(text: str, i: int) -> tuple[str, int]:
    """Parse one or more adjacent Dart string literals starting at [i]."""
    parts: list[str] = []
    while True:
        i = skip_space(text, i)
        if i >= len(text) or text[i] not in "'\"":
            break
        quote = text[i]
        i += 1
        buffer: list[str] = []
        while i < len(text):
            char = text[i]
            if char == "\\" and i + 1 < len(text):
                nxt = text[i + 1]
                mapping = {
                    "n": "\n",
                    "t": "\t",
                    "r": "\r",
                    "'": "'",
                    '"': '"',
                    "\\": "\\",
                    "$": "$",
                }
                buffer.append(mapping.get(nxt, nxt))
                i += 2
                continue
            if char == quote:
                i += 1
                break
            buffer.append(char)
            i += 1
        parts.append("".join(buffer))
        # Adjacent literals are concatenated by Dart; continue only when the
        # next non-space character is another quote.
        j = skip_space(text, i)
        if j >= len(text) or text[j] not in "'\"":
            return "".join(parts), i
        i = j


def parse_string_list(text: str, i: int) -> tuple[list[str], int]:
    i = skip_space(text, i)
    assert text[i] == "[", text[i : i + 40]
    i += 1
    values: list[str] = []
    while True:
        i = skip_space(text, i)
        if i < len(text) and text[i] == "]":
            return values, i + 1
        value, i = parse_string(text, i)
        values.append(value)
        i = skip_space(text, i)
        if i < len(text) and text[i] == ",":
            i += 1


def find_field(text: str, name: str) -> tuple[int, int, int] | None:
    """Return (value_start, value_end, colon_index) for `name:` in [text]."""
    match = re.search(rf"\b{re.escape(name)}\s*:", text)
    if not match:
        return None
    return match.end(), match.start(), match.end()


def dart_list(values: list[str]) -> str:
    return "[" + ", ".join("'" + v + "'" for v in values) + "]"


def key_literal(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"



# ── Generic key extraction ─────────────────────────────────────────────────
def add(key: str, text: str, ru: str | None = None) -> None:
    if key in STRINGS and STRINGS[key] != text:
        raise SystemExit(f"duplicate key {key!r}: {STRINGS[key]!r} vs {text!r}")
    STRINGS[key] = text
    if ru:
        RU[key] = ru


def replace_string_field(
    block: str,
    field: str,
    new_field: str,
    key: str,
    ru: str | None = None,
) -> str:
    match = re.search(rf"\b{re.escape(field)}\s*:", block)
    if not match:
        return block
    value, end = parse_string(block, match.end())
    add(key, value, ru)
    return block[: match.start()] + f"{new_field}: {key_literal(key)}" + block[end:]


def replace_list_field(
    block: str,
    field: str,
    new_field: str,
    key_prefix: str,
    ru_values: list[str] | None = None,
) -> str:
    match = re.search(rf"\b{re.escape(field)}\s*:", block)
    if not match:
        return block
    values, end = parse_string_list(block, match.end())
    keys: list[str] = []
    for index, value in enumerate(values):
        key = f"{key_prefix}.{index}"
        add(key, value, ru_values[index] if ru_values and index < len(ru_values) else None)
        keys.append(key)
    return block[: match.start()] + f"{new_field}: {dart_list(keys)}" + block[end:]


def constructor_blocks(src: str, name: str) -> list[tuple[int, int, str]]:
    """All `Name(...)` call spans in [src], declarations excluded."""
    result: list[tuple[int, int, str]] = []
    for match in re.finditer(rf"\b{re.escape(name)}\(", src):
        start = match.start()
        i = match.end()
        depth = 1
        while i < len(src) and depth:
            if src[i] in "'\"":
                _, i = parse_string(src, i)
                continue
            if src[i] == "(":
                depth += 1
            elif src[i] == ")":
                depth -= 1
            i += 1
        block = src[start:i]
        if block[match.end() - start :].lstrip().startswith("{"):
            continue  # constructor declaration
        result.append((start, i, block))
    return result


def rewrite_blocks(src: str, name: str, transform) -> str:
    spans = constructor_blocks(src, name)
    for start, end, block in reversed(spans):
        src = src[:start] + transform(block) + src[end:]
    return src


def named_int(block: str, field: str) -> int:
    match = re.search(rf"\b{field}\s*:\s*(\d+)", block)
    if not match:
        raise SystemExit(f"missing {field} in {block[:80]}")
    return int(match.group(1))


def named_enum(block: str, field: str) -> str:
    match = re.search(rf"\b{field}\s*:\s*([A-Za-z0-9_.]+)", block)
    if not match:
        raise SystemExit(f"missing {field} in {block[:80]}")
    return match.group(1).split(".")[-1]


# ── Tarot ──────────────────────────────────────────────────────────────────
def migrate_tarot(path: pathlib.Path) -> None:
    src = path.read_text(encoding="utf-8")

    def transform(block: str) -> str:
        card_id = named_int(block, "id")
        base = f"content.tarot.{card_id}"
        block = replace_string_field(block, "name", "nameKey", f"{base}.name")
        block = replace_list_field(block, "keywords", "keywordKeys", f"{base}.keyword")
        block = replace_string_field(block, "upright", "uprightKey", f"{base}.upright")
        block = replace_string_field(block, "reversed", "reversedKey", f"{base}.reversed")
        block = replace_string_field(block, "socratic", "socraticKey", f"{base}.socratic")
        return block

    path.write_text(rewrite_blocks(src, "TarotCard", transform), encoding="utf-8")


# ── Lenormand ──────────────────────────────────────────────────────────────
def migrate_lenormand(path: pathlib.Path) -> None:
    src = path.read_text(encoding="utf-8")

    def transform(block: str) -> str:
        number = named_int(block, "number")
        base = f"content.lenormand.{number}"
        block = replace_string_field(block, "name", "nameKey", f"{base}.name")
        block = replace_list_field(block, "keywords", "keywordKeys", f"{base}.keyword")
        block = replace_string_field(block, "meaning", "meaningKey", f"{base}.meaning")
        block = replace_list_field(
            block, "combinations", "combinationKeys", f"{base}.combination"
        )
        block = replace_string_field(block, "timing", "timingKey", f"{base}.timing")
        return block

    path.write_text(rewrite_blocks(src, "LenormandCard", transform), encoding="utf-8")


# ── Runes ──────────────────────────────────────────────────────────────────
def migrate_runes(path: pathlib.Path) -> None:
    src = path.read_text(encoding="utf-8")

    def transform(block: str) -> str:
        stone_id = named_int(block, "id")
        base = f"content.rune.{stone_id}"
        block = replace_string_field(block, "name", "nameKey", f"{base}.name")
        block = replace_list_field(block, "keywords", "keywordKeys", f"{base}.keyword")
        block = replace_string_field(block, "upright", "uprightKey", f"{base}.upright")
        block = replace_string_field(block, "lore", "loreKey", f"{base}.lore")
        match = re.search(r"\bmerkstave\s*:\s*", block)
        if match:
            value, end = parse_string(block, match.end())
            add(f"{base}.merkstave", value)
            block = (
                block[: match.start()]
                + f"merkstaveKey: {key_literal(f'{base}.merkstave')}"
                + block[end:]
            )
        return block

    path.write_text(rewrite_blocks(src, "RuneStone", transform), encoding="utf-8")


# ── Zodiac almanac ─────────────────────────────────────────────────────────
def migrate_zodiac(path: pathlib.Path) -> None:
    src = path.read_text(encoding="utf-8")

    def transform(block: str) -> str:
        sign = named_enum(block, "sign")
        base = f"content.zodiac.{sign}"
        block = replace_string_field(
            block, "dateRange", "dateRangeKey", f"{base}.dateRange"
        )
        block = replace_list_field(block, "keywords", "keywordKeys", f"{base}.keyword")
        block = replace_string_field(
            block, "archetype", "archetypeKey", f"{base}.archetype"
        )
        block = replace_string_field(block, "shadow", "shadowKey", f"{base}.shadow")
        block = replace_string_field(
            block, "loveStyle", "loveStyleKey", f"{base}.loveStyle"
        )
        block = replace_string_field(
            block, "careerVector", "careerVectorKey", f"{base}.careerVector"
        )
        return block

    path.write_text(
        rewrite_blocks(src, "ZodiacSignEntry", transform), encoding="utf-8"
    )


# ── Guided Reading lessons ─────────────────────────────────────────────────
def migrate_lessons(path: pathlib.Path, system: str) -> None:
    src = path.read_text(encoding="utf-8")
    key_events: list[tuple[int, str, bool]] = []
    for match in re.finditer(r"'([A-Za-z0-9_]+)'\s*:\s*(\[|GuideLine\()", src):
        key_events.append((match.start(), match.group(1), match.group(2) == "["))

    spans = constructor_blocks(src, "GuideLine")
    replacements: list[tuple[int, int, str]] = []
    for start, end, block in spans:
        upper = [event for event in key_events if event[0] < start]
        if not upper:
            raise SystemExit(f"{path}: GuideLine without a map key")
        event_start, spread_key, is_list = upper[-1]
        if is_list:
            index = sum(1 for s, _, _ in spans if event_start < s < start)
            key = f"content.lesson.{system}.{spread_key}.{index}"
        else:
            key = f"content.purpose.{system}.{spread_key}"
        en, cursor = parse_string(block, block.index("(") + 1)
        comma = block.find(",", cursor)
        if comma < 0:
            raise SystemExit(f"{path}: GuideLine without a Russian line")
        ru, _ = parse_string(block, comma + 1)
        add(key, en, ru)
        replacements.append((start, end, f"GuideLine({key_literal(key)})"))

    for start, end, replacement in reversed(replacements):
        src = src[:start] + replacement + src[end:]
    path.write_text(src, encoding="utf-8")


# ── Spread enums (positional constructors) ─────────────────────────────────
def migrate_spread_enum(path: pathlib.Path, enum_name: str, system: str) -> None:
    src = path.read_text(encoding="utf-8")
    body_start = src.index(f"enum {enum_name} {{")
    body_end = src.index("\n}", body_start)
    body = src[body_start:body_end]

    entry_re = re.compile(r"^  ([a-zA-Z0-9_]+)\(", re.MULTILINE)
    entries = list(entry_re.finditer(body))
    replacements: list[tuple[int, int, str]] = []

    for index, entry in enumerate(entries):
        start = entry.start()
        block_end = entries[index + 1].start() if index + 1 < len(entries) else len(body)
        block = body[start:block_end]
        paren = block.index("(")
        # Split the positional arguments at top level.
        args: list[tuple[int, int]] = []
        depth = 0
        arg_start = paren + 1
        in_string = False
        quote = ""
        i = paren + 1
        while i < len(block):
            char = block[i]
            if in_string:
                if char == "\\":
                    i += 2
                    continue
                if char == quote:
                    in_string = False
            elif char in "'\"":
                in_string = True
                quote = char
            elif char in "([{":
                depth += 1
            elif char in ")]}":
                if char == ")" and depth == 0:
                    args.append((arg_start, i))
                    break
                depth -= 1
            elif char == "," and depth == 0:
                args.append((arg_start, i))
                arg_start = i + 1
            i += 1

        name = entry.group(1)
        base = f"content.spread.{system}.{name}"

        def arg_text(position: int) -> str:
            return block[args[position][0] : args[position][1]].strip()

        label, _ = parse_string(arg_text(0), 0)
        add(f"{base}.label", label)
        roles, _ = parse_string_list(arg_text(3), 0)
        for slot, role in enumerate(roles):
            add(f"{base}.role.{slot}", role)
        focus, _ = parse_string(arg_text(4), 0)
        add(f"{base}.focus", focus)
        shorts, _ = parse_string_list(arg_text(5), 0)
        for slot, short in enumerate(shorts):
            add(f"{base}.short.{slot}", short)

        new_args = list(args)
        new_args[0] = (0, 0, f"{key_literal(f'{base}.label')}")
        new_args[3] = (
            0,
            0,
            dart_list([f"{base}.role.{i}" for i in range(len(roles))]),
        )
        new_args[4] = (0, 0, key_literal(f"{base}.focus"))
        new_args[5] = (
            0,
            0,
            dart_list([f"{base}.short.{i}" for i in range(len(shorts))]),
        )

        def render(position: int) -> str:
            start_pos, end_pos = args[position]
            original = block[start_pos:end_pos]
            replacement = new_args[position]
            text = replacement[2] if len(replacement) > 2 else original
            leading = original[: len(original) - len(original.lstrip())]
            trailing = original[len(original.rstrip()) :]
            return leading + text + trailing

        rendered = [render(position) for position in range(len(args))]
        block_new = (
            block[: args[0][0]]
            + rendered[0]
            + "".join("," + rendered[i] for i in range(1, len(rendered)))
            + block[args[-1][1] :]
        )
        replacements.append((start, block_end, block_new))

    for start, end, replacement in reversed(replacements):
        body = body[:start] + replacement + body[end:]
    path.write_text(src[:body_start] + body + src[body_end:], encoding="utf-8")




def main() -> int:
    data = ROOT / "lib" / "core" / "data"
    models = ROOT / "lib" / "core" / "models"

    migrate_tarot(data / "tarot_deck_data.dart")
    migrate_lenormand(data / "lenormand_data.dart")
    migrate_runes(data / "runes_data.dart")
    migrate_zodiac(data / "zodiac_almanac_data.dart")
    migrate_lessons(data / "guide_lessons_tarot.dart", "tarot")
    migrate_lessons(data / "guide_lessons_lenormand.dart", "lenormand")
    migrate_lessons(data / "guide_lessons_runes.dart", "runes")
    migrate_spread_enum(models / "spread_type.dart", "SpreadType", "tarot")
    migrate_spread_enum(models / "lenormand_spread.dart", "LenormandSpread", "lenormand")
    migrate_spread_enum(models / "rune_cast.dart", "RuneCast", "runes")

    english = read_tsv("en")
    order = list(english.keys())
    english.update(STRINGS)
    order += [key for key in STRINGS if key not in order]
    write_tsv("en", english, order)

    russian = read_tsv("ru")
    russian.update(RU)
    ru_order = list(russian.keys())
    ru_order += [key for key in RU if key not in ru_order]
    write_tsv("ru", russian, ru_order)

    print(f"content keys: {len(STRINGS)} (ru: {len(RU)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
