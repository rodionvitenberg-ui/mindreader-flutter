#!/usr/bin/env python3
"""Convert `context.astralRussian ? 'RU' : 'EN'` ternaries into dictionary keys.

The ASTRAL surface predates the six-language dictionaries and carries inline
Russian/English pairs. This codemod registers the EN text as the source, keeps
the existing RU text as the Russian translation, and replaces the whole ternary
with `AppStrings.g('key')`.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"
PATTERN = re.compile(
    r"context\.astralRussian\s*\n?\s*\?\s*'((?:\\.|[^'\\])*)'\s*\n?\s*:\s*"
    r"'((?:\\.|[^'\\])*)'"
)


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
    if path.exists():
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


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")[:48] or "text"


def main() -> int:
    english = read_tsv("en")
    russian = read_tsv("ru")
    order = list(english.keys())
    added_en: dict[str, str] = {}
    added_ru: dict[str, str] = {}
    total = 0

    for path in sorted((ROOT / "lib" / "features").rglob("*.dart")):
        source = path.read_text(encoding="utf-8")
        file_slug = path.stem

        def replace(match: re.Match[str]) -> str:
            nonlocal total
            ru = unescape(match.group(1))
            en = unescape(match.group(2))
            base = f"ui.astral_{file_slug}.{slug(en)}"
            key = base
            counter = 2
            while key in english and english[key] != en:
                key = f"{base}.{counter}"
                counter += 1
            if key not in english:
                english[key] = en
                added_en[key] = en
                added_ru[key] = ru
                order.append(key)
            total += 1
            return f"AppStrings.g('{key}')"

        new_source = PATTERN.sub(replace, source)
        if new_source != source:
            if "app_strings.dart" not in new_source:
                import_line = "import '../../../core/l10n/app_strings.dart';"
                depth = len(path.relative_to(ROOT / "lib" / "features").parts) - 1
                import_line = f"import '{'../' * (depth + 1)}core/l10n/app_strings.dart';"
                imports = list(
                    re.finditer(r"^import .*;$", new_source, re.MULTILINE)
                )
                position = imports[-1].end() if imports else 0
                new_source = (
                    new_source[:position]
                    + "\n"
                    + import_line
                    + new_source[position:]
                )
            path.write_text(new_source, encoding="utf-8")

    english.update(added_en)
    write_tsv("en", english, order)
    russian.update(added_ru)
    ru_order = list(russian.keys())
    ru_order += [key for key in added_ru if key not in ru_order]
    write_tsv("ru", russian, ru_order)
    print(f"ternaries replaced: {total}, keys: {len(added_en)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
