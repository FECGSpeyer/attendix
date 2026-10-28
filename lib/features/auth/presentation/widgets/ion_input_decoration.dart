import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Metrics of one `ion-item lines="full"` with a stacked label on the Ionic
/// login card (login.page.scss: `--padding-start: 0`, primary-tinted 1px
/// line, 2px primary highlight on focus). Values measured on the Ionic
/// page in iOS mode (1rem = 17px on the iPhone) and md mode.
class IonStackedItemMetrics {
  const IonStackedItemMetrics({
    required this.labelSize,
    required this.labelHeight,
    required this.inputTop,
    required this.inputBottom,
    required this.inputSize,
  });

  /// Legacy `<ion-label position="stacked">` + `<ion-input>` (e-mail row).
  static IonStackedItemMetrics legacy({required bool ios}) => ios
      // iOS: label 14.9px (18 high), input 44 high 4 below → item 77.
      ? const IonStackedItemMetrics(
          labelSize: 14.875,
          labelHeight: 18,
          inputTop: 16,
          inputBottom: 12,
          inputSize: 17)
      // md: label scaled to 12px (15 high), input text centred → item 65.
      : const IonStackedItemMetrics(
          labelSize: 12,
          labelHeight: 15,
          inputTop: 7,
          inputBottom: 12,
          inputSize: 16);

  /// Modern `<ion-input label labelPlacement="stacked">` (password row):
  /// label scaled to 75 % (15 high), 36 high native input → item 57.
  static IonStackedItemMetrics modern({required bool ios}) =>
      IonStackedItemMetrics(
          labelSize: ios ? 12.75 : 12,
          labelHeight: 15,
          inputTop: 3,
          inputBottom: 8,
          inputSize: ios ? 17 : 16);

  final double labelSize;
  final double labelHeight;

  /// Space between the label and the input text line (20 high).
  final double inputTop;

  /// Space between the input text line and the item line.
  final double inputBottom;
  final double inputSize;

  /// Height of the input text line (`TextStyle.height` is set to match).
  static const double lineHeight = 20;

  /// `ion-item` top padding above the stacked label.
  static const double itemTop = 10;

  /// Vertical centre of an end-slot button, from the top of the item.
  static const double trailingCenter = 28;
}

/// IOS_LOOK: an Ionic login `ion-item lines="full"` with a stacked label:
/// label above the input, full-width bottom line (also below [trailing])
/// that turns into the 2px primary highlight while the input has focus.
class IonStackedItem extends StatefulWidget {
  const IonStackedItem({
    super.key,
    required this.label,
    required this.metrics,
    required this.builder,
    this.trailing,
    this.trailingSize = 40,
    this.indent = 0,
    this.lineColor,
    this.focusHighlight = true,
    this.placeholder,
  });

  final String label;

  /// Placeholder (defaults to [label], like the login inputs).
  final String? placeholder;
  final IonStackedItemMetrics metrics;

  /// `--padding-start` of the item (login card 0, ion-list items 16); the
  /// line still runs full width (`lines="full"`).
  final double indent;

  /// Item line colour (default: login card `rgba(primary, .3)`).
  final Color? lineColor;

  /// Show the 2px primary highlight while focused (iOS lists: none).
  final bool focusHighlight;

  /// Builds the input; [decoration] and [style] must be passed to the
  /// TextFormField so it lines up with the label and the item line.
  final Widget Function(InputDecoration decoration, TextStyle style) builder;

  /// End-slot button (e.g. the password eye), centred like Ionic.
  final Widget? trailing;
  final double trailingSize;

  @override
  State<IonStackedItem> createState() => _IonStackedItemState();
}

class _IonStackedItemState extends State<IonStackedItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.metrics;
    final textColor = theme.colorScheme.onSurface;
    final decoration = InputDecoration(
      hintText: widget.placeholder ?? widget.label,
      hintStyle: TextStyle(
        color: const Color(0xFF777777),
        fontSize: m.inputSize,
        height: IonStackedItemMetrics.lineHeight / m.inputSize,
        fontWeight: FontWeight.w400,
      ),
      isDense: true,
      filled: false,
      contentPadding: EdgeInsets.fromLTRB(
        0,
        m.inputTop,
        widget.trailing != null ? widget.trailingSize + 16 : 0,
        m.inputBottom,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
    );
    final style = TextStyle(
      fontSize: m.inputSize,
      height: IonStackedItemMetrics.lineHeight / m.inputSize,
      color: textColor,
    );
    final line = _focused && widget.focusHighlight
        ? const BorderSide(color: AppColors.primary, width: 2)
        : BorderSide(
            color: widget.lineColor ??
                AppColors.primary.withValues(alpha: 0.3));
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Container(
        // 1px line below the input; the 2px focus highlight is painted
        // over it (foreground) so the item height never changes.
        padding: EdgeInsets.only(
            left: widget.indent,
            top: IonStackedItemMetrics.itemTop,
            bottom: 1),
        foregroundDecoration: BoxDecoration(border: Border(bottom: line)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: m.labelHeight,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: m.labelSize,
                      height: m.labelHeight / m.labelSize,
                      color: textColor,
                    ),
                  ),
                ),
                // Ionic metrics are absolute: no compact desktop density.
                Theme(
                  data: theme.copyWith(visualDensity: VisualDensity.standard),
                  child: widget.builder(decoration, style),
                ),
              ],
            ),
            if (widget.trailing != null)
              Positioned(
                // end slot sits 16px inside the item edge when indented
                right: widget.indent > 0 ? 16 : 0,
                top: IonStackedItemMetrics.trailingCenter -
                    IonStackedItemMetrics.itemTop -
                    widget.trailingSize / 2,
                width: widget.trailingSize,
                height: widget.trailingSize,
                child: widget.trailing!,
              ),
          ],
        ),
      ),
    );
  }
}
