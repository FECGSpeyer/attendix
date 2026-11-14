#!/usr/bin/env python3
"""Checks that app texts quoted in docs/beta still exist in the app.

The Beta docs quote texts of the app in German quotation marks: „Bin dabei“.
This script looks every quoted text up in lib/l10n/app_de.arb and lists the
ones the app no longer has, so a renamed button shows up as a stale doc.

    python3 tool/docs/check_app_texts.py          # list unknown texts
    python3 tool/docs/check_app_texts.py --strict # exit 1 if there are any

Texts with placeholders match loosely ("Antwort bis {date}" matches
„Antwort bis …“ and „Antwort bis Fr 2.11.“). Quotes that are examples and not
app texts are listed in docs/beta/.app-texts-ignore, one per line.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / 'docs' / 'beta'
ARB = ROOT / 'lib' / 'l10n' / 'app_de.arb'
IGNORE = DOCS / '.app-texts-ignore'

QUOTE = re.compile(r'„([^“”„]+)[“”]')


def branches(text):
    """All plain variants of an ICU message (plural/select branches)."""
    m = re.search(r'\{\s*\w+\s*,\s*(?:plural|select)\s*,', text)
    if not m:
        return [text]
    # Find the end of the ICU block and its top-level branches.
    depth, i, start = 0, m.start(), m.start()
    parts, branch_start = [], None
    while i < len(text):
        c = text[i]
        if c == '{':
            depth += 1
            if depth == 2:
                branch_start = i + 1
        elif c == '}':
            if depth == 2 and branch_start is not None:
                parts.append(text[branch_start:i])
            depth -= 1
            if depth == 0:
                break
        i += 1
    head, tail = text[:start], text[i + 1:]
    out = []
    for part in parts:
        out.extend(branches(head + part + tail))
    return out or [text]


def pattern(text):
    """Regex for one variant: placeholders match anything."""
    pieces = re.split(r'\{\w+\}', text)
    return re.compile('.+?'.join(re.escape(p) for p in pieces), re.S)


def normalise(text):
    return re.sub(r'\s+', ' ', text.replace('…', '...')).strip()


def main():
    arb = json.loads(ARB.read_text(encoding='utf-8'))
    variants = []
    for key, value in arb.items():
        if key.startswith('@') or not isinstance(value, str):
            continue
        for b in branches(value):
            variants.append(normalise(b))
    plain = set(variants)
    # A message that is little more than a placeholder ("{name}") would
    # match every quote, so it needs some text of its own.
    loose = [pattern(v) for v in variants
             if '{' in v and len(re.findall(r'[^\W\d_]', re.sub(r'\{\w+\}', '', v))) >= 4]

    ignore = set()
    if IGNORE.exists():
        ignore = {normalise(l) for l in IGNORE.read_text(encoding='utf-8').splitlines()
                  if l.strip() and not l.startswith('#')}

    unknown = []
    for path in sorted(DOCS.rglob('*.md')):
        text = path.read_text(encoding='utf-8')
        # Quotes may wrap over a line break inside a list item.
        flat = re.sub(r'\n\s*', ' ', text)
        for quote in QUOTE.findall(flat):
            q = normalise(quote)
            if q in plain or q in ignore:
                continue
            if any(p.fullmatch(q) for p in loose):
                continue
            unknown.append((path.relative_to(ROOT), quote))

    if not unknown:
        print('docs/beta: alle zitierten App-Texte gibt es in app_de.arb.')
        return 0
    print('Diese Texte stehen in docs/beta in „Anführungszeichen“, aber nicht '
          '(mehr) in lib/l10n/app_de.arb:\n')
    for path, quote in unknown:
        print(f'  {path}: „{quote}“')
    print('\nWurde ein Text der App umbenannt, passe die Doku an. Ist das '
          'Zitat nur ein Beispiel, trage es in docs/beta/.app-texts-ignore ein.')
    return 1 if '--strict' in sys.argv else 0


if __name__ == '__main__':
    sys.exit(main())
