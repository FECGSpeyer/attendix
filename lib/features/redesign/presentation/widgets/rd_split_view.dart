import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import 'today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: list and detail side by side on wide screens (canvas
/// "Desktop", "DesktopMitglieder"): Termine and Mitglieder keep their list
/// on the left while a Termin or a person opens on the right.

/// Window width from which the split is used (iPad landscape, desktop).
const double rdSplitBreakpoint = 1100;

/// Width of the list column.
const double rdSplitListWidth = 400;

bool rdUseSplit(BuildContext context) => MediaQuery.sizeOf(context).width >= rdSplitBreakpoint;

/// Tells a list or detail page that it sits inside [RdSplitView].
class RdSplitScope extends InheritedWidget {
  const RdSplitScope({
    super.key,
    required this.isDetail,
    this.selectedId,
    required super.child,
  });

  /// The right column (no back link: the list stays visible).
  final bool isDetail;

  /// Id of the item open on the right (highlighted in the list).
  final int? selectedId;

  static RdSplitScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RdSplitScope>();

  /// Opens [location] from a list row: in the split it replaces the detail
  /// (the list keeps its state), otherwise it is pushed.
  static void open(BuildContext context, String location) {
    if (of(context) != null) {
      context.go(location);
    } else {
      context.push(location);
    }
  }

  @override
  bool updateShouldNotify(RdSplitScope oldWidget) =>
      oldWidget.isDetail != isDetail || oldWidget.selectedId != selectedId;
}

class RdSplitView extends StatelessWidget {
  const RdSplitView({
    super.key,
    required this.list,
    required this.detail,
    required this.selectedId,
    required this.emptyText,
    this.emptyIcon = Icons.touch_app_outlined,
    this.empty,
  });

  final Widget list;

  /// null: nothing chosen yet ([emptyText] on the right).
  final Widget? detail;
  final int? selectedId;
  final String emptyText;
  final IconData emptyIcon;

  /// Shown instead of [emptyText] while nothing is chosen (an overview, so
  /// the wide column is not one sentence in a large empty box).
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return ColoredBox(
      color: p.bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: rdSplitListWidth,
            child: RdSplitScope(isDetail: false, selectedId: selectedId, child: list),
          ),
          VerticalDivider(width: 1, thickness: 1, color: p.line),
          Expanded(
            child: detail == null
                ? empty ?? Scaffold(
                    backgroundColor: p.bg,
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: RdInfoCard(text: emptyText, icon: emptyIcon),
                        ),
                      ),
                    ),
                  )
                : RdSplitScope(isDetail: true, selectedId: selectedId, child: detail!),
          ),
        ],
      ),
    );
  }
}
