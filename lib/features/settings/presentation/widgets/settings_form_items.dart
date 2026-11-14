import 'package:flutter/material.dart';

import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../shared/widgets/adaptive/ion_md_stacked_item.dart';
import '../../../../shared/widgets/layout/ionic_md.dart';
import 'settings_list.dart';

// Classic-design form rows of the settings pages (EIA-15, EIA-22): the iOS
// look and the Beta design keep [IonStackedField] / [IonStackedValue]
// exactly as before, the md look gets the Ionic md stacked row
// ([IonMdStackedField]) instead of the boxed Material field.

bool _keepLegacy(BuildContext context) =>
    context.rdSkin != null || ionIsIos(context);

/// `ion-item` + `ion-input labelPlacement="stacked"` in both looks.
/// Same API as [IonStackedField].
class SettingsStackedField extends StatelessWidget {
  const SettingsStackedField({
    super.key,
    this.label,
    this.helper,
    this.hint,
    required this.builder,
    this.flush = false,
  });

  final String? label;
  final String? helper;
  final String? hint;
  final bool flush;
  final Widget Function(InputDecoration decoration) builder;

  @override
  Widget build(BuildContext context) {
    if (_keepLegacy(context)) {
      return IonStackedField(
        label: label,
        helper: helper,
        hint: hint,
        flush: flush,
        builder: builder,
      );
    }
    return IonMdStackedField(
      label: label,
      helper: helper,
      hint: hint,
      flush: flush,
      builder: builder,
    );
  }
}

/// Stacked label + read-only value in both looks. Same API as
/// [IonStackedValue].
class SettingsStackedValue extends StatelessWidget {
  const SettingsStackedValue({
    super.key,
    required this.label,
    required this.value,
    this.helper,
    this.onTap,
    this.trailing,
    this.flush = false,
  });

  final String label;
  final String value;
  final String? helper;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool flush;

  @override
  Widget build(BuildContext context) {
    if (_keepLegacy(context)) {
      return IonStackedValue(
        label: label,
        value: value,
        helper: helper,
        onTap: onTap,
        trailing: trailing,
        flush: flush,
      );
    }
    return IonMdStackedValue(
      label: label,
      value: value,
      helper: helper,
      onTap: onTap,
      trailing: trailing,
      flush: flush,
    );
  }
}

/// Ionic `ion-input type="number" labelPlacement="start" class="ion-text-end"`
/// in an `ion-item` (EIA-22): label at the start, the borderless number
/// right-aligned at the end of the row. Classic design only.
class SettingsNumberItem extends StatelessWidget {
  const SettingsNumberItem({
    super.key,
    required this.label,
    required this.controller,
    this.placeholder,
    this.onChanged,
    this.helper,
  });

  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    final b = Theme.of(context).brightness;
    final text = ios ? IonIos.text(context) : IonMd.text(b);
    final fontSize = ios ? IonIos.itemFontSize : IonMd.itemFontSize;
    final style = TextStyle(fontSize: fontSize, letterSpacing: 0, color: text);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: ios ? IonIos.itemMinHeight : IonMd.itemMinHeight,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ios ? IonIos.itemPaddingStart : IonMd.itemPaddingStart,
          8,
          ios ? IonIos.itemPaddingEnd : IonMd.itemPaddingEnd,
          8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: style),
                  if (helper != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        helper!,
                        style: TextStyle(
                          fontSize: 12,
                          color: ios
                              ? IonStackedField.iosHelper
                              : IonMd.step550(b),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 72,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                style: style,
                onChanged: onChanged,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  hintText: placeholder,
                  hintStyle: style.copyWith(
                    color: ios ? IonIos.note(context) : text.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
