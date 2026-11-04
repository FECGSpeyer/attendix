# Review brief for one parity batch

Placeholders: `{BATCH}`, `{SLICE}` (input file from `parity.mjs slice`),
`{IONIC}` (Ionic checkout), `{FLUTTER}` (Flutter checkout to compare),
`{OUT}` (output file `docs/parity/status/{BATCH}.json`),
`{IONIC_SHA}`, `{FLUTTER_SHA}`.

---

You are verifying feature and UI parity between the Ionic app (the reference)
and the Flutter app for one batch of Ionic source units. The Flutter app will
replace the Ionic app in the stores; the owner needs certainty that every
feature and nearly every UI detail exists identically in the Flutter app's
**normal design**. A wrong `ok` is worse than an honest `unclear`.

## Inputs

- Batch file `{SLICE}`: JSON with `units` (each with its Ionic files `ts` and
  `html`, its `routes`, and `items`) and `i18n` (Ionic key → German text `de`,
  Flutter ARB key `arb`, and where normal Flutter code uses that ARB key:
  `flutter.normal` as `file:line`; `flutter.beta` = Beta-only uses).
  The key usages are hints, not proof.
- Ionic source (read-only): `{IONIC}/src/app/<file>`; translations in
  `{IONIC}/src/i18n/de.json`.
- Flutter source (read-only): `{FLUTTER}/lib`. Flutter texts come from
  `context.l10n.<arbKey>` (generated from the Ionic keys, same wording) or from
  Flutter-only strings in `lib/l10n/fragments/*.json`.

## Scope rules

- Only the **normal** Flutter design counts. Beta/redesign code is excluded:
  `lib/features/redesign/`, `lib/core/theme/redesign/`, files named `rd_*.dart`,
  and branches only taken when the Beta switch is on. If something exists only
  in Beta, the status is `missing` with the note "nur im Beta".
- Platform look (iOS vs Material widgets) is not a difference by itself.
- Do not edit any file except `{OUT}`. No git commands, no network, no builds.

## Status per item (every item of the batch)

- `ok`: same function, same place (page/section/sheet), same German text
  (punctuation/capitalisation nuances are fine), same visibility condition
  (roles, states, platform), same effect (navigation target, dialog content and
  buttons, data written). A Flutter-native replacement with the same
  user-visible behaviour is `ok`.
- `diff`: exists but differs in something a user could notice or in
  behaviour. The note states precisely what differs ("Ionic: … / Flutter: …").
- `missing`: no counterpart in the normal design.
- `na`: not applicable by nature (Angular/Ionic plumbing without user-visible
  effect, e.g. change detection, lifecycle wiring). Give the reason.
- `unclear`: could not be determined; say what is missing to decide.

## How to check each item kind

- `action`: what the user taps (button, item, tab, sliding option, fab, link),
  label and icon, where it appears, under which conditions (`cond` lists the
  enclosing `@if/@for/@switch`; trace role flags such as `isConductor`,
  `isHelper`, `isAdmin` to their TS definitions and compare with Flutter's role
  checks), and what the handler does (follow it into the TS method).
- `field`: control type, label/placeholder/helper text, all options in order,
  default value, validation, what happens on change, conditions.
- `text`: heading/label/note/badge/data display: same text and same data
  (`bound` lists data expressions; check formatting such as dates, percent).
- `embed`: the child component appears at the same place, same condition.
- `alert` / `actionsheet` / `popover`: same trigger, header, message, every
  button (text, role, order, effect), inputs.
- `modal`: same trigger, presentation (sheet with breakpoints vs full page vs
  card) and passed data. The modal's own content is checked in its own unit.
- `toast`: same message in the same situation, similar colour (success/danger).
- `loading`: Ionic shows a blocking overlay with this message; `ok` if Flutter
  blocks equivalently, `diff`/`niedrig` if not.
- `nav`: same navigation target and behaviour (back stack, replace).
- `db`: same table/RPC/edge function/bucket, same operation, same written
  columns and values, same filters (tenantId!), same conditions. Writes need
  the most care. A read is `ok` when the same data is read.
- `native` / `effect`: same platform behaviour (haptics, share sheet, browser,
  download/open file, print, clipboard, push, live activity).
- `route`: the path exists in the Flutter router (same path or a redirect from
  it), same guard/role access, same landing page.
- `logic`: `methods` lists every method of the Ionic class. Go through all of
  them and compare the behaviour behind the UI: data loading, sorting,
  filtering, grouping, calculations (percentages, counts, ages), defaults,
  validation, role flags, caching/offline, side effects. `ok` if everything
  matches; otherwise `diff` with a summary **and** one `extra` finding per
  substantive difference.

## Severity for `diff` / `missing` (`sev`)

- `hoch`: a feature/action is missing or behaves differently, wrong or missing
  data, a role sees something it must not or misses something it should, a
  different DB write.
- `mittel`: visible difference in flow, position, order, dialog type, or a text
  with different meaning; a missing hint or confirmation.
- `niedrig`: cosmetic (icon, colour, punctuation, same meaning in other words,
  loading indicator).

## Output

Write `{OUT}`:

```json
{
  "batch": "{BATCH}", "ionic": "{IONIC_SHA}", "flutter": "{FLUTTER_SHA}",
  "items": {
    "<item id>": { "s": "ok|diff|missing|na|unclear", "f": ["lib/…/x.dart:123"], "n": "kurze Notiz", "sev": "hoch|mittel|niedrig" }
  },
  "extra": [
    { "unit": "<unit id>", "title": "kurz", "n": "Ionic: … / Flutter: …", "sev": "hoch|mittel|niedrig", "ionic": "src/app/…:line", "f": ["lib/…:line"] }
  ]
}
```

- Every item id of the batch appears exactly once.
- `f` is required for `ok` and `diff` (paths relative to the Flutter repo).
- `n` is required for everything except a plain `ok`; German, short, concrete,
  quote texts.
- `sev` only for `diff` and `missing`.
- Write the file after each unit so work is not lost. At the end validate it:
  it must parse as JSON and contain exactly the batch's item ids.

Final message (short): counts per status and the five most important gaps.
