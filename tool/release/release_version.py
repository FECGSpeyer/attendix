#!/usr/bin/env python3
"""Turns pending changelog fragments into one internal version bump.

PRs no longer bump the version themselves (several threads merging in
parallel made every PR conflict on the same three lines). Instead each PR
adds one file to changelog/unreleased/, for example

    changelog/unreleased/beta-desktop.json
    {"bump": "minor", "changes": ["✨ Beta: Desktop-Ansicht mit Liste und Detail"]}

"bump" is "minor" (feature) or "patch" (fix); missing means "patch".

After a merge to master the deploy workflow runs this script. It
  1. picks the largest bump of all fragments,
  2. raises pubspec.yaml (x.y.z+build, build + 1) and AppConstants.appVersion,
  3. puts one entry with all changes on top of assets/version_history.json,
  4. deletes the fragments.
With no fragments it changes nothing. It prints the new version, or nothing.

Usage: python3 tool/release/release_version.py [repo_root] [--date D.M.YYYY]
       python3 tool/release/release_version.py --check   (only validate, CI)
"""
import datetime
import json
import pathlib
import re
import sys
import zoneinfo

FRAGMENTS = 'changelog/unreleased'
PUBSPEC = 'pubspec.yaml'
CONSTANTS = 'lib/core/constants/app_constants.dart'
HISTORY = 'assets/version_history.json'

_PUBSPEC_RE = re.compile(r'^version: *(\d+)\.(\d+)\.(\d+)\+(\d+) *$', re.M)
_APP_VERSION_RE = re.compile(
    r"(static const String appVersion = ')(\d+\.\d+\.\d+)(';)")


def _fail(message):
    sys.stderr.write(f'release_version: {message}\n')
    sys.exit(1)


def read_fragments(root):
    files = sorted((root / FRAGMENTS).glob('*.json'))
    fragments = []
    for path in files:
        try:
            data = json.loads(path.read_text(encoding='utf-8'))
        except ValueError as e:
            _fail(f'{path.name} is not valid JSON: {e}')
        bump = data.get('bump', 'patch')
        changes = data.get('changes')
        if bump not in ('minor', 'patch'):
            _fail(f'{path.name}: bump must be "minor" or "patch", not {bump!r}')
        if (not isinstance(changes, list) or not changes
                or not all(isinstance(c, str) and c.strip() for c in changes)):
            _fail(f'{path.name}: "changes" must be a non-empty list of texts')
        fragments.append((path, bump, changes))
    return fragments


def release(root, date):
    fragments = read_fragments(root)
    if not fragments:
        return None

    pubspec_path = root / PUBSPEC
    pubspec = pubspec_path.read_text(encoding='utf-8')
    match = _PUBSPEC_RE.search(pubspec)
    if not match:
        _fail('version line in pubspec.yaml not found')
    major, minor, patch, build = (int(g) for g in match.groups())
    if any(bump == 'minor' for _, bump, _ in fragments):
        minor, patch = minor + 1, 0
    else:
        patch += 1
    version = f'{major}.{minor}.{patch}'
    pubspec_path.write_text(
        pubspec[:match.start()] + f'version: {version}+{build + 1}'
        + pubspec[match.end():], encoding='utf-8')

    constants_path = root / CONSTANTS
    constants, count = _APP_VERSION_RE.subn(
        rf'\g<1>{version}\g<3>', constants_path.read_text(encoding='utf-8'))
    if count != 1:
        _fail('appVersion in app_constants.dart not found')
    constants_path.write_text(constants, encoding='utf-8')

    history_path = root / HISTORY
    history = json.loads(history_path.read_text(encoding='utf-8'))
    history['versions'].insert(0, {
        'version': version,
        'date': date,
        'changes': [c for _, _, changes in fragments for c in changes],
    })
    history_path.write_text(
        json.dumps(history, indent=2, ensure_ascii=False) + '\n',
        encoding='utf-8')

    for path, _, _ in fragments:
        path.unlink()
    return version


def main(args):
    if '--check' in args:
        args = [a for a in args if a != '--check']
        root = pathlib.Path(args[0] if args else '.')
        print(f'{len(read_fragments(root))} changelog fragment(s) ok')
        return
    date = None
    if '--date' in args:
        i = args.index('--date')
        date = args[i + 1]
        args = args[:i] + args[i + 2:]
    if date is None:
        today = datetime.datetime.now(zoneinfo.ZoneInfo('Europe/Berlin'))
        date = f'{today.day}.{today.month}.{today.year}'
    root = pathlib.Path(args[0] if args else '.')
    version = release(root, date)
    if version:
        print(version)


if __name__ == '__main__':
    main(sys.argv[1:])
