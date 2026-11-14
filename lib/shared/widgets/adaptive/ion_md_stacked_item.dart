import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../layout/ionic_md.dart';

/// Ionic **md** `ion-item` with `ion-input labelPlacement="stacked"`
/// (EIA-15 / WER-04): the label sits small (16px × .75 = 12px) above the
/// value, the input itself has no box and no underline of its own – the
/// item line of the surrounding group separates the rows.
///
/// Use it inside an md inset group (e.g. `SettingsListSection`) wherever
/// the iOS look uses a stacked row. [builder] gets the decoration for the
/// `TextField` / `TextFormField` / select field:
///
/// ```dart
/// IonMdStackedField(
///   label: 'Name',
///   hint: 'Name eingeben',
///   builder: (decoration) => TextFormField(decoration: decoration),
/// )
/// ```
///
/// md only: the iOS look and the Beta design keep their own rows.
class IonMdStackedField extends StatelessWidget {
  const IonMdStackedField({
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

  /// No horizontal item padding (the parent already insets).
  final bool flush;

  final Widget Function(InputDecoration decoration) builder;

  /// md stacked label: 12px in `rgba(text, .6)`.
  static TextStyle labelStyle(BuildContext context) => TextStyle(
        fontSize: 12,
        height: 1.4,
        letterSpacing: 0,
        color: IonMd.text(Theme.of(context).brightness).withValues(alpha: 0.6),
      );

  /// md input helper text (`.input-bottom .helper-text`): 12px step-550.
  static TextStyle helperStyle(BuildContext context) => TextStyle(
        fontSize: 12,
        letterSpacing: 0,
        color: IonMd.step550(Theme.of(context).brightness),
      );

  /// The borderless decoration of an md stacked input.
  static InputDecoration decoration(
    BuildContext context, {
    String? hint,
    String? helper,
  }) {
    final b = Theme.of(context).brightness;
    return InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: IonMd.itemFontSize,
        letterSpacing: 0,
        color: IonMd.text(b).withValues(alpha: 0.6),
      ),
      helperText: helper,
      helperMaxLines: 4,
      helperStyle: helperStyle(context),
      errorStyle: const TextStyle(fontSize: 12, color: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = TextStyle(
      fontSize: IonMd.itemFontSize,
      letterSpacing: 0,
      color: IonMd.text(theme.brightness),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        flush ? 0 : IonMd.itemPaddingStart,
        10,
        flush ? 0 : IonMd.itemPaddingEnd,
        6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) Text(label!, style: labelStyle(context)),
          Theme(
            // ion-input md: 16px text without Material letter spacing.
            data: theme.copyWith(
              textTheme: theme.textTheme.copyWith(
                bodyLarge: theme.textTheme.bodyLarge?.merge(text) ?? text,
                titleMedium: theme.textTheme.titleMedium?.merge(text) ?? text,
              ),
            ),
            child: builder(decoration(context, hint: hint, helper: helper)),
          ),
        ],
      ),
    );
  }
}

/// Ionic **md** stacked `ion-label` + read-only value in an `ion-item`
/// (a stacked `ion-select` or an input that opens a picker): 12px label,
/// 16px value, optional 12px helper, [trailing] at the end of the row.
class IonMdStackedValue extends StatelessWidget {
  const IonMdStackedValue({
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
    final b = Theme.of(context).brightness;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: IonMd.itemMinHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            flush ? 0 : IonMd.itemPaddingStart,
            10,
            flush ? 0 : IonMd.itemPaddingEnd,
            10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: IonMdStackedField.labelStyle(context)),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: IonMd.itemFontSize,
                        letterSpacing: 0,
                        color: IonMd.text(b),
                      ),
                    ),
                    if (helper != null) ...[
                      const SizedBox(height: 4),
                      Text(helper!, style: IonMdStackedField.helperStyle(context)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: IonMd.endGap),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
