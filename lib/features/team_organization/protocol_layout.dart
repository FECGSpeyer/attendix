/// Wide protocol layout (Ionic protocol.helpers.ts: column widths, next point).
library;

import 'dart:convert';

/// From this width on the leadership gets the three-column layout.
const double protocolWideBreakpoint = 900;
const double defaultSideWidth = 280;
const double minSideWidth = 160;

/// Upper bound for stored values; the real limit is the free space on screen.
const double maxSideWidth = 2000;
const double minMainWidth = 280;

/// Width of each drag handle between two columns.
const double resizerWidth = 8;

/// Preference key of the stored widths.
const String protocolColumnWidthsKey = 'protocol-column-widths';

typedef ColumnWidths = ({double left, double right});

const ColumnWidths defaultColumnWidths = (left: defaultSideWidth, right: defaultSideWidth);

/// Clamps one side column to at least [minSideWidth] while leaving the middle
/// column at least [minMainWidth], given the other side's width.
double clampSideWidth(double width, double otherSide, double containerWidth) {
  final room = containerWidth > 0 ? containerWidth - otherSide - minMainWidth - 2 * resizerWidth : maxSideWidth;
  final max = room.clamp(minSideWidth, maxSideWidth);
  return width.clamp(minSideWidth, max).roundToDouble();
}

/// Parses stored widths, falling back to the defaults for anything invalid.
ColumnWidths parseColumnWidths(String? raw) {
  bool ok(dynamic n) => n is num && n.isFinite && n >= minSideWidth && n <= maxSideWidth;
  try {
    final v = raw == null ? null : jsonDecode(raw);
    if (v is! Map) return defaultColumnWidths;
    return (
      left: ok(v['left']) ? (v['left'] as num).toDouble() : defaultSideWidth,
      right: ok(v['right']) ? (v['right'] as num).toDouble() : defaultSideWidth,
    );
  } catch (_) {
    return defaultColumnWidths;
  }
}

String encodeColumnWidths(ColumnWidths w) => jsonEncode({'left': w.left, 'right': w.right});

/// Id of the point after [currentId]; the first one without a selection,
/// null at the end.
String? nextSectionId(List<String> ids, String? currentId) {
  if (ids.isEmpty) return null;
  if (currentId == null) return ids.first;
  final i = ids.indexOf(currentId);
  if (i == -1) return ids.first;
  return i + 1 < ids.length ? ids[i + 1] : null;
}

/// Id of the point before [currentId], or null.
String? previousSectionId(List<String> ids, String? currentId) {
  final i = currentId == null ? -1 : ids.indexOf(currentId);
  return i > 0 ? ids[i - 1] : null;
}
