import 'package:flutter/material.dart';

import '../../../core/utils/haptic_helper.dart';
import 'adaptive_platform.dart';
import 'app_segmented_button.dart';

/// IOS_ATT_PAGES: `ion-segment` inside an `ion-toolbar` (header) without a
/// colour, as Ionic renders it in iOS mode (ionic-theme-ios26 `.in-toolbar`):
/// neutral grey track (`rgba(text, .065)`), white selected pill with a soft
/// shadow, black 15 pt labels, 48 pt high, as wide as its labels (equal
/// segment widths, 13 pt label padding, min 70 pt each) and centred in the
/// 74 pt segment toolbar (theme `--min-height: 68px` + 3 pt toolbar padding
/// above and below) – IOS_R4.
///
/// Outside iOS it falls back to the full-width [IonSegment] (Material).
class IonToolbarSegment<T> extends StatelessWidget {
  const IonToolbarSegment({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final List<IonSegmentItem<T>> items;
  final T? value;
  final ValueChanged<T>? onChanged;

  /// Height of the toolbar row that holds the segment.
  static double toolbarHeight(BuildContext context) =>
      useIosLook(context) ? 74 : 52;

  static const double _height = 48;

  /// ion-segment-button (ios): `min-width: 70px`.
  static const double _minSegmentWidth = 70;

  @override
  Widget build(BuildContext context) {
    if (!useIosLook(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: SizedBox(
          width: double.infinity,
          child: IonSegment<T>(items: items, value: value, onChanged: onChanged),
        ),
      );
    }

    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final text = theme.colorScheme.onSurface;
    // IOS_THEME2: ionic-theme-ios26 track rgba(text, .06) / dark
    // rgba(118,118,128,.24), indicator background / dark #5a5a5f.
    final track = dark ? const Color(0x3D767680) : const Color(0x0F000000);
    final pill = dark ? const Color(0xFF5A5A5F) : Colors.white;

    Widget segment(IonSegmentItem<T> item) {
      final checked = item.value == value;
      final enabled = item.enabled && onChanged != null;
      Widget child = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minWidth: _minSegmentWidth),
        margin: const EdgeInsets.symmetric(vertical: 2),
        // ion-segment-button (ios) --padding-start/end: 13px
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: checked ? pill : Colors.transparent,
          borderRadius: BorderRadius.circular(_height / 2),
          boxShadow: checked && !dark
              ? const [
                  BoxShadow(color: Color(0x0F000000), blurRadius: 5, offset: Offset(0, 2)),
                  BoxShadow(color: Color(0x0F000000), spreadRadius: 0.5),
                ]
              : null,
        ),
        child: DefaultTextStyle.merge(
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            // ios27 `.in-toolbar ion-segment-button { font-size: .94rem }`
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: text,
          ),
          child: IconTheme.merge(
            data: IconThemeData(color: text, size: 20),
            child: item.label ?? item.icon ?? const SizedBox.shrink(),
          ),
        ),
      );
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
      return Semantics(
        button: true,
        selected: checked,
        enabled: enabled,
        child: child,
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: _height,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(_height / 2),
          ),
          // Equal segment widths, sized by the widest label.
          child: IntrinsicWidth(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final i in items) Expanded(child: segment(i))],
            ),
          ),
        ),
      ),
    );
  }
}
