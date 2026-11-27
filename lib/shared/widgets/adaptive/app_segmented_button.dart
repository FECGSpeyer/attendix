import 'package:flutter/material.dart';

import '../../../core/theme/design_theme.dart';
import '../../../core/utils/haptic_helper.dart';

/// Segmented control wrapper matching [SegmentedButton]'s API for single selection.
class AppSegmentedButton<T> extends StatelessWidget {
  const AppSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    this.onSelectionChanged,
    this.multiSelectionEnabled = false,
    this.emptySelectionAllowed = false,
    this.showSelectedIcon = true,
    this.style,
    this.expandedInsets,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;
  final bool multiSelectionEnabled;
  final bool emptySelectionAllowed;
  final bool showSelectedIcon;
  final ButtonStyle? style;
  final EdgeInsets? expandedInsets;

  @override
  Widget build(BuildContext context) {
    if (multiSelectionEnabled) {
      return SegmentedButton<T>(
        segments: segments,
        selected: selected,
        onSelectionChanged: onSelectionChanged,
        multiSelectionEnabled: multiSelectionEnabled,
        emptySelectionAllowed: emptySelectionAllowed,
        showSelectedIcon: showSelectedIcon,
        style: style,
        expandedInsets: expandedInsets,
      );
    }
    return IonSegment<T>(
      items: [
        for (final s in segments)
          IonSegmentItem<T>(
            value: s.value,
            label: s.label,
            icon: s.label == null ? s.icon : null,
            enabled: s.enabled,
            tooltip: s.tooltip,
          ),
      ],
      value: selected.isEmpty ? null : selected.first,
      onChanged: onSelectionChanged == null
          ? null
          : (v) {
              if (selected.contains(v)) {
                if (emptySelectionAllowed) onSelectionChanged!(<T>{});
                return;
              }
              onSelectionChanged!(<T>{v});
            },
    );
  }
}

/// One button of an [IonSegment].
class IonSegmentItem<T> {
  const IonSegmentItem({
    required this.value,
    this.label,
    this.icon,
    this.enabled = true,
    this.tooltip,
  });

  final T value;
  final Widget? label;

  /// Shown only when there is no label (icon-only segment buttons).
  final Widget? icon;
  final bool enabled;
  final String? tooltip;
}

/// Segmented control with rounded track and white pill indicator.
class IonSegment<T> extends StatelessWidget {
  const IonSegment({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.scrollable = false,
    this.neutral = true,
    this.fitContent = false,
  });

  final List<IonSegmentItem<T>> items;
  final T? value;
  final ValueChanged<T>? onChanged;

  final bool scrollable;
  final bool neutral;
  final bool fitContent;

  @override
  Widget build(BuildContext context) {
    final rd = context.rd;
    final brightness = Theme.of(context).brightness;
    final labelColor = rd.text;
    final trackColor = rd.track;
    final pillColor = rd.surface;
    final disabledOpacity = brightness == Brightness.dark ? 0.15 : 0.2;

    Widget segment(IonSegmentItem<T> item) {
      final checked = item.value == value;
      final enabled = item.enabled && onChanged != null;
      Widget child = DefaultTextStyle.merge(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: checked ? FontWeight.w700 : FontWeight.w500,
          color: !checked ? rd.text2 : labelColor,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: labelColor, size: 18),
          child: item.label ?? item.icon ?? const SizedBox.shrink(),
        ),
      );
      child = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        constraints: const BoxConstraints(minWidth: 65 - 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: checked ? pillColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: checked
              ? const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: child,
      );
      child = Opacity(
        opacity: enabled ? 1 : disabledOpacity,
        child: child,
      );
      final onTap = enabled && !checked
          ? () {
              HapticHelper.light();
              onChanged!(item.value);
            }
          : null;
      child = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        canRequestFocus: enabled,
        child: child,
      );
      if (item.tooltip != null) {
        child = Tooltip(message: item.tooltip!, child: child);
      }
      return Semantics(
        button: true,
        selected: checked,
        enabled: enabled,
        child: child,
      );
    }

    final row = Row(
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: [
        for (final i in items)
          scrollable ? segment(i) : Expanded(child: segment(i)),
      ],
    );

    final track = Container(
      height: 40,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(11),
      ),
      child: scrollable
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
          : row,
    );
    return fitContent && !scrollable ? IntrinsicWidth(child: track) : track;
  }
}
