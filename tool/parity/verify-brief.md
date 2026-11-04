# Verification brief (second, independent pass)

Placeholders: `{BATCH}`, `{SLICE}` (from `parity.mjs verify-slices` or
`verify2-slices`), `{IONIC}` (Ionic checkout), `{FLUTTER}` (this repo),
`{PUB_CACHE}` (Dart package cache, `$PUB_CACHE` or `~/.pub-cache`), `{OUT}`,
`{IONIC_SHA}`, `{FLUTTER_SHA}`.

---

A first reviewer compared the Ionic app (reference) with the Flutter app
(normal design, not Beta) item by item. You check a sample of those verdicts
independently. The results decide which gaps get fixed before the Flutter app
replaces the Ionic app in the stores, so both a false gap and a missed gap are
costly.

`{SLICE}` holds `items`; each has the Ionic `unit` and files, the extracted
Ionic `item` (kind, file, line, conditions, texts …) and the first verdict
`first` (`s` status, `f` Flutter references, `n` note, `sev` severity).
Sources: Ionic `{IONIC}/src/app/…` (translations `{IONIC}/src/i18n/de.json`),
Flutter `{FLUTTER}/lib/…` (Beta code under `lib/features/redesign/`,
`lib/core/theme/redesign/`, `rd_*.dart` does not count). Package sources:
`{PUB_CACHE}/hosted/pub.dev/`. Status and severity definitions are in
`{FLUTTER}/tool/parity/review-brief.md`; read it first.

For every item:

1. Read the Ionic code yourself and form your own picture of what the user
   sees and what happens (including role conditions and data written).
2. Find the Flutter counterpart yourself; the first verdict's references are
   a starting point, but also search for other places (another page, a shared
   widget, a provider) where the behaviour may live.
3. Decide `s` and `sev` on your own. Then compare with `first`.
   - Agree: `v: "bestätigt"`, keep or sharpen the note.
   - Disagree: `v: "korrigiert"`, give the corrected `s`/`sev`/`f` and say
     in `n` what the first reviewer got wrong.
   - Pay special attention to DB writes (table, columns, values, filters,
     tenantId) and to role visibility.

Write `{OUT}`:

```json
{
  "batch": "{BATCH}", "ionic": "{IONIC_SHA}", "flutter": "{FLUTTER_SHA}",
  "items": { "<item id>": { "s": "…", "sev": "…", "f": ["lib/…:12"], "n": "…", "v": "bestätigt|korrigiert" } },
  "extra": []
}
```

### Round 2 slices (`zz-verify2-*`)

Each entry has a `reason`:

- `rolle-mandant`: the first verdict is `ok`/`na`, but the Ionic element is
  only shown or enabled for certain roles or tenant settings (see
  `item.cond`). Work out for every role (Admin/Dirigent, Verantwortlich,
  Helfer, Stimmführer, Spieler, Eltern, Beobachter, Bewerber, and the
  tenant flags involved) whether it sees/can use the element in Ionic, then
  check the same in Flutter (role getters, route guards, tenant settings).
  A role that sees or can do more or less than in Ionic is a gap; a role
  that can write data it could not write in Ionic is at least `mittel`.
- `neu`: the item is new in the inventory (`first` is `null`). Give a full
  first verdict; leave out `v`.
- `zusatzbefund`: instead of `item` the entry has `extra` (`id`, `title`,
  `n`, `sev`, `ionic`, `f`), a finding a first reviewer added outside the
  item list. Check whether it is real and correctly rated. Write it under its
  `id` (`x-…`) in `items`: `s` `diff` or `missing` with `sev` keeps it,
  `s` `ok` or `na` withdraws it (say why in `n`), always with `v`.

Every item id (and every `x-…` id) of the slice appears once. Notes in German, short and concrete.
Write the file regularly and validate it at the end. Do not edit anything
else; no git, no network, no builds.

Final message (short): number confirmed vs corrected, and the corrections
that change a severity to or from `hoch`.
