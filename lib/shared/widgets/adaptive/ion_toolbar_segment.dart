import 'package:flutter/material.dart';

import '../../../core/utils/haptic_helper.dart';
import 'adaptive_platform.dart';
import 'app_segmented_button.dart';

/// IOS_ATT_PAGES: `ion-segment` inside an `ion-toolbar` (header) without a
/// colour, as Ionic renders it in iOS mode (IOS27_SWEEP, ionic-theme-ios27
/// `.in-toolbar`): the flat `rgba(medium, .11)` track (dark `.19`) with
/// radius 24, 48 pt high, 44 pt buttons (2 pt margin) with the pill
/// indicator inset 2 pt (white, dark `color-mix(medium 59%, #000)`, no
/// shadow), 0.94rem (15.98 pt) medium labels in the text colour; as wide as
/// its labels (equal segment widths, 8 pt label padding, min 65 pt each) and
/// centred in the 74 pt segment toolbar (theme `--min-height: 68px` + 3 pt
/// toolbar padding above and below) – IOS_R4.
///
/// Outside iOS it falls back to the full-width [IonSegment] (Material).
class IonToolbarSegment<T> extends StatelessWidget {
  const IonToolbarSegment({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.trackPadding = 0,
  });

  final List<IonSegmentItem<T>> items;
  final T? value;
  final ValueChanged<T>? onChanged;

  /// ATT_SPACING: page CSS `ion-segment { padding: 8px }` (Übersicht) – iOS
  /// pads the grey track around the buttons: 48 + 2 × 8 = 64pt high and
  /// 16pt wider, still centred in the 74pt toolbar (68 + 2 × 3).
  final double trackPadding;

  /// Height of the toolbar row that holds the segment.
  /// MD_SWEEP: md `ion-toolbar` 56px with the 48px segment centred.
  static double toolbarHeight(BuildContext context) =>
      useIosLook(context) ? 74 : 56;

  static const double _height = 48;

  /// ion-segment-button (ios27): `min-width: 65px`.
  static const double _minSegmentWidth = 65;

  /// ios27 `.in-toolbar { --border-radius: 24px }`.
  static const double _radius = 24;

  @override
  Widget build(BuildContext context) {
    if (!useIosLook(context)) {
      // MD_SWEEP: md ion-segment in a 56px toolbar (no toolbar padding),
      // the 48px buttons centred vertically.
      return SizedBox(
        height: toolbarHeight(context),
        width: double.infinity,
        child: Center(
          child: IonSegment<T>(items: items, value: value, onChanged: onChanged),
        ),
      );
    }

    final theme = Theme.of(context);
    final text = theme.colorScheme.onSurface;
    final track = IonSegment.iosTrack(theme.brightness);
    final pill = IonSegment.iosIndicator(theme.brightness);

    Widget segment(IonSegmentItem<T> item) {
      final checked = item.value == value;
      final enabled = item.enabled && onChanged != null;
      Widget child = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minWidth: _minSegmentWidth - 4),
        // button margin 2px 0 + indicator padding-inline 2px
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        // ios27 ion-segment-button --padding-start/end: 8px
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: checked ? pill : Colors.transparent,
          // 44pt pill inset 2pt in the 24pt-radius track
          borderRadius: BorderRadius.circular(_radius - 2),
        ),
        child: DefaultTextStyle.merge(
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            // ios27 `.in-toolbar ion-segment-button { font-size: .94rem }`
            fontSize: 0.94 * 17,
            fontWeight: FontWeight.w500,
            color: text,
          ),
          child: IconTheme.merge(
            data: IconThemeData(color: text, size: 20),
            child: item.label ?? item.icon ?? const SizedBox.shrink(),
          ),
        ),
      );
      child = Opacity(
        opacity: enabled ? 1 : IonSegment.iosDisabledOpacity(theme.brightness),
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
      return Semantics(
        button: true,
        selected: checked,
        enabled: enabled,
        child: child,
      );
    }

    // ATT_SPACING: fill the toolbar row so the track is centred in it like
    // Ionic (3pt toolbar padding + (68 − track) / 2). AppBar.bottom does not
    // stretch its child, which put the track at the bottom edge (≈18pt low).
    return SizedBox(
      height: toolbarHeight(context),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: _height + 2 * trackPadding,
            padding: EdgeInsets.all(trackPadding),
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(_radius),
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
      ),
    );
  }
}
