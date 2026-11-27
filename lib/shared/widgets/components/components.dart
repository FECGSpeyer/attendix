/// REDESIGN: building blocks of the design system (all colours come from the
/// active Farbwelt via `context.rd`).
///
/// Split by responsibility into cohesive modules under `primitives/`:
/// - [primitives/surfaces.dart]: cards, grouped lists, rows, hint boxes, [RdPage]
/// - [primitives/badges.dart]: tones, badges, pills, avatars, date tiles, headers
/// - [primitives/buttons.dart]: primary/outline/circle/pill buttons, text & back links
/// - [primitives/status_indicators.dart]: proportional status bars & aligned counters
/// - [primitives/controls.dart]: segmented control, swipe switch, chips, scroller
/// - [primitives/sheets.dart]: modal sheet wrapper, title, and selection checkmark
library;

export 'primitives/badges.dart';
export 'primitives/buttons.dart';
export 'primitives/controls.dart';
export 'primitives/sheets.dart';
export 'primitives/status_indicators.dart';
export 'primitives/surfaces.dart';
