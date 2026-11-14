import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart';
import '../../../../shared/widgets/layout/ionic_md.dart' show IonMd;

/// Item lines of the Werke forms: inset 16 from the start to the end of the
/// row (Ionic `ion-item` inner border), 0.55pt iOS / 1px md.
BorderSide songItemLine(BuildContext context) {
  final b = Theme.of(context).brightness;
  return useIosLook(context)
      ? BorderSide(color: IonIos.line(b), width: 0.55)
      : BorderSide(color: IonMd.line(b), width: IonMd.lineWidth);
}

/// Frame of one Ionic `ion-item` in a Werke form: 16 start padding, the
/// minimum item height of the look and the inset item line below
/// (none with [lines] false, Ionic `lines="none"`).
class SongItemFrame extends StatelessWidget {
  const SongItemFrame({
    super.key,
    required this.child,
    this.lines = true,
    this.endPadding = 16,
    this.onTap,
  });

  final Widget child;
  final bool lines;
  final double endPadding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    Widget row = Container(
      constraints: BoxConstraints(minHeight: ios ? IonIos.itemMinHeight : IonMd.itemMinHeight),
      alignment: AlignmentDirectional.centerStart,
      padding: EdgeInsetsDirectional.only(end: endPadding),
      decoration: lines ? BoxDecoration(border: Border(bottom: songItemLine(context))) : null,
      child: child,
    );
    row = Padding(padding: const EdgeInsetsDirectional.only(start: 16), child: row);
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      splashFactory: ios ? NoSplash.splashFactory : null,
      child: row,
    );
  }
}

/// `ion-item` > `ion-input` with a stacked label: the label above, the
/// input below and the item line under both ([ionInputDecoration] draws the
/// line as the field's underline, from the label start to the row end).
class SongStackedInput extends StatelessWidget {
  const SongStackedInput({
    super.key,
    required this.controller,
    required this.label,
    this.helperText,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.sentences,
    this.minLines,
    this.maxLines = 1,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final decoration = ionInputDecoration(context, label: label, helperText: helperText);
    final pad = decoration.contentPadding?.resolve(TextDirection.ltr);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, top: 4),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        minLines: minLines,
        maxLines: maxLines,
        onSubmitted: onSubmitted,
        decoration: decoration.copyWith(
          // The line runs to the row end; the text keeps the item padding.
          contentPadding: EdgeInsets.fromLTRB(0, pad?.top ?? 6, 16, pad?.bottom ?? 10),
        ),
      ),
    );
  }
}

/// `ion-item` > `ion-toggle` (label start, toggle at the end).
class SongToggleItem extends StatelessWidget {
  const SongToggleItem({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.lines = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool lines;

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    return SongItemFrame(
      lines: lines,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(label, style: TextStyle(fontSize: ios ? IonIos.itemFontSize : IonMd.itemFontSize)),
            ),
          ),
          // The look decides, not the platform (`.adaptive` would draw the
          // Cupertino switch on macOS although the look is md).
          ios
              ? Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeTrackColor: AppColors.success,
                )
              : Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// `ion-item` > `ion-select [label]` (also `multiple`): the label at the
/// start, the display text (selected labels, comma separated) and the select
/// icon at the end. [onTap] opens the select interface.
class SongSelectItem extends StatelessWidget {
  const SongSelectItem({
    super.key,
    required this.label,
    required this.text,
    required this.onTap,
    this.lines = true,
    this.placeholder,
  });

  final String label;
  final String text;
  final VoidCallback? onTap;
  final bool lines;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    final size = ios ? IonIos.itemFontSize : IonMd.itemFontSize;
    final empty = text.isEmpty;
    return SongItemFrame(
      lines: lines,
      onTap: onTap,
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: size)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              empty ? (placeholder ?? '') : text,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: size,
                color: empty ? AppColors.medium : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ios ? const IonSelectIcon() : const IonMdSelectIcon(),
        ],
      ),
    );
  }
}
