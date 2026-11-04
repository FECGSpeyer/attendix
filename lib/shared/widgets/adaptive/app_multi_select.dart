import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'adaptive_platform.dart';
import 'app_dialog.dart';
import 'app_select.dart';

/// Ionic `ion-select multiple` with its default `interface="alert"`: an
/// alert with one checkbox per option and "Abbrechen" / "OK" (same dialog as
/// the Termintyp "Verfügbare Status" and the Export "Felder" select).
///
/// Returns the checked values in option order, or null when cancelled.
Future<List<T>?> showAppMultiSelect<T>({
  required BuildContext context,
  required List<AppSelectOption<T>> options,
  required List<T> values,
  String? header,
}) async {
  final selected = {...values};
  final result = await showAppDialog<Set<T>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AppAlertDialog(
        title: header == null ? null : Text(header),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in options)
                CheckboxListTile(
                  title: Text(o.textOr('')),
                  value: selected.contains(o.value),
                  onChanged: !o.enabled
                      ? null
                      : (v) => setLocal(() {
                            v == true ? selected.add(o.value) : selected.remove(o.value);
                          }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, selected),
            child: Text(ctx.l10n.commonOk),
          ),
        ],
      ),
    ),
  );
  if (result == null) return null;
  return [for (final o in options) if (result.contains(o.value)) o.value];
}

/// Form field for an Ionic `ion-select multiple`: the [decoration] label,
/// the selected labels comma separated (Ionic's display text) or the
/// [placeholder], and the select icon (iOS `chevron-expand`, Material ▾ –
/// like [AppDropdownFormField]). Tapping opens [showAppMultiSelect].
class AppMultiSelectFormField<T> extends StatelessWidget {
  const AppMultiSelectFormField({
    super.key,
    required this.options,
    required this.values,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.placeholder,
    this.header,
  });

  final List<AppSelectOption<T>> options;
  final List<T> values;
  final ValueChanged<List<T>> onChanged;
  final InputDecoration decoration;

  /// Ionic `placeholder`, shown while nothing is selected.
  final String? placeholder;

  /// Alert header (default: the decoration's label).
  final String? header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = useIosLook(context);
    final text = [
      for (final o in options)
        if (values.contains(o.value)) o.textOr(''),
    ].join(', ');
    final style = (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(fontSize: 16);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final picked = await showAppMultiSelect<T>(
          context: context,
          options: options,
          values: values,
          header: header ?? decoration.labelText,
        );
        if (picked != null) onChanged(picked);
      },
      child: Semantics(
        button: true,
        child: InputDecorator(
          decoration: decoration.applyDefaults(theme.inputDecorationTheme),
          isEmpty: text.isEmpty && placeholder == null,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text.isNotEmpty ? text : (placeholder ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.isNotEmpty ? style : style.copyWith(color: theme.hintColor),
                ),
              ),
              const SizedBox(width: 6),
              if (ios) const IonSelectIcon() else Icon(Icons.arrow_drop_down, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }
}
