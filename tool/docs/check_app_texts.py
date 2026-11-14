#!/usr/bin/env python3
"""Checks that app texts quoted in docs/beta still exist in the app.

The Beta docs quote texts of the app in German quotation marks: „Bin dabei“.
This script looks every quoted text up in lib/l10n/app_de.arb and lists the
ones the app no longer has, so a renamed button shows up as a stale doc.

    python3 tool/docs/check_app_texts.py          # list unknown texts
    python3 tool/docs/check_app_texts.py --strict # exit 1 if there are any

It also checks the references inside the docs: every scenario number that is
mentioned (L-17) has its heading, no number is used twice, and every link to
another page or section leads somewhere.

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


SCENARIO = re.compile(r'^### ([A-Z]-\d{2}) ', re.M)
SCENARIO_REF = re.compile(r'(?<![\w-])([MSHBLAEN]-\d{2})(?!\d)')
LINK = re.compile(r'\[[^\]]*\]\(([^)\s]+)\)')
HEADING = re.compile(r'^#{1,6} (.+)$', re.M)


def slug(heading):
    """Anchor GitHub gives a heading."""
    text = re.sub(r'[`*_]', '', heading).strip().lower()
    text = re.sub(r'[^\w\- ]', '', text)
    return text.replace(' ', '-')


def check_refs():
    """Dangling scenario numbers and links; a list of (path, problem)."""
    # Fenced blocks are examples (the scenario template), not content.
    pages = {p: re.sub(r'```.*?```', '', p.read_text(encoding='utf-8'), flags=re.S)
             for p in sorted(DOCS.rglob('*.md'))}
    problems = []
    defined = {}
    for path, text in pages.items():
        for sid in SCENARIO.findall(text):
            if sid in defined:
                problems.append((path, f'{sid} gibt es zweimal (auch in {defined[sid].name})'))
            defined[sid] = path
    anchors = {p: {slug(h) for h in HEADING.findall(t)} for p, t in pages.items()}
    for path, body in pages.items():
        for sid in sorted(set(SCENARIO_REF.findall(body)) - set(defined)):
            problems.append((path, f'{sid} wird genannt, aber kein Szenario heißt so'))
        for target in LINK.findall(body):
            if re.match(r'[a-z]+:', target):
                continue
            file, _, anchor = target.partition('#')
            dest = (path.parent / file).resolve() if file else path
            if not dest.exists():
                problems.append((path, f'Link {target}: die Datei gibt es nicht'))
            elif anchor and dest in anchors and anchor not in anchors[dest]:
                problems.append((path, f'Link {target}: den Abschnitt gibt es nicht'))
    return [(p.relative_to(ROOT), msg) for p, msg in problems]


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

    refs = check_refs()
    if refs:
        print('Diese Verweise in docs/beta führen ins Leere:\n')
        for path, msg in refs:
            print(f'  {path}: {msg}')
        print()
    if not unknown:
        print('docs/beta: alle zitierten App-Texte gibt es in app_de.arb.')
        return 1 if refs and '--strict' in sys.argv else 0
    print('Diese Texte stehen in docs/beta in „Anführungszeichen“, aber nicht '
          '(mehr) in lib/l10n/app_de.arb:\n')
    for path, quote in unknown:
        print(f'  {path}: „{quote}“')
    print('\nWurde ein Text der App umbenannt, passe die Doku an. Ist das '
          'Zitat nur ein Beispiel, trage es in docs/beta/.app-texts-ignore ein.')
    return 1 if '--strict' in sys.argv else 0


if __name__ == '__main__':
    sys.exit(main())
