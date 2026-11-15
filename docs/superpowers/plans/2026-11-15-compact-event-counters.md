# Compact Event Counters Implementation Plan

> Execute inline using superpowers:executing-plans.

**Goal:** Remove zero-value gaps from the next-event card and keep its reminder adjacent to the open count.

**Architecture:** Reuse the flow mode of `RdStatusCounters`, with an optional trailing action grouped with the last visible counter. The next-event card selects flow mode and supplies the existing reminder.

**Tech Stack:** Flutter, Riverpod, existing localization.

**Spec:** `docs/superpowers/specs/2026-11-15-compact-event-counters-design.md`

## Global Constraints
Preserve list columns, reminder filtering/permissions, accessibility, loading height and navigation. Use existing translations; no backend, dependency or version changes.

## Review Focus
Zero late/excused counts; all answered versus no participants; narrow screens and enlarged text; screen-reader access to reminders; filtered reminder recipients.

### Task 1: Compact next-event status and reminder

**Files:** `lib/features/redesign/presentation/widgets/rd_widgets.dart`, `lib/features/redesign/presentation/widgets/today/rd_leader_today.dart`, `test/features/redesign/rd_shell_today_test.dart`, `changelog/unreleased/compact-event-counters.json`.

- [ ] Add regression coverage for visible geometry without empty columns, adjacent reminder, narrow/enlarged rendering and zero states. Verify the regression fails before the fix.
- [ ] Add an optional trailing action to the counter flow without swallowing its semantics. Switch the next-event card to flow and existing localized zero-state labels.
- [ ] Run the shell/today, palette and reminder widget tests plus targeted Dart analysis; inspect the diff and obtain a read-only review.
- [ ] Add the patch changelog, commit and push `codex/compact-event-counters`.
