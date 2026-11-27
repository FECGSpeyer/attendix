# Ensemble Creation Guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Approved design and user go-ahead authorize continuous implementation.

**Goal:** Replace ensemble creation with the approved question-led three-step guide, using two steps for general groups.
**Architecture:** Keep TenantCreatePage and its final creation pipeline. Local step state retains shared identity fields and per-type catalog drafts. Reuse the catalogue picker and Rd design system.
**Tech Stack:** Flutter, Riverpod, go_router, existing DE/EN fragment generation.
**Spec:** docs/superpowers/specs/2026-11-27-ensemble-creation-guide-design.md

## Global Constraints
- Use the existing codex/instrument-catalog branch and worktree. Base 2cf2268f88a0062f1c32cd95cf187147ec87534e.
- No push, merge, deployment, live service writes, schema, repository, importer or permission changes.
- No Big Band preset; existing Eastern European folk preset includes Mandoline.
- Preserve all catalog merge/name/metadata and stale-scope behavior. Keep final tenant success independent of optional import failure.
- New copy in DE/EN fragments; generate ARB/Dart, never hand-edit generated localization.
- No version bump; update the existing instrument-catalog minor changelog only.
- Every subagent starts with max reasoning effort. Implementers do not spawn helpers/reviewers; root coordinates reviews.

## Review Focus
- Back and type switches retain drafts, but general-group creation cannot import hidden orchestra choices.
- Automatic short name stops changing after manual editing; blank and whitespace names cannot advance/submit.
- System Back navigates within the guide, busy creation cannot navigate or double-submit, last-step submission only.
- Account/tenant changes while async dialogs or creation are pending cannot apply stale choices/imports.
- 320px width, large text, keyboard and long German labels keep primary actions reachable; summary never hides mandatory editing.

### Task 1: Guide UI, local state, localization and behavior tests
**Files:** Own lib/features/tenant_selection/presentation/pages/tenant_create_page.dart; optionally a small private guide widget/helper under the same feature; test/features/tenant_selection/tenant_catalog_setup_test.dart; test/features/auth/ux_auth_ios_test.dart; l10n fragments and generated outputs. Do not modify root-owned docs/changelog/plan or shared catalog files.
**Interfaces:** Existing TenantCreatePage public API unchanged. Reuse showInstrumentCatalogSheet purpose setup, CatalogPickerResult, mergeCatalogDrafts and shared preset-change dialog. Existing creation/import pipeline stays intact. Keep current field keys; add rd-tenant-guide-next, rd-tenant-guide-back, rd-tenant-guide-create and rd-tenant-type-{orchestra,choir,general}. Main-group editing may reuse rd-tenant-new-main on its edit control. Preserve GoRouter.of(context).go(RedesignRoutes.today) spelling for existing source-parity assertions.
- [x] Write/run RED widget tests for step order, required type choice, dynamic questions, final-only writes, three/two steps, automatic acronym and manual override preservation, back navigation and active-type import isolation.
- [x] Implement the approved screens and state. Use selectable type cards, progress text, one large question, keyboard-safe scroll content and bottom actions. No preselected type. General groups skip instrumentation. Summary on final screen includes name/kürzel, active selection and editable default Leitung.
- [x] Retain instrument drafts per type; UI and system back preserve them. Returning orchestra -> choir -> orchestra restores its preset and custom entries. General creation imports none. Update existing setup tests to navigate the new flow, retaining prior import-failure, duplicate-create and stale-scope assertions.
- [x] Add generated DE/EN copy: question prompts, step progress, Andere Gruppe / Other group, Weiter / Next, Zurück / Back, contextual create actions, Leitung / Leadership, Leitungsgruppe / Leadership group, Ändern / Change, Selbst zusammenstellen / Choose instruments or voices. Reuse existing catalog copy where accurate. Remove the stale main-group hint that says choose instruments above from the new flow; unused localization can stay for other callers.
- [x] Tests cover default/edited leadership name submission, empty optional instrumentation, setup merge/reopen regression, same-preset preservation, custom-only setup, narrow/large-text operation, short-name Unicode/basic single-word inputs and no overwrite of a manual acronym.
- [x] Run flutter test --no-pub test/features/tenant_selection test/features/auth/ux_auth_ios_test.dart and changed-file analysis, then relevant catalog/l10n regression suite. Resolve tests meaningfully, not by weakening assertions.
- [x] Self-review and commit only owned paths using git commit --only. Report red/green evidence, changed files, commit and any concerns in the task report.

### Task 2: Documentation and rendered verification (root)
**Files:** docs/beta/szenarien/neu-dabei.md; existing changelog/unreleased/instrument-catalog.json; approved spec/plan. Render fixtures remain ignored and screenshots in the visualization output directory.
**Interfaces:** Read Task 1's final text and stable guide keys. No ownership overlap in source/tests/localization.
- [x] Update the onboarding scenario to type -> name -> optional instrumentation -> contextual create. Explain editable default leadership and preserved back navigation.
- [x] Update existing minor changelog. Check patrol_test for an actual creation scenario; adapt if one exists (initial search found only entrypoint coverage).
- [x] Render actual Flutter guide screens with fake providers, including orchestra, general final, dark and narrow/enlarged type. Inspect images and fix reproduced defects via Task 1 owner.
- [x] Run docs text check and diff check. Create concise screen overview; keep fixtures out of tracked code.

### Task 3: Review and final verification
- [x] Generate review package from the recorded base. Parallel independent reviews for Flutter/state/tenant boundaries and general spec/quality, with max effort. Use normal available reviewer agents for the roles because named custom plugins are not callable here.
- [x] Fix reproduced findings; scoped recheck as appropriate. Root runs final focused suite and changed-file analysis. Broaden only for a concrete concern.
- [x] Complete ledger/plan, commit root-owned docs and verify clean local worktree. No push/merge/deploy.

## Completion evidence — 2026-11-27
- Implementation completed natively after the delegated implementer could not access tools; the public page API and existing final creation/import pipeline are retained.
- RED/GREEN coverage verified for the guide, top-of-step scrolling, and rapid cancellation. The review found duplicate deferred cancellation could pop two routes or permit an immediate create; closing now locks actions while permitting the intended dismissal.
- Final focused Flutter suite: **153 passed** across instruments, tenant selection, authentication UX, management lists and localization. All **14 dedicated guide tests** pass.
- Changed-file Dart analysis: no issues. Strict beta-documentation text check and `git diff --check`: passed.
- Actual Flutter screens rendered and inspected for the three orchestral steps, general-group completion, dark choir setup and 320px/1.8x text. Header constraints and stacked footer actions keep controls readable; keyboard reachability is covered by a widget test.
- Independent Flutter and general reviews completed. The Flutter reviewer confirmed the cancellation fix and responsive layout. The machine-specific rendering harness has been removed from test discovery and retained only as ignored local tooling.
- Existing local branch and managed worktree retained as agreed. No additional integration decision is needed for this local-only scope. Verification is intentionally limited to relevant suites under the task's testing guidance.
