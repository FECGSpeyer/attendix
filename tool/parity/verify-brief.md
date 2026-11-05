# Verification brief (second, independent pass)

Placeholders: `{BATCH}`, `{SLICE}` (from `parity.mjs verify-slices` or
`verify-round <N>`), `{IONIC}` (Ionic checkout), `{FLUTTER}` (this repo),
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

### Full rounds (`zz-verify2-*`, `zz-verify3-*`, …)

Each entry has a `reason`:

- `rolle-mandant`: the verdict is `ok`/`na`, but the Ionic element is only
  shown, enabled or executed for certain roles or tenant settings: see
  `item.cond`, and if `item.roleGuarded` is true, the role or tenant check
  sits in the TypeScript method that contains the element (an early
  `return`, an `if` around it, a getter it calls). Work out for every role
  (Admin/Dirigent, Verantwortlich, Helfer, Stimmführer, Spieler, Eltern,
  Beobachter, Bewerber, and the tenant flags involved) whether it sees, can
  use or triggers the element in Ionic, then check the same in Flutter (role
  getters, route guards, tenant settings, provider checks). A role that sees
  or can do more or less than in Ionic is a gap; a role that can write data
  it could not write in Ionic is at least `mittel`. The role or tenant
  dependence can also sit in a bound attribute (`item.attrs` keys in
  brackets such as `[disabled]`, `item.bindings`, `item.bindingExprs`). With
  `via: "ausloeser"` the item is inside an inline modal/popover (or is it)
  whose opening element depends on role or tenant: judge who can open it.
- `behoben-ungeprueft`: a fix PR set the item (or the extra finding, entry
  with `extra` and `fix`) to `ok` in `zz-fixed-*` and no round has looked at
  it since. Check that the fix really closes the gap, with `v`.
- `neu`: the item is new in the inventory (`first` is `null`). Give a full
  first verdict; leave out `v`.
- `geaendert`: the item's content changed since its verdict (a newer Ionic
  version or a more complete extraction, e.g. text inside an element).
  Judge it again from scratch against `first`, with `v`.
- `abweichung-ungeprueft`, `db-unaufgeloest`: a gap or a DB call without a
  second check. Check as in the main steps above.
- `zusatzbefund`, `zusatzbefund-ionic-geaendert`: instead of `item` the
  entry has `extra` (`id`, `title`, `n`, `sev`, `ionic`, `f`, `stale`), a
  finding a reviewer added outside the item list (`stale`: its Ionic page
  changed after the finding). Check whether it is real and correctly rated.
  Write it under its `id` (`x-…`) in `items`: `s` `diff` or `missing` with
  `sev` keeps it, `s` `ok` or `na` withdraws it (say why in `n`), always
  with `v`.

Every item id (and every `x-…` id) of the slice appears once. Notes in German, short and concrete.
Write the file regularly and validate it at the end. Do not edit anything
else; no git, no network, no builds.

Final message (short): number confirmed vs corrected, and the corrections
that change a severity to or from `hoch`.
