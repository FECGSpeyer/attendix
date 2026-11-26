import 'package:flutter/material.dart';

/// Label text of a button in the app design.
String ionButtonText(BuildContext context, String text) => text;

/// CSS `text-transform: uppercase` for German labels on every platform.
String ionUppercase(String text) => text.toUpperCase().replaceAll('ß', 'SS');

/// Button label wrapper compatible with [AppAlertDialog] button extraction.
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

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;

  /// The equivalent plain [Text] for [context].
  Text toText(BuildContext context, {TextAlign? textAlign}) => Text(
        text,
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
        text,
        style: style,
        textAlign: textAlign,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
      );
}
