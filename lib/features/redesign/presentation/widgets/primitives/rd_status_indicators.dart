import 'package:flutter/material.dart';

import '../../../../../core/theme/redesign/rd_theme.dart';

/// Design-system attendance/status visualization widgets: proportional bars
/// and aligned status counters.

/// One coloured part of a [RdStatusBar].
class RdBarSegment {
  const RdBarSegment(this.value, this.color);
  final int value;
  final Color color;
}

/// Thin bar with the share of each status ("24 zugesagt, 3 entschuldigt").
class RdStatusBar extends StatelessWidget {
  const RdStatusBar({
    super.key,
    required this.segments,
    required this.total,
    required this.semanticLabel,
  });

  final List<RdBarSegment> segments;
  final int total;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 8,
          child: LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth;
              return Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: p.track)),
                  // Positioned.fill + stretch: a non-positioned Row gets
                  // loose constraints and its segments would be 0 px high.
                  if (total > 0)
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final s in segments)
                            if (s.value > 0)
                              SizedBox(
                                width: width * s.value / total,
                                child: ColoredBox(color: s.color),
                              ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One number and label of [RdStatusCounters].
class RdCounter {
  const RdCounter(
    this.value,
    this.label,
    this.color, {
    this.shortLabel,
    this.always = false,
    this.onTap,
    this.tapKey,
  });

  final int value;
  final String label;
  final Color color;

  /// Used when the columns are too narrow for [label] ("entsch.").
  final String? shortLabel;

  /// Shown at 0 as well ("0 zugesagt" is the news then).
  final bool always;
  final VoidCallback? onTap;
  final Key? tapKey;

  bool get visible => always || value > 0;
}

/// The answers of a Termin as numbers with their word below, instead of
/// the status bar: a full bar said nothing and one sign-out was a few
/// pixels. A 0 is left out.
///
/// [columns] (lists): every counter keeps its column and a 0 leaves it
/// empty, so the same number sits at the same place in every card.
/// Otherwise (a single card) the numbers stand next to each other.
/// [inline] places smaller numbers beside their labels and wraps whole
/// counters when space is limited.
class RdStatusCounters extends StatelessWidget {
  const RdStatusCounters({
    super.key,
    required this.counters,
    required this.semanticLabel,
    this.columns = false,
    this.inline = false,
    this.trailing,
  }) : assert(!columns || trailing == null),
       assert(!columns || !inline);

  final List<RdCounter> counters;
  final String semanticLabel;
  final bool columns;
  final bool inline;

  /// In flow mode, keep an action beside the last visible counter. Its
  /// semantics stay available separately from the counters' summary.
  final Widget? trailing;

  static const double _gap = 8;
  static const double _flowGap = 18;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    // With the inherited font: the columns are measured as they are drawn.
    final labelStyle = DefaultTextStyle.of(context).style
        .merge(RdType.meta(p, size: 12));
    final numberStyle = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        fontSize: inline ? 13 : 17,
        height: 1.2,
        fontWeight: inline ? FontWeight.w600 : FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final tappable = counters.any((c) => c.onTap != null);

    Widget cell(RdCounter c, String label) {
      final content = inline
          ? Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${c.value}\u00a0',
                    style: numberStyle.copyWith(color: c.color),
                  ),
                  TextSpan(text: label),
                ],
              ),
              style: labelStyle,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${c.value}',
                  maxLines: 1,
                  style: numberStyle.copyWith(color: c.color),
                ),
                Text(label, maxLines: 1, softWrap: false, style: labelStyle),
              ],
            );
      if (c.onTap == null) return content;
      return Semantics(
        button: true,
        label: '${c.value} ${c.label}',
        excludeSemantics: true,
        child: InkWell(
          key: c.tapKey,
          borderRadius: BorderRadius.circular(8),
          onTap: c.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              heightFactor: 1,
              child: content,
            ),
          ),
        ),
      );
    }

    Widget flow() {
      final visible = counters.where((c) => c.visible).toList();
      Widget flowCell(RdCounter c) => ExcludeSemantics(
        excluding: trailing != null && !tappable,
        child: cell(c, c.label),
      );
      return Wrap(
        spacing: inline ? 13 : _flowGap,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          for (final c in visible)
            if (c == visible.last && trailing != null)
              Wrap(
                spacing: _gap,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [flowCell(c), trailing!],
              )
            else
              flowCell(c),
          if (visible.isEmpty && trailing != null) trailing!,
        ],
      );
    }

    final Widget child;
    if (!columns) {
      child = flow();
    } else {
      child = LayoutBuilder(
        builder: (context, box) {
          // Columns need a width to share (not in a scrolling row).
          if (!box.hasBoundedWidth) return flow();
          final scaler = MediaQuery.textScalerOf(context);
          double measure(String text, TextStyle style) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: Directionality.of(context),
              textScaler: scaler,
              maxLines: 1,
            )..layout();
            final w = painter.width;
            painter.dispose();
            return w;
          }

          // A column is as wide as its word, at least three digits. The
          // widths depend on the words only, never on the numbers of one
          // card: cards with the same counters get the same columns.
          final digits = measure('000', numberStyle);
          double width(String label) {
            final w = measure(label, labelStyle);
            return w < digits ? digits : w;
          }

          // Full words when all columns fit, else the short ones.
          final full = [for (final c in counters) width(c.label)];
          final fits =
              full.fold<double>(0, (a, b) => a + b) +
                  _gap * (counters.length - 1) <=
              box.maxWidth;
          final labels = [
            for (final c in counters) fits ? c.label : c.shortLabel ?? c.label,
          ];
          final widths = fits ? full : [for (final l in labels) width(l)];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < counters.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(
                  // Each column as wide as its word needs, the rest shared.
                  flex: (widths[i] * 10).round().clamp(1, 100000),
                  child: counters[i].visible
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: cell(counters[i], labels[i]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          );
        },
      );
    }
    if (tappable) return child;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: trailing == null,
      explicitChildNodes: trailing != null,
      child: child,
    );
  }
}
