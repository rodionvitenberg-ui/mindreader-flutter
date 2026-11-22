#!/usr/bin/env python3
"""Fill missing translations in `l10n/<code>.tsv` automatically.

`l10n/en.tsv` is the source language. For every other language this script
translates the English text of each key that is still missing, in batches, and
appends the result to that language's TSV. Existing human/AI edits are never
overwritten, so you can fix a translation by hand and re-run the script.

Placeholders (`{count}`, `{name}`, …) are masked with opaque tokens while the
text is translated and restored afterwards.

Usage:
    python3 tool/translate_l10n.py            # fill every language
    python3 tool/translate_l10n.py --lang es  # one language
    python3 tool/translate_l10n.py --force es # re-translate every key
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
import time
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"
LANGUAGES = ["ru", "es", "pt", "de", "fr"]
ENDPOINT = (
    "https://clients5.google.com/translate_a/t"
    "?client=dict-chrome-ex&sl=en&tl={lang}"
)
TOKEN = "QQX{i}XQQ"
PLACEHOLDER = re.compile(r"\{([a-zA-Z0-9_]+)\}")

# Brand names and the native language labels stay identical in every locale.
SKIP_KEYS = {"pro.title"}
SKIP_PREFIXES = ("settings.lang.",)


def unescape(value: str) -> str:
    return value.replace("\\n", "\n").replace("\\t", "\t").replace("\\\\", "\\")


def read_tsv(code: str) -> dict[str, str]:
    path = L10N / f"{code}.tsv"
    if not path.exists():
        path.write_text("# key\ttext\n", encoding="utf-8")
    entries: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw or raw.startswith("#") or "\t" not in raw:
            continue
        key, value = raw.split("\t", 1)
        entries[key.strip()] = unescape(value)
    return entries


def escape(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
        .replace("\r", "")
    )


def mask(text: str) -> tuple[str, list[tuple[str, str]]]:
    tokens: list[tuple[str, str]] = []

    def replace(match: re.Match[str]) -> str:
        index = len(tokens)
        token = TOKEN.format(i=index)
        tokens.append((token, match.group(0)))
        return token

    return PLACEHOLDER.sub(replace, text), tokens


def unmask(text: str, tokens: list[tuple[str, str]]) -> str:
    for token, original in tokens:
        text = text.replace(token, original)
    return text


def translate(texts: list[str], lang: str, retries: int = 4) -> list[str]:
    payload = urllib.parse.urlencode([("q", t) for t in texts]).encode()
    request = urllib.request.Request(
        ENDPOINT.format(lang=lang),
        data=payload,
        headers={"User-Agent": "Mozilla/5.0 (mindreader l10n tool)"},
    )
    last_error: Exception | None = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read().decode("utf-8")
            data = json.loads(body)
            if isinstance(data, list) and len(data) == len(texts):
                return [str(item) for item in data]
            last_error = ValueError(f"unexpected response: {body[:200]}")
        except Exception as error:  # noqa: BLE001 - retry every network error
            last_error = error
        time.sleep(1.5 * (attempt + 1))
    raise SystemExit(f"translation failed for {lang}: {last_error}")


def write_tsv(code: str, entries: dict[str, str], order: list[str]) -> None:
    lines = ["# key\ttext — edit this file, then run: python3 tool/gen_l10n_dart.py"]
    for key in order:
        if key in entries:
            lines.append(f"{key}\t{escape(entries[key])}")
    (L10N / f"{code}.tsv").write_text("\n".join(lines) + "\n", encoding="utf-8")



def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", choices=LANGUAGES, action="append")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--batch", type=int, default=16)
    args = parser.parse_args()

    english = read_tsv("en")
    order = list(english.keys())
    languages = args.lang or LANGUAGES

    for lang in languages:
        entries = read_tsv(lang)
        if args.force:
            for key in order:
                if not (key in SKIP_KEYS or key.startswith(SKIP_PREFIXES)):
                    entries.pop(key, None)
        for key in order:
            if (key in SKIP_KEYS or key.startswith(SKIP_PREFIXES)) and key not in entries:
                entries[key] = english[key]
        missing = [key for key in order if key not in entries]
        if not missing:
            print(f"{lang}: complete ({len(order)} keys)")
            continue
        print(f"{lang}: {len(missing)} missing")
        index = 0
        while index < len(missing):
            batch_keys: list[str] = []
            batch: list[str] = []
            while index < len(missing) and len(batch) < args.batch:
                key = missing[index]
                text = english[key]
                index += 1
                if len(text) > 1200:
                    # Long paragraphs still go alone, just not batched.
                    batch_keys.append(key)
                    batch.append(text)
                    break
                batch_keys.append(key)
                batch.append(text)
            masked: list[str] = []
            masks: list[list[tuple[str, str]]] = []
            for text in batch:
                masked_text, tokens = mask(text)
                masked.append(masked_text)
                masks.append(tokens)
            translated = translate(masked, lang)
            for key, value, tokens in zip(batch_keys, translated, masks):
                entries[key] = unmask(value, tokens)
            write_tsv(lang, entries, order)
            print(f"  {lang}: {len(entries)}/{len(order)}")
            time.sleep(0.4)
        write_tsv(lang, entries, order)
        print(f"{lang}: done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
