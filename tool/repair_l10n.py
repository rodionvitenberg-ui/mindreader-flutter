#!/usr/bin/env python3
"""Repair empty / placeholder-broken machine translations in `l10n/*.tsv`.

Google occasionally returns an empty string or drops a `{placeholder}`.
This script retries those keys one by one and falls back to the English text
when the service still cannot produce a safe result. It also forces the six
native language labels into every dictionary.
"""
from __future__ import annotations
import importlib.util, pathlib, re, sys, time

ROOT = pathlib.Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('tl', ROOT / 'tool' / 'translate_l10n.py')
tl = importlib.util.module_from_spec(spec); spec.loader.exec_module(tl)
PLACEHOLDER = re.compile(r'\{([a-zA-Z0-9_]+)\}')
NATIVE = {'en':'ENGLISH','ru':'РУССКИЙ','es':'ESPAÑOL','pt':'PORTUGUÊS','de':'DEUTSCH','fr':'FRANÇAIS'}

def placeholders(text):
    return set(PLACEHOLDER.findall(text))

def main():
    english = tl.read_tsv('en')
    order = list(english.keys())
    for lang in tl.LANGUAGES:
        entries = tl.read_tsv(lang)
        for code, label in NATIVE.items():
            entries[f'settings.lang.{code}'] = label
        broken = [k for k in order if not entries.get(k,'').strip() or placeholders(entries.get(k,'')) != placeholders(english[k])]
        print(f'{lang}: {len(broken)} broken')
        for i, key in enumerate(broken):
            source = english[key]
            masked, tokens = tl.mask(source)
            value = ''
            for attempt in range(3):
                try:
                    value = tl.translate([masked], lang)[0]
                except SystemExit as exc:
                    print('  ', exc); value = ''
                value = tl.unmask(value, tokens)
                if value.strip() and placeholders(value) == placeholders(source):
                    break
                time.sleep(1.0)
            if not value.strip() or placeholders(value) != placeholders(source):
                value = source
            entries[key] = value
            if (i+1) % 25 == 0:
                tl.write_tsv(lang, entries, order)
                print(f'  {lang}: {i+1}/{len(broken)}')
            time.sleep(0.25)
        tl.write_tsv(lang, entries, order)
        print(f'{lang}: repaired')

if __name__ == '__main__':
    main()
