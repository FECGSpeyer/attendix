import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/adaptive/adaptive_platform.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart' as ios27;
import '../../../people/presentation/widgets/ion/ion_widgets.dart' show ionLineColor;

/// Classic design: an Ionic `ion-item` holding an `ion-input` /
/// `ion-textarea` with `labelPlacement="stacked"` – the label (scaled to
/// .75) above a borderless input, the item line below. Same in both looks
/// apart from the Ionic font sizes (iOS 17 / md 16), so the md look no
/// longer gets a Material floating-label or outlined field.
///
/// [lineInset]: true = the inset item line of an `ion-list` (starts at the
/// label), false = `lines="full"`; [line] false = `lines="none"`.
class IonStackedField extends StatelessWidget {
  const IonStackedField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hintText,
    this.helperText,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.sentences,
    this.onChanged,
    this.onSubmitted,
    this.line = true,
    this.lineInset = true,
    this.autofocus = false,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;

  /// Ionic `helperText` (small grey text under the input).
  final String? helperText;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool line;
  final bool lineInset;
  final bool autofocus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final fontSize = ios ? ios27.IonIos.itemFontSize : 16.0;
    final border = line
        ? Border(
            bottom: BorderSide(
              color: ionLineColor(context),
              width: ios ? 0.55 : 1,
            ),
          )
        : null;
    final content = Container(
      decoration: BoxDecoration(border: lineInset ? border : null),
      padding: EdgeInsetsDirectional.only(
        start: lineInset ? 0 : 16,
        end: 16,
        top: 10,
        bottom: helperText == null ? 2 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // `.label-text-wrapper` of a stacked label: scale(.75).
          Text(
            label,
            style: TextStyle(fontSize: fontSize * 0.75, color: onSurface),
          ),
          TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            enabled: enabled,
            minLines: minLines,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            onTapOutside: focusNode == null ? null : (_) => focusNode!.unfocus(),
            style: TextStyle(fontSize: fontSize, color: onSurface),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              hintText: hintText,
              hintStyle: TextStyle(
                fontSize: fontSize,
                color: onSurface.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          if (helperText != null)
            Text(
              helperText!,
              style: const TextStyle(fontSize: 12, color: AppColors.medium),
            ),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(border: lineInset ? null : border),
      padding: EdgeInsetsDirectional.only(start: lineInset ? 16 : 0),
      child: content,
    );
  }
}
