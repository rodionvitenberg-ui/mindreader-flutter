#!/usr/bin/env python3
"""Add or update keys in l10n/en.tsv (and optionally other languages).

Usage:
    python3 tool/add_l10n.py key "English text"
    python3 tool/add_l10n.py key "English text" ru "Русский текст" es "Texto"

The key is appended when new, or its text is replaced when it already exists.
"""
import pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
L10N = ROOT / 'l10n'

def unescape(v):
    return v.replace('\\n','\n').replace('\\t','\t').replace('\\\\','\\')

def escape(v):
    return v.replace('\\','\\\\').replace('\n','\\n').replace('\t','\\t').replace('\r','')

def read(code):
    path = L10N / f'{code}.tsv'
    entries = {}
    if path.exists():
        for raw in path.read_text(encoding='utf-8').splitlines():
            if raw and not raw.startswith('#') and '\t' in raw:
                k, v = raw.split('\t', 1)
                entries[k.strip()] = unescape(v)
    return entries

def write(code, entries):
    path = L10N / f'{code}.tsv'
    lines = ['# key\ttext — edit this file, then run: python3 tool/gen_l10n_dart.py']
    lines += [f'{k}\t{escape(v)}' for k, v in entries.items()]
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')

def main():
    args = sys.argv[1:]
    if len(args) < 2:
        raise SystemExit(__doc__)
    key, english = args[0], args[1]
    en = read('en')
    en[key] = english
    write('en', en)
    rest = args[2:]
    while rest:
        code, value = rest[0], rest[1]
        rest = rest[2:]
        entries = read(code)
        entries[key] = value
        # Keep the English order: rebuild this file in the en key order.
        ordered = {k: entries[k] for k in en if k in entries}
        for k, v in entries.items():
            if k not in ordered:
                ordered[k] = v
        write(code, ordered)

if __name__ == '__main__':
    main()
