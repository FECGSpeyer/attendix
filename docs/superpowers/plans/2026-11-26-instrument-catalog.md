# Instrument Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship the agreed instrument collection, editable ensemble presets, and custom-entry path in Attendix's current UI.

**Architecture:** Immutable bundled catalog and pure selection drafts feed a tenant-bound importer using the current instrument/category schema. A shared selection sheet serves the group list and tenant-creation form.

**Tech Stack:** Flutter, Dart, Riverpod, Supabase, existing Rd components and generated localization.

**Spec:** `docs/superpowers/specs/2026-11-26-instrument-catalog-design.md`

## Global Constraints

- Preserve local group IDs, custom names, category assignments, person references and sheet-music references. No schema migration.
- No Big Band preset; use Volksinstrumentenorchester. No head counts or structured doubling.
- Honor immutable tenant/account context, roles, demo guards and current offline rules.
- All five Rd color worlds and light/dark; DE/EN interface strings through fragments, generated ARB and Dart.
- No direct version bumps. One minor changelog fragment and updated beta scenarios.
- Worktree `/Users/I576226/.codex/worktrees/instrument-catalog/attendix`, branch `codex/instrument-catalog`. No push, merge or production deployment as part of local implementation.

## Review Focus

- Account/tenant changes during open dialogs or writes: original scope must remain bound and stale UI must not navigate/report success.
- Existing German/English aliases and numbered strings: preserve distinction and avoid duplicate copies without merging unrelated families.
- Network result ambiguity and retry: refresh persisted state; do not create another tenant or a half-batch of instruments.
- User typography and narrow screens: selection, query, footer and custom-entry path stay accessible.
- Untuned percussion, variant tuning and choir: no generic C/treble defaults silently replace explicit catalog metadata.

## Task 1: Catalog and pure drafts

**Files:** create `lib/features/instruments/data/instrument_catalog.dart`, `instrument_presets.dart`, `catalog_selection.dart`; tests under `test/features/instruments/`.

**Interfaces:**
- `InstrumentFamily` enum with `label(String languageCode)` and stable ordering (strings, woodwinds, brass, percussion, keyboards, plucked, voices, folk).
- `CatalogInstrument`: const fields `id`, `nameDe`, `nameEn`, `family`, `aliases` (`List<String>`), nullable `tuning`, nullable `clefs` (`List<String>`); `String label(String languageCode)`.
- `const instrumentCatalog`: immutable curated list, including mainstream orchestra and folk instruments; `List<CatalogInstrument> searchInstrumentCatalog(String query, {InstrumentFamily? family, bool voicesOnly = false})`.
- `CatalogGroupDraft`: const fields `key`, `instrumentId`, `name`, nullable `categoryName`, `synonyms` (`List<String>`), nullable `tuning`, nullable `clefs`; `copyWith({String? name})` must deliberately restrict aliases for renamed additional voices to prevent duplicate matching.
- `CatalogPreset`: const `id`, `nameDe`, `nameEn`, `tenantType`; `String label(String languageCode)`; `List<CatalogPresetEntry> entries` with each entry's `key`, `instrumentId`, DE/EN output names, precise synonyms, `selectedByDefault`.
- `instrumentPresets` list; `CatalogGroupDraft draftFromInstrument(CatalogInstrument instrument, {required String languageCode, String? name})`; `CatalogGroupDraft draftFromPresetEntry(CatalogPresetEntry entry, {required String languageCode})`.
- `String normalizeCatalogName(String value)`; `bool draftMatchesGroup(CatalogGroupDraft draft, Group group)` with exact normalized names/curated aliases and no main-group matches.

- [ ] Write tests for synonyms, family filter, distinct flute variants and tuned/mallet instruments; observe failure.
- [ ] Add curated data (at least 60 useful distinct types), presets and precise drafts. Default symphony selection has 14 rows, violin I/II share type but distinct keys/names/aliases.
- [ ] Test custom renaming and German/English equivalent names; no wildcard/substrings in duplicate detection.
- [ ] Run `flutter test test/features/instruments/`; analyze changed Dart files; commit only owned files.

## Task 2: Tenant-bound batch importer

**Files:** `lib/data/repositories/group_repository.dart`; new `lib/features/instruments/data/catalog_import.dart`; tests for importer and repository requests.

**Interfaces:** `Future<List<Group>> GroupRepository.createGroups(List<Map<String,dynamic>> rows)` sanitizes each, forcibly binds tenant, honors demo, and uses one insert. `CatalogImportResult` has `added`, `skipped` integer counts. `Future<CatalogImportResult> importCatalogGroups(GroupRepository repository, List<CatalogGroupDraft> drafts, {bool Function()? isCurrent})` reads current groups/categories, removes duplicates, ensures categories, appends sort order, inserts all remaining groups once. `isCurrent` checked after awaits before another mutation; throws/cancels on scope change.

- [ ] Write behavior tests using repository fakes or recorded HTTP requests: preservation, no duplicate second import, name alias handling, no main-group reuse, partial category failure, empty batch and context switch.
- [ ] Implement sanitized bulk writes and category reuse; no destructive rollback. Explicit null/empty metadata survives rather than defaulting to C/treble.
- [ ] Test demo rejection, tenant binding and caller data not mutated.
- [ ] Run importer/repository tests and relevant group/provider tests.

## Task 3: Shared collection picker and existing group list

**Files:** new `lib/features/instruments/presentation/widgets/instrument_catalog_sheet.dart`; `lib/features/redesign/presentation/pages/rd_groups_page.dart`; `lib/l10n/fragments/instrument_catalog.json` and generated files; widget tests.

**Interface:** `Future<List<CatalogGroupDraft>?> showInstrumentCatalogSheet(BuildContext context, {required String tenantType, List<Group> existingGroups = const [], List<CatalogGroupDraft> initialSelection = const [], bool allowCustom = true})`. Returns drafts only; no network writes. Empty list is a deliberate empty selection; null is cancel. Picker includes presets plus empty, search, family filter, selectable results with persistent selection, editable output names and custom entry.

- [ ] Test search/select/filter retention/cancel and distinct numbered voice selection before implementing.
- [ ] Reuse Rd sheet/form/list/choice styles. Existing groups marked; rename action enables explicit new voice. General tenant retains existing manual add path.
- [ ] Existing orchestral/choir plus calls picker and Task 2 importer under captured tenant/account/role and duplicate-submit guard; refresh groups/map/categories/counts in finally, and no stale navigation/toast.
- [ ] Create DE/EN fragment; run `dart run tool/i18n/build_arb.dart` and `flutter gen-l10n`.
- [ ] Verify phone width, increased text and dark/light palette in widget tests.

## Task 4: Tenant setup, documentation and integration

**Files:** `lib/features/tenant_selection/presentation/pages/tenant_create_page.dart`; related tests; `docs/beta/` matching scenario; `changelog/unreleased/instrument-catalog.json`.

- [ ] Add optional template/selection section to existing creation form; reuse picker drafts, clear incompatible selection on type change, preserve main leadership group separately.
- [ ] After tenant creation succeeds and has been selected, import drafts through repository bound to new ID. Distinguish creation failure from template failure; no duplicate tenant when only template application fails.
- [ ] Test the orchestral and choir setup, empty/custom path, selection-only failure and account switch.
- [ ] Add minor changelog and beta instructions with exact generated UI text.
- [ ] Run appropriate feature/repository/widget tests, `flutter analyze`, documentation checks, and broader suite once. Have independent reviewers assess behavior and Flutter/tenant correctness.
