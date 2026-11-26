# Intuitive event creation implementation plan

> For agentic workers: execute independent components in parallel and review the integrated behavior.

**Goal:** Implement the approved event creation mockup and the approved plus-button choice in the existing Flutter app.

**Architecture:** Keep the existing AttendanceCreateWriter and configured AttendanceType model. Split meeting entry from regular event creation; use existing theme, adaptive pickers, permissions and route guards. A single bottom action remains visible outside the scrolling form and shows the number of events being created.

**Tech stack:** Flutter, Riverpod, GoRouter, generated German/English localization.

**Spec:** Approved type-first creation form and an anchored plus-button menu with separate regular-event and meeting entries. The primary action stays at the bottom.

## Constraints and decisions
- Keep date tile and existing card layout; approved inline attendance counts are a separate small UI refinement.
- Keep only one primary create action: bottom safe-area button, labeled Anlegen rather than Fertig because it creates records.
- Dynamic type names, no hard-coded Probe/Vortrag list. Protocol-enabled types enter via meeting choice.
- Preserve all-day/multiday, custom dates, holidays, deadlines, invitation filters, duties and existing permission checks. All-day is configured on the type; do not silently change a type globally from an event toggle.
- Preserve explicit title/time/place edits on type changes. Show templates as an optional explicit shortcut.
- Keep input locked and navigation guarded throughout asynchronous saving; prevent duplicate submissions.
- No database migrations or deployment required. Integrate through a reviewed pull request.

## Review focus
- Helpers must not gain meeting creation access.
- Empty or meeting-only type lists must have truthful states.
- A narrow phone, large text and the keyboard must leave the create action usable.
- Recurrences, all-day durations and duties must survive the new layout.
- Changing types and async data refresh must not overwrite manual input.

## Tasks
- [x] Plus menu: reusable anchored choice for mobile and desktop event entry, route to normal form or existing meeting flow; test choices and role restrictions. Owner: plus-menu agent; no edits to the event form.
- [x] Creation form: type-first layout, grouped date/time/repeat, optional templates/deadline/works, invitation summary and fixed bottom submit; test defaults preservation, protocol separation, responsive layouts and save state. Owner: root.
- [x] Card refinement: small inline counts with original date tile; verify existing alignment tests and narrow layout. Owner: card agent; no changes to event creation.
- [x] Integration: format, localization generation, targeted analyzer/tests, visual capture of actual Flutter widgets, fresh review and fixes. Owner: root.

## Implementation decisions and verification
- The single footer action says “Termin anlegen” (or the exact series count), which stays understandable for arbitrarily named types. The top bar has an accessible close action.
- Under very short keyboard/landscape layouts, secondary header/summary content collapses to keep the action and form reachable.
- User-entered time pairs remain together across type changes. Missing endpoints visibly adopt the new type's defaults so the displayed and saved times agree. Re-selecting the active type is a no-op, preserving duties and templates.
- The save path captures the draft before waiting, locks pointer and keyboard interaction immediately, and refuses to resume after an account/group switch.
- Works remain available for all musical types, as in the existing Beta product; its legacy flag synchronization is preserved.
- The final integrated targeted suite passed 289 tests, including creation, menu, counters, time rules, type flags, invitation circles, meeting helpers and event details.
- Actual Flutter widget screenshots were rendered with fixture data and real app fonts; the temporary capture test is removed before handoff.
- Final targeted analyzer: no issues across 11 changed source/test targets. Independent review reverified save focus lock, retained duty overrides and landscape keyboard layout; neutral empty-state copy resolves its remaining minor finding.
- Reviews and browser checks found an invisible time-default fallback after type changes and stale E2E selectors for creation and inline counters; these are fixed, with two time regression tests and updated H-10/B-02 Patrol selectors.
- All eight Linux golden comparisons pass after visually reviewing and updating only the intentional event-list image. Beta scenarios, strict app-text checks and the changelog fragment are updated. Full-library analysis passes with existing informational lints outside the changed files.
