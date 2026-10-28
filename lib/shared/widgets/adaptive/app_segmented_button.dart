import 'package:flutter/material.dart';

import '../../../core/utils/haptic_helper.dart';
import 'adaptive_platform.dart';

/// IOS_LOOK: drop-in replacement for [SegmentedButton] (same parameters)
/// that renders like `ion-segment` in iOS mode:
/// a soft primary-tinted track without border, the selected segment as a
/// primary-tint pill, primary semibold labels and no icons/check marks.
///
/// Outside iOS (or with `multiSelectionEnabled`) the Material
/// [SegmentedButton] is used unchanged.
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
    if (!useIosLook(context) || multiSelectionEnabled) {
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

/// One button of an [IonSegment] (`ion-segment-button`).
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

/// IOS_LOOK: `ion-segment` (iOS mode) with a simple value API.
///
/// On non-iOS platforms it renders a Material [SegmentedButton] without
/// check marks, so pages can use it unconditionally.
class IonSegment<T> extends StatelessWidget {
  const IonSegment({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.scrollable = false,
  });

  final List<IonSegmentItem<T>> items;
  final T? value;
  final ValueChanged<T>? onChanged;

  /// `[scrollable]="true"`: segments keep their natural width and scroll.
  final bool scrollable;

  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    if (!useIosLook(context)) {
      return SegmentedButton<T>(
        segments: [
          for (final i in items)
            ButtonSegment<T>(
              value: i.value,
              label: i.label,
              icon: i.label == null ? i.icon : null,
              enabled: i.enabled,
              tooltip: i.tooltip,
            ),
        ],
        selected: value == null ? <T>{} : {value as T},
        emptySelectionAllowed: value == null,
        showSelectedIcon: false,
        onSelectionChanged: onChanged == null
            ? null
            : (s) {
                if (s.isNotEmpty) onChanged!(s.first);
              },
      );
    }
    final primary = Theme.of(context).colorScheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget segment(IonSegmentItem<T> item) {
      final checked = item.value == value;
      final enabled = item.enabled && onChanged != null;
      Widget child = DefaultTextStyle.merge(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: primary, size: 20),
          child: item.label ?? item.icon ?? const SizedBox.shrink(),
        ),
      );
      child = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: checked
              ? primary.withValues(alpha: dark ? 0.32 : 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(height),
        ),
        child: child,
      );
      child = Opacity(opacity: enabled ? 1 : 0.4, child: child);
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled && !checked
            ? () {
                HapticHelper.light();
                onChanged!(item.value);
              }
            : null,
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
          scrollable
              ? ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 60),
                  child: segment(i),
                )
              : Expanded(child: segment(i)),
      ],
    );

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: dark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(height),
      ),
      child: scrollable
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
          : row,
    );
  }
}
