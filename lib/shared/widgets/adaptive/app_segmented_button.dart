import 'package:flutter/material.dart';

import '../../../core/theme/redesign/rd_theme.dart';

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
/// - iOS (IOS27_SWEEP, ionic-theme-ios27): an uncoloured `ion-segment` is
///   the flat system fill: track `rgba(medium, .11)` (dark
///   `rgba(medium, .19)`), radius 16, 32pt high; 28pt buttons (2pt
///   margin) with a pill indicator inset 2pt, white (dark
///   `color-mix(medium 59%, #000)`), no shadow; labels in the text colour,
///   0.81rem (13.77pt) medium. `neutral: false` gives `color="primary"`
///   (primary 6.5 % track, same pill and text-colour labels).
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
    this.forceMd = false,
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

  /// PARITY_R3: `<ion-segment mode="md">` – the md tab style on every
  /// platform (Ionic songs categories, export, members Einteilung).
  final bool forceMd;

  /// iOS height (ionic-theme-ios27 `min-height: 32px`).
  static const double height = 32;

  /// ios27 `ion-segment-button` font size (0.81rem).
  static const double iosFontSize = 0.81 * 17;

  /// ios27 track: `rgba(--ion-color-medium-rgb, .11)` (Ionic 9 medium
  /// #636469); dark `rgba(152,154,162,.19)`.
  static Color iosTrack(Brightness b) => b == Brightness.dark
      ? const Color(0xFF989AA2).withValues(alpha: 0.19)
      : const Color(0xFF636469).withValues(alpha: 0.11);

  /// ios27 indicator: `--ion-background-color` (white); dark
  /// `color-mix(in srgb, medium 59%, #000)`.
  static Color iosIndicator(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF5A5B60) : Colors.white;

  /// ios27 disabled segment buttons: opacity .2 (dark .15).
  static double iosDisabledOpacity(Brightness b) =>
      b == Brightness.dark ? 0.15 : 0.2;

  /// md `ion-segment-button` max-width.
  static const double mdButtonMaxWidth = 360;

  /// md height (`ion-segment-button` md min-height 48px).
  static const double mdHeight = 48;

  @override
  Widget build(BuildContext context) {
    // Beta-Skin: the segmented control of the new design on every platform
    // (grey track, white pill, bold selected label).
    final rd = context.rdSkin;
    if (rd == null && (forceMd || !useIosLook(context))) return _buildMd(context);
    final theme = Theme.of(context);
    final labelColor = rd?.text ?? theme.colorScheme.onSurface;
    final trackColor = rd?.track ??
        (!neutral
            ? theme.colorScheme.primary.withValues(alpha: 0.065)
            : iosTrack(theme.brightness));
    final pillColor = rd?.surface ?? iosIndicator(theme.brightness);

    Widget segment(IonSegmentItem<T> item) {
      final checked = item.value == value;
      final enabled = item.enabled && onChanged != null;
      Widget child = DefaultTextStyle.merge(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: rd != null ? 15 : iosFontSize,
          fontWeight: rd != null && checked ? FontWeight.w700 : FontWeight.w500,
          color: rd != null && !checked ? rd.text2 : labelColor,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: labelColor, size: 18),
          child: item.label ?? item.icon ?? const SizedBox.shrink(),
        ),
      );
      child = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        // button margin 2px 0 + indicator padding-inline 2px
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        constraints: const BoxConstraints(minWidth: 65 - 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: checked ? pillColor : Colors.transparent,
          borderRadius: BorderRadius.circular(rd != null ? 9 : height),
          boxShadow: rd != null && checked
              ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 3, offset: Offset(0, 1))]
              : null,
        ),
        child: child,
      );
      child = Opacity(
        opacity: enabled ? 1 : iosDisabledOpacity(theme.brightness),
        child: child,
      );
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
      height: rd != null ? 40 : height,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(rd != null ? 11 : height / 2),
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
        // MD_SWEEP: md segment-button hover primary .04, focus .12, no
        // pressed tint – the ripple in the label colour.
        hoverColor: primary.withValues(alpha: 0.04),
        focusColor: primary.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        splashColor: color.withValues(alpha: 0.16),
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
          : natural
              ? row
              // PARITY_R3: md `ion-segment-button { max-width: 360px }` –
              // on wide screens the buttons stay 360 wide, centred.
              : Center(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: mdButtonMaxWidth * items.length),
                    child: row,
                  ),
                ),
    );
  }
}
