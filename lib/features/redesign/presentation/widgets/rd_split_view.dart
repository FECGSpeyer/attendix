import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import 'rd_widgets.dart' show RdBackLink, RdPage, rdIsPushed;
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
                // A short card at the top (not one sentence in a large box).
                ? empty ?? RdPage(children: [RdInfoCard(text: emptyText, icon: emptyIcon)])
                : RdSplitScope(isDetail: true, selectedId: selectedId, child: detail!),
          ),
        ],
      ),
    );
  }
}

/// REDESIGN: "‹ Verwaltung" on a page of the Verwaltung. On the right of
/// the Verwaltung list (wide screens) it is left out, like on a person or a
/// Werk next to its list: the list's own back link leads on (a pushed
/// Verwaltung there says "‹ Zurück" and pops back to where it came from).
class RdManageBackLink extends StatelessWidget {
  const RdManageBackLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (RdSplitScope.of(context)?.isDetail ?? false) return const SizedBox(height: 44);
    return RdBackLink(label: label, onTap: onTap);
  }
}

/// Opens a page of the Verwaltung from its list on wide screens: it takes
/// the place on the right, the list keeps its state. When the Verwaltung was
/// pushed from elsewhere (a picker, the Mitglieder •••), the next page is
/// pushed too: the page below stays and its `await push` still returns
/// when the user goes back.
void rdManageSplitOpen(BuildContext context, String location) {
  if (rdIsPushed(context)) {
    context.push(location);
  } else {
    context.go(location);
  }
}
