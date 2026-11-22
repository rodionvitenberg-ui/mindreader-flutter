#!/usr/bin/env python3
"""Generate the Dart dictionaries from the per-language `l10n/*.tsv` files.

The TSV files in `l10n/` are the single source of truth for every piece of
user-visible copy.  One file per language, one `key<TAB>text` line per string.
Edit those files and run:

    python3 tool/gen_l10n_dart.py

The script writes `lib/core/l10n/strings/strings_<code>.dart` (const maps) and
fails loudly when a key present in `en.tsv` is missing from another language,
so a forgotten translation can never silently ship as an empty label.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"
OUT = ROOT / "lib" / "core" / "l10n" / "strings"

# Order matters only for the generated file; the first one is the source.
LANGUAGES = ["en", "ru", "es", "pt", "de", "fr"]
DART_CLASS = {
    "en": "StringsEn",
    "ru": "StringsRu",
    "es": "StringsEs",
    "pt": "StringsPt",
    "de": "StringsDe",
    "fr": "StringsFr",
}


def unescape(value: str) -> str:
    return (
        value.replace("\\n", "\n")
        .replace("\\t", "\t")
        .replace("\\\\", "\\")
    )


def read_tsv(code: str) -> dict[str, str]:
    path = L10N / f"{code}.tsv"
    entries: dict[str, str] = {}
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw or raw.startswith("#"):
            continue
        if "\t" not in raw:
            raise SystemExit(f"{path}:{lineno}: expected `key<TAB>text`")
        key, value = raw.split("\t", 1)
        key = key.strip()
        if not key:
            raise SystemExit(f"{path}:{lineno}: empty key")
        if key in entries:
            raise SystemExit(f"{path}:{lineno}: duplicate key {key!r}")
        entries[key] = unescape(value)
    return entries


def dart_literal(value: str) -> str:
    escaped = (
        value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", "\\$")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
        .replace("\r", "")
    )
    return f"'{escaped}'"


def main() -> int:
    dictionaries = {code: read_tsv(code) for code in LANGUAGES}
    english = dictionaries["en"]

    missing: list[str] = []
    for code in LANGUAGES[1:]:
        for key in english:
            if key not in dictionaries[code]:
                missing.append(f"{code}: {key}")
    if missing:
        print("\n".join(missing[:50]))
        raise SystemExit(f"{len(missing)} missing translation(s) — add them to l10n/*.tsv")

    OUT.mkdir(parents=True, exist_ok=True)
    for code in LANGUAGES:
        entries = dictionaries[code]
        lines = [
            "// GENERATED FILE — do not edit by hand.",
            "// Source: l10n/" + code + ".tsv (run: python3 tool/gen_l10n_dart.py)",
            "",
            "/// Every user-visible string in " + code.upper() + ".",
            "const Map<String, String> strings" + code.capitalize() + " = {",
        ]
        for key in english:
            lines.append(f"  {dart_literal(key)}: {dart_literal(entries[key])},")
        lines.append("};")
        lines.append("")
        (OUT / f"strings_{code}.dart").write_text(
            "\n".join(lines), encoding="utf-8"
        )

    print(f"Generated {len(LANGUAGES)} dictionaries, {len(english)} keys each.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
