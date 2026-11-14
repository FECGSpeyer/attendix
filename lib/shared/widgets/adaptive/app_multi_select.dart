import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../core/theme/redesign/rd_theme.dart';
import '../../../l10n/l10n.dart';
import 'adaptive_platform.dart';
import 'app_alert_inputs.dart';
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
  if (context.rdSkin == null) {
    // Classic: the Ionic `.alert-checkbox-group` (checkbox at the start).
    final result = await showAppCheckboxAlert<T>(
      context,
      title: header,
      options: [
        for (final o in options)
          AppAlertOption<T>(o.value, o.textOr(''), enabled: o.enabled),
      ],
      initialValues: values,
    );
    if (result == null) return null;
    return [for (final o in options) if (result.contains(o.value)) o.value];
  }
  // Beta: unchanged.
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
/// like [AppDropdownFormField]). Tapping opens [showAppMultiSelect]; the
/// field is focusable with Tab and opens with Enter / Space (keyboard focus
/// shows the focused border of the decoration, no ripple).
class AppMultiSelectFormField<T> extends StatefulWidget {
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
  State<AppMultiSelectFormField<T>> createState() => _AppMultiSelectFormFieldState<T>();
}

class _AppMultiSelectFormFieldState<T> extends State<AppMultiSelectFormField<T>> {
  bool _focused = false;

  Future<void> _open() async {
    final picked = await showAppMultiSelect<T>(
      context: context,
      options: widget.options,
      values: widget.values,
      header: widget.header ?? widget.decoration.labelText,
    );
    if (picked != null) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = useIosLook(context);
    final text = [
      for (final o in widget.options)
        if (widget.values.contains(o.value)) o.textOr(''),
    ].join(', ');
    final placeholder = widget.placeholder;
    final style = (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(fontSize: 16);
    // InkWell for keyboard focus (Tab) and activation (Enter / Space); the
    // ink effects stay off so tapping looks like before.
    return Semantics(
      button: true,
      child: InkWell(
        onTap: _open,
        onFocusChange: (focused) => setState(() => _focused = focused),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: InputDecorator(
          decoration: widget.decoration.applyDefaults(theme.inputDecorationTheme),
          isFocused: _focused,
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
              if (ios) const IonSelectIcon() else Icon(AppIcons.arrowDropDown, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }
}
