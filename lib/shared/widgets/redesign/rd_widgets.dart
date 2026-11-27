/// REDESIGN: building blocks of the design system (all colours come from the
/// active Farbwelt via `context.rd`).
///
/// Split by responsibility into cohesive modules under `primitives/`:
/// - [primitives/rd_surfaces.dart]: cards, grouped lists, rows, hint boxes, [RdPage]
/// - [primitives/rd_badges.dart]: tones, badges, pills, avatars, date tiles, headers
/// - [primitives/rd_buttons.dart]: primary/outline/circle/pill buttons, text & back links
/// - [primitives/rd_status_indicators.dart]: proportional status bars & aligned counters
/// - [primitives/rd_controls.dart]: segmented control, swipe switch, chips, scroller
/// - [primitives/rd_sheets.dart]: modal sheet wrapper, title, and selection checkmark
library;

export 'primitives/rd_badges.dart';
export 'primitives/rd_buttons.dart';
export 'primitives/rd_controls.dart';
export 'primitives/rd_sheets.dart';
export 'primitives/rd_status_indicators.dart';
export 'primitives/rd_surfaces.dart';
