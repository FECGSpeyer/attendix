# Instrument Catalog Flow Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development.

**Goal:** Implement the approved three flow improvements without changing persistence or tenant boundaries.
**Architecture:** Shared picker returns drafts plus preset metadata; a shared explicit change dialog and pure merge helper serve both entry points. Setup offers presets directly.
**Tech Stack:** Flutter, Riverpod, existing Rd widgets, generated DE/EN localization.
**Spec:** docs/superpowers/specs/2026-11-26-instrument-catalog-flow-design.md

## Constraints and review focus
- Reuse current attached worktree; no push, merge or deploy.
- Preserve type-specific instruments/voices, curated synonyms and role/account/tenant guards.
- Canceled dialogs and account/type/tenant changes may not apply stale choices.
- Merge preserves renamed same-key parts and custom additions; distinct numbered parts stay distinct.
- Same preset and Without preset must never erase choices.
- Fit narrow screens and scaled type; keep existing form hierarchy.

## Task 1 — shared picker and merge (agent)
Files: catalog_selection.dart; instrument_catalog_sheet.dart; rd_groups_page.dart; related selection/sheet tests; instrument_catalog.json and redesign.json plus generated localization.
- [x] Add behavior regressions for preservation and explicit replace/cancel.
- [x] Implement interfaces in spec; adapt list caller and test helper.
- [x] Add all shared and setup localization, including corrected main-group hint.
- [x] Focused tests/analyze; commit only owned paths.

## Task 2 — setup and documentation (root)
Files: tenant_create_page.dart; tenant_catalog_setup_test.dart; beta docs and existing minor changelog.
- [x] Add direct preset controls after type; render selection name/count and pass metadata to/from picker.
- [x] Same preset no-op; merge/replace using shared helper/dialog; explicit confirmation before Later discards.
- [x] Scope checks after dialog; preserve empty/custom setup and existing import behavior.
- [x] Tests for direct templates, Later, scope changes and setup picker labels.
- [x] Update beta docs; render revised screens.

## Task 3 — review and verification
- [x] Independent review, fix reproduced findings.
- [x] Feature tests, changed-file analysis, localization/docs and diff checks.
- [x] Keep branch/worktree as local deliverable.

## Verification results
- 139 focused tests passed across instruments, tenant setup, authentication UI, management lists and localization.
- Changed production and test files: Dart analysis clean; localization and documentation text checks clean.
- Independent setup and integrated reviews completed. The equivalent-row finding and its deselected-name follow-up were reproduced, fixed and covered by regressions.
- Real Flutter screenshots inspected for setup, customization, preset switching and adding, including dark mode and narrow screens with enlarged text.
- Changes remain on the local branch and attached worktree.
