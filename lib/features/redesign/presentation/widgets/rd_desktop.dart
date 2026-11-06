import 'package:flutter/material.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import 'rd_split_view.dart';

/// REDESIGN: desktop rules (canvas "Beta: Desktop-UX").
///
/// * Lists with a detail keep the list on the left; the right side is never
///   empty and a wide detail shows its parts side by side.
/// * One "+" per area, in the list's header.
/// * Start pages (Heute) and the Verwaltung use the width in columns.

/// Width of the sidebar of the shell (from [rdSidebarBreakpoint]).
const double rdSidebarWidth = 248;

/// Window width from which the shell shows the sidebar.
const double rdSidebarBreakpoint = 840;

/// Width of a page's content area: the window minus sidebar and, in the
/// split's detail column, the list.
double rdContentWidth(BuildContext context) {
  var width = MediaQuery.sizeOf(context).width;
  if (width >= rdSidebarBreakpoint) width -= rdSidebarWidth;
  if (RdSplitScope.of(context)?.isDetail ?? false) width -= rdSplitListWidth + 1;
  return width;
}

/// A Termin shows Überblick and Anwesenheit next to each other from here.
const double rdSideBySideMinWidth = 900;

bool rdEventSideBySide(BuildContext context) => rdContentWidth(context) >= rdSideBySideMinWidth;

/// Two pages in one: the header over the full width, below it two columns
/// that scroll on their own (Termin: Überblick + Programm | Anwesenheit).
class RdEventColumns extends StatelessWidget {
  const RdEventColumns({
    super.key,
    required this.header,
    required this.left,
    required this.right,
    this.bottomPadding = 32,
    this.onRefresh,
  });

  final List<Widget> header;
  final List<Widget> left;
  final List<Widget> right;
  final double bottomPadding;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    Widget column(List<Widget> children) {
      final list = ListView(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomPadding),
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ],
      );
      return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...header,
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: column(left)),
                        const SizedBox(width: 28),
                        Expanded(flex: 6, child: column(right)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Heute (Leitung) in two columns from here on.
const double rdTodayColumnsMinWidth = 1000;

bool rdTodayColumns(BuildContext context) => rdContentWidth(context) >= rdTodayColumnsMinWidth;

/// Two columns from [minWidth] content width, else one below the other
/// (Heute: next Termin | what needs attention).
class RdDesktopColumns extends StatelessWidget {
  const RdDesktopColumns({
    super.key,
    required this.left,
    required this.right,
    this.minWidth = 960,
  });

  final List<Widget> left;
  final List<Widget> right;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < minWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [...left, ...right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 27,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left),
            ),
            const SizedBox(width: 28),
            Expanded(
              flex: 20,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right),
            ),
          ],
        );
      },
    );
  }
}
