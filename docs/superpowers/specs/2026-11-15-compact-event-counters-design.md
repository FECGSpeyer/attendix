# Compact next-event counters

Approved in the design discussion: remove empty slots from the next-event card while retaining the existing large numbers and labels. Keep zero confirmations visible; hide other zero counters. Place the reminder beside the open count and wrap at narrow widths. With participants and no open answers, show the existing localized answered hint. With no participants, show the existing localized empty state.

## Approaches

- Compact, visible counters (selected): removes gaps and reuses the existing flow layout.
- Fixed columns including muted zeroes: stable positions, but adds unneeded information.
- Status chips: smaller footprint, but makes the numbers less prominent.

## Constraints

Use existing Flutter widgets, colors and localized strings. Preserve reminder recipient filtering, permissions, loading height and navigation. Keep fixed columns available for event lists. No backend, dependency or version changes.
