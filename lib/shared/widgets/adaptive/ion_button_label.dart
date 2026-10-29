import 'package:flutter/material.dart';

import 'adaptive_platform.dart';

/// MD_BUTTONS: label text of an `ion-button` in the current Ionic mode.
///
/// Ionic md (`button.md.css`): `text-transform: uppercase` (with 14px / 500
/// and `letter-spacing: .06em`, set by the md button theme) – on every
/// `ion-button`, toolbar text buttons (`ion-buttons > ion-button`)
/// included. Ionic iOS keeps the text as written. CSS uppercasing uses the
/// full Unicode mapping (`ß` → `SS`); [String.toUpperCase] does that on the
/// web (JS) but keeps `ß` on the Dart VM, so it is mapped explicitly.
String ionButtonText(BuildContext context, String text) =>
    useIosLook(context) ? text : ionUppercase(text);

/// CSS `text-transform: uppercase` for German labels on every platform.
String ionUppercase(String text) => text.toUpperCase().replaceAll('ß', 'SS');

/// MD_BUTTONS: drop-in replacement for the [Text] label of a Material
/// button that stands for an Ionic `ion-button`: UPPERCASE in md (Android,
/// desktop), unchanged on iOS (see [ionButtonText]).
///
/// Do not use it for things that are no `ion-button` in Ionic: item rows,
/// action-sheet / popover entries, tab labels, chips, links, plain
/// `<button>`s, the back button or `ion-datetime-button` values.
class IonButtonLabel extends StatelessWidget {
  const IonButtonLabel(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
  });

  /// The label as written (Ionic iOS); md shows it uppercased.
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;

  /// The equivalent plain [Text] for [context] – used where a parent
  /// inspects its child as a [Text] (alert button conversion).
  Text toText(BuildContext context, {TextAlign? textAlign}) => Text(
        ionButtonText(context, text),
        key: key,
        style: style,
        textAlign: textAlign ?? this.textAlign,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
      );

  @override
  Widget build(BuildContext context) => Text(
        ionButtonText(context, text),
        style: style,
        textAlign: textAlign,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
      );
}
