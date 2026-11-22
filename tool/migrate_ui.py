#!/usr/bin/env python3
"""Codemod: replace plain UI string literals with `AppStrings.g('key')`.

Dry-run first (`--dry-run`) prints every match. The codemod is deliberately
conservative: it only touches literals used in obvious display positions
(`Text('…')`, `label: '…'`, `tooltip: '…'`, …), skips interpolated strings
(handled by hand), keys, ids, asset paths and log messages, and registers each
new key in `l10n/en.tsv`.
"""

from __future__ import annotations

import argparse
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"
UI_ROOTS = [
    ROOT / "lib" / "features",
    ROOT / "lib" / "design_system" / "components",
    ROOT / "lib" / "main.dart",
]
SKIP_FILES = {
    ROOT / "lib" / "design_system" / "playground" / "glass_playground.dart",
    ROOT / "lib" / "design_system" / "playground" / "playground_main.dart",
}
SPECIAL_STRINGS = re.compile(
    r"(assets/|https?://|package:|dart:|^[a-z0-9_.:\\-]+$|^[A-Z0-9_]+$)"
)
TEXT_PATTERN = re.compile(r"\bText\(\s*'((?:\\.|[^'\\$])*)'\s*([,)])")
FIELD_PATTERN = re.compile(
    r"\b(label|title|subtitle|tooltip|hintText|labelText|helperText|"
    r"errorText|semanticLabel|placeholder|message|description|question|text)"
    r":\s*'((?:\\.|[^'\\$])*)'"
)
TERNARY_PATTERN = re.compile(
    r"\?\s*'((?:\\.|[^'\\$])*)'\s*:\s*'((?:\\.|[^'\\$])*)'"
)
ARROW_PATTERN = re.compile(r"=>\s*'((?:\\.|[^'\\$])*)'")
LIST_ITEM_PATTERN = re.compile(r"^(\s*)'((?:\\.|[^'\\$])*)'(,)\s*$", re.MULTILINE)
KEY_LIKE = re.compile(r"^[a-z][a-z0-9]*(\.[a-z0-9_]+)+$")


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
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "_", text).strip("_")
    return text[:48] or "text"


def relative_import(path: pathlib.Path) -> str:
    target = ROOT / "lib" / "core" / "l10n" / "app_strings.dart"
    rel = pathlib.Path(os.path.relpath(target, path.parent)).as_posix()
    return f"import '{rel}';"



def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    english = read_tsv("en")
    order = list(english.keys())
    added: dict[str, str] = {}
    used_keys = set(english)
    matches_total = 0

    files: list[pathlib.Path] = []
    for root in UI_ROOTS:
        if root.is_file():
            files.append(root)
        else:
            files.extend(sorted(root.rglob("*.dart")))
    files = [f for f in files if f not in SKIP_FILES]

    def assign_key(file_slug: str, text: str) -> str:
        base = f"ui.{file_slug}.{slug(text)}"
        key = base
        counter = 2
        while key in used_keys and english.get(key, added.get(key)) != text:
            key = f"{base}.{counter}"
            counter += 1
        if key not in used_keys:
            used_keys.add(key)
            added[key] = text
            order.append(key)
        return key

    for path in files:
        source = path.read_text(encoding="utf-8")
        file_slug = path.stem
        changed = False

        def acceptable(text: str) -> bool:
            if len(text) < 2 or not re.search(r"[A-Za-zА-Яа-я]", text):
                return False
            if SPECIAL_STRINGS.search(text) or KEY_LIKE.match(text):
                return False
            return text not in {"material", "none", "center", "start", "end"}

        def replace_text(match: re.Match[str]) -> str:
            nonlocal changed, matches_total
            text = unescape(match.group(1))
            if not acceptable(text):
                return match.group(0)
            key = assign_key(file_slug, text)
            changed = True
            matches_total += 1
            if args.dry_run:
                print(f"{path.relative_to(ROOT)}: {text[:60]!r} → {key}")
            return f"Text(AppStrings.g('{key}'){match.group(2)}"

        def replace_field(match: re.Match[str]) -> str:
            nonlocal changed, matches_total
            text = unescape(match.group(2))
            if not acceptable(text):
                return match.group(0)
            key = assign_key(file_slug, text)
            changed = True
            matches_total += 1
            if args.dry_run:
                print(f"{path.relative_to(ROOT)}: {text[:60]!r} → {key}")
            return f"{match.group(1)}: AppStrings.g('{key}')"

        new_source = TEXT_PATTERN.sub(replace_text, source)
        new_source = FIELD_PATTERN.sub(replace_field, new_source)

        def replace_ternary(match: re.Match[str]) -> str:
            nonlocal changed, matches_total
            first = unescape(match.group(1))
            second = unescape(match.group(2))
            if not (acceptable(first) and acceptable(second)):
                return match.group(0)
            first_key = assign_key(file_slug, first)
            second_key = assign_key(file_slug, second)
            changed = True
            matches_total += 1
            if args.dry_run:
                print(
                    f"{path.relative_to(ROOT)}: {first[:40]!r} / "
                    f"{second[:40]!r} → {first_key} | {second_key}"
                )
            return f"? AppStrings.g('{first_key}') : AppStrings.g('{second_key}')"

        new_source = TERNARY_PATTERN.sub(replace_ternary, new_source)

        def replace_arrow(match: re.Match[str]) -> str:
            nonlocal changed, matches_total
            text = unescape(match.group(1))
            if not acceptable(text):
                return match.group(0)
            key = assign_key(file_slug, text)
            changed = True
            matches_total += 1
            if args.dry_run:
                print(f"{path.relative_to(ROOT)}: => {text[:50]!r} → {key}")
            return f"=> AppStrings.g('{key}')"

        new_source = ARROW_PATTERN.sub(replace_arrow, new_source)

        def replace_list_item(match: re.Match[str]) -> str:
            nonlocal changed, matches_total
            text = unescape(match.group(2))
            if not acceptable(text):
                return match.group(0)
            # Adjacent Dart string literals are concatenated; replacing the
            # second half would leave `AppStrings.g('k') 'tail'` (a syntax
            # error). Those pairs are handled by hand.
            if new_source[: match.start()].rstrip().endswith("'"):
                return match.group(0)
            key = assign_key(file_slug, text)
            changed = True
            matches_total += 1
            if args.dry_run:
                print(f"{path.relative_to(ROOT)}: list {text[:50]!r} → {key}")
            return f"{match.group(1)}AppStrings.g('{key}'){match.group(3)}"

        new_source = LIST_ITEM_PATTERN.sub(replace_list_item, new_source)

        if changed and not args.dry_run:
            if "app_strings.dart" not in new_source:
                import_line = relative_import(path)
                imports = list(
                    re.finditer(r"^import .*;$", new_source, re.MULTILINE)
                )
                if imports:
                    position = imports[-1].end()
                    new_source = (
                        new_source[:position]
                        + "\n"
                        + import_line
                        + new_source[position:]
                    )
                else:
                    new_source = import_line + "\n\n" + new_source
            path.write_text(new_source, encoding="utf-8")

    if not args.dry_run:
        english.update(added)
        write_tsv("en", english, order)
        print(f"replacements: {matches_total}, new keys: {len(added)}")
    else:
        print(f"matches: {matches_total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
