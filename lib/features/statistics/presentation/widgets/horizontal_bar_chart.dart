import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Chart.js `plugins.title` of the Ionic stats charts: centered, bold, 12px,
/// grey (#666).
class StatsChartTitle extends StatelessWidget {
  const StatsChartTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : const Color(0xFF666666),
        ),
      ),
    );
  }
}

/// Axis title text (Chart.js `scales.*.title`).
TextStyle statsAxisTitleStyle(BuildContext context) => TextStyle(
  fontSize: 12,
  color:
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white70
          : const Color(0xFF666666),
);

/// One bar of a [StatsHorizontalBarChart].
typedef StatsBar = ({String label, double value});

/// PARITY_STATS: Ionic stats bar charts with `indexAxis: 'y'` – one
/// horizontal bar per entry, its name on the left at the bar, values along
/// the bottom axis (fixed [maxValue] like `x: { min: 0, max: 100 }`, else a
/// rounded maximum) with an optional axis title.
class StatsHorizontalBarChart extends StatelessWidget {
  const StatsHorizontalBarChart({
    super.key,
    required this.title,
    required this.bars,
    required this.color,
    this.maxValue,
    this.axisTitle,
    this.rowHeight = 28,
    this.minHeight = 250,
    this.labelWidth = 110,
    this.tooltip,
  });

  final String title;
  final List<StatsBar> bars;
  final Color color;

  /// Fixed axis maximum (e.g. 100 for %), otherwise derived from the data.
  final double? maxValue;
  final String? axisTitle;

  /// Ionic: `Math.max(min, entries * rowHeight)` px for the chart area.
  final double rowHeight;
  final double minHeight;
  final double labelWidth;
  final String Function(StatsBar bar)? tooltip;

  /// Chart.js-like "nice" axis: 0..max in about five steps of 1/2/5·10^n.
  static ({double max, double step}) niceAxis(double maxData) {
    if (maxData <= 0) return (max: 1, step: 1);
    final raw = maxData / 5;
    final magnitude =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final normalized = raw / magnitude;
    final niceNorm =
        normalized <= 1
            ? 1
            : normalized <= 2
            ? 2
            : normalized <= 5
            ? 5
            : 10;
    final step = math.max(1.0, niceNorm * magnitude);
    return (max: (maxData / step).ceil() * step, step: step);
  }

  @override
  Widget build(BuildContext context) {
    final dataMax = bars.fold<double>(0, (m, b) => math.max(m, b.value));
    final axis =
        maxValue != null
            ? (max: maxValue!, step: maxValue! / 5)
            : niceAxis(dataMax);
    final ticks = <double>[
      for (var v = 0.0; v <= axis.max + 0.0001; v += axis.step) v,
    ];
    final gridColor = Theme.of(context).dividerColor.withValues(alpha: 0.4);
    final labelStyle = TextStyle(
      fontSize: 11,
      color:
          Theme.of(context).brightness == Brightness.dark
              ? Colors.white70
              : const Color(0xFF666666),
    );
    // Chart area: Ionic chart height minus the title (≈ 30 px).
    final chartHeight = math.max(minHeight, bars.length * rowHeight) - 30;
    final barRowHeight = bars.isEmpty ? rowHeight : chartHeight / bars.length;

    String tickText(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatsChartTitle(title),
        SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: labelWidth,
                child: Column(
                  children: [
                    for (final bar in bars)
                      SizedBox(
                        height: barRowHeight,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              bar.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: labelStyle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return Stack(
                      children: [
                        for (final t in ticks)
                          Positioned(
                            // max(0, …): no throw while the area is < 1 px
                            left: (t / axis.max * width).clamp(
                              0,
                              math.max(0, width - 1),
                            ),
                            top: 0,
                            bottom: 0,
                            child: Container(width: 1, color: gridColor),
                          ),
                        Column(
                          children: [
                            for (final bar in bars)
                              SizedBox(
                                height: barRowHeight,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Tooltip(
                                    message:
                                        tooltip?.call(bar) ??
                                        '${bar.label}: ${tickText(bar.value)}',
                                    triggerMode: TooltipTriggerMode.tap,
                                    child: Container(
                                      width:
                                          (bar.value / axis.max).clamp(
                                            0.0,
                                            1.0,
                                          ) *
                                          width,
                                      height: barRowHeight * 0.8,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Bottom axis: tick values under the grid lines.
        Padding(
          padding: EdgeInsets.only(left: labelWidth, top: 4),
          child: SizedBox(
            height: 14,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final t in ticks)
                      Positioned(
                        left: (t / axis.max * width) - 15,
                        width: 30,
                        child: Text(
                          tickText(t),
                          textAlign: TextAlign.center,
                          style: labelStyle,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        if (axisTitle != null)
          Padding(
            padding: EdgeInsets.only(left: labelWidth, top: 4),
            child: Text(
              axisTitle!,
              textAlign: TextAlign.center,
              style: statsAxisTitleStyle(context),
            ),
          ),
      ],
    );
  }
}

/// Ionic stats bar colours (Chart.js `backgroundColor`).
abstract final class StatsChartColors {
  static const top20 = Color(0xFF2DD36F);
  static const instrument = Color(0xFF3880FF);
  static const unexcused = Color(0xFFEB445A);
  static const avgAge = Color(0xFFFF9F0A);
}
