import 'package:flutter/material.dart';

import '../../../core/utils/haptic_helper.dart';
import 'adaptive_platform.dart';

/// IOS_LOOK: drop-in replacement for [SegmentedButton] (same parameters)
/// that renders like `ion-segment` ([IonSegment]): the neutral iOS
/// segmented control on iOS, the Ionic md tab-style segment elsewhere.
///
/// With `multiSelectionEnabled` the Material [SegmentedButton] is used
/// unchanged.
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
    // IOS_THEME2: single-select segments are Ionic segments in both modes
    // (iOS neutral control, md tab style); multi-select stays Material.
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

/// IOS_LOOK: `ion-segment` with a simple value API.
///
/// IOS_THEME2: renders like Ionic in both modes –
/// - iOS (ionic-theme-ios26): an uncoloured `ion-segment` is the neutral
///   system control: grey track (`rgba(text, .06)`, dark
///   `rgba(118,118,128,.24)`), white (dark #5a5a5f) selected pill, labels in
///   the text colour (13pt medium), 31pt high. Ionic has no coloured
///   segments; `neutral: false` gives `color="primary"` (primary 6.5 % track,
///   same white pill and text-colour labels).
/// - md (desktop / Android): the Ionic md segment – tab style, UPPERCASE
///   14pt medium labels, 60 % text colour, the checked one primary with a
///   2pt primary underline, no box or pill.
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

  /// `[scrollable]="true"`: segments keep their natural width and scroll.
  final bool scrollable;

  /// `ion-segment` without `color` (default, like every Ionic segment).
  /// false = `color="primary"` (iOS: primary-tinted track).
  final bool neutral;

  /// IOS_SHEETS: `ion-segment` inside an `ion-toolbar` (iOS): the control is
  /// only as wide as needed (all segments as wide as the widest label) and
  /// is centred by the caller instead of filling the row.
  final bool fitContent;

  /// iOS height (ionic-theme-ios26 `min-height: 31px`).
  static const double height = 31;

  /// md height (`ion-segment-button` md min-height 48px).
  static const double mdHeight = 48;

  @override
  Widget build(BuildContext context) {
    if (!useIosLook(context)) return _buildMd(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final labelColor = theme.colorScheme.onSurface;
    final trackColor = !neutral
        ? theme.colorScheme.primary.withValues(alpha: 0.065)
        : (dark ? const Color(0x3D767680) : const Color(0x0F000000));
    final pillColor = dark ? const Color(0xFF5A5A5F) : Colors.white;

    Widget segment(IonSegmentItem<T> item) {
      final checked = item.value == value;
      final enabled = item.enabled && onChanged != null;
      Widget child = DefaultTextStyle.merge(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: labelColor,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: labelColor, size: 18),
          child: item.label ?? item.icon ?? const SizedBox.shrink(),
        ),
      );
      child = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        constraints: const BoxConstraints(minWidth: 65),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: checked ? pillColor : Colors.transparent,
          borderRadius: BorderRadius.circular(height),
          boxShadow: checked && !dark
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: child,
      );
      // ios26: disabled segment buttons opacity .2
      child = Opacity(opacity: enabled ? 1 : 0.2, child: child);
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
          scrollable ? segment(i) : Expanded(child: segment(i)),
      ],
    );

    final track = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: scrollable
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
          : row,
    );
    // Equal-width segments as wide as the widest label (Row intrinsic width
    // with flex children = widest child × count).
    return fitContent && !scrollable ? IntrinsicWidth(child: track) : track;
  }

  /// Ionic md `ion-segment`: tab-style buttons with an underline indicator.
  Widget _buildMd(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final text = theme.colorScheme.onSurface;

    Widget segment(IonSegmentItem<T> item) {
      final checked = item.value == value;
      final enabled = item.enabled && onChanged != null;
      final color = checked ? primary : text.withValues(alpha: 0.6);
      final label = item.label;
      final content = IconTheme.merge(
        data: IconThemeData(color: color, size: 24),
        child: DefaultTextStyle.merge(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.84,
            color: color,
          ),
          child: label == null
              ? (item.icon ?? const SizedBox.shrink())
              : (label is Text && label.data != null
                  ? Text(
                      label.data!.toUpperCase(),
                      style: label.style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : label),
        ),
      );
      Widget child = Container(
        constraints: const BoxConstraints(minWidth: 90, minHeight: mdHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: checked ? primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: content,
      );
      child = Opacity(opacity: enabled ? 1 : 0.3, child: child);
      child = InkWell(
        onTap: enabled && !checked ? () => onChanged!(item.value) : null,
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

    final natural = scrollable || fitContent;
    final row = Row(
      mainAxisSize: natural ? MainAxisSize.min : MainAxisSize.max,
      children: [
        for (final i in items) natural ? segment(i) : Expanded(child: segment(i)),
      ],
    );
    return Material(
      type: MaterialType.transparency,
      child: scrollable
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
          : row,
    );
  }
}
