import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'app_dialog.dart';

/// One option of an [AppAlertRadioGroup] / [AppAlertCheckboxGroup].
class AppAlertOption<T> {
  const AppAlertOption(
    this.value,
    this.label, {
    this.description,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? description;
  final bool enabled;
}

/// Radio selection content for an [AppAlertDialog].
class AppAlertRadioGroup<T> extends StatelessWidget
    implements AppAlertGroupContent {
  const AppAlertRadioGroup({
    super.key,
    this.message,
    required this.options,
    required this.groupValue,
    required this.onChanged,
    this.footer,
    this.beta,
  });

  final Widget? message;
  final List<AppAlertOption<T>> options;
  final T? groupValue;
  final ValueChanged<T> onChanged;
  final Widget? footer;
  final Widget? beta;

  @override
  String? get alertMessageText => switch (message) {
        final Text t => t.data,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final beta = this.beta;
    if (beta != null) return beta;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null) message!,
          for (final o in options)
            // ignore: deprecated_member_use
            RadioListTile<T>(
              value: o.value,
              // ignore: deprecated_member_use
              groupValue: groupValue,
              title: Text(o.label),
              subtitle: o.description == null ? null : Text(o.description!),
              // ignore: deprecated_member_use
              onChanged: o.enabled ? (_) => onChanged(o.value) : null,
            ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// Checkbox selection content for an [AppAlertDialog].
class AppAlertCheckboxGroup<T> extends StatelessWidget
    implements AppAlertGroupContent {
  const AppAlertCheckboxGroup({
    super.key,
    this.message,
    required this.options,
    required this.values,
    required this.onChanged,
    this.footer,
    this.beta,
  });

  final Widget? message;
  final List<AppAlertOption<T>> options;
  final Set<T> values;
  final void Function(T value, bool checked) onChanged;
  final Widget? footer;
  final Widget? beta;

  @override
  String? get alertMessageText => switch (message) {
        final Text t => t.data,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final beta = this.beta;
    if (beta != null) return beta;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null) message!,
          for (final o in options)
            CheckboxListTile(
              title: Text(o.label),
              subtitle: o.description == null ? null : Text(o.description!),
              value: values.contains(o.value),
              onChanged:
                  o.enabled ? (v) => onChanged(o.value, v == true) : null,
            ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// Alert dialog with multiple-choice checkboxes.
///
/// [canChange] may veto a change (e.g. "at least one stays checked").
Future<Set<T>?> showAppCheckboxAlert<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<AppAlertOption<T>> options,
  Iterable<T> initialValues = const [],
  String? confirmText,
  String? cancelText,
  bool Function(Set<T> current, T value, bool checked)? canChange,
}) {
  final selected = {...initialValues};
  return showAppDialog<Set<T>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AppAlertDialog(
        title: title == null ? null : Text(title),
        content: AppAlertCheckboxGroup<T>(
          message: message == null || message.isEmpty ? null : Text(message),
          options: options,
          values: selected,
          onChanged: (value, checked) {
            if (canChange != null && !canChange(selected, value, checked)) {
              return;
            }
            setLocal(() {
              checked ? selected.add(value) : selected.remove(value);
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(cancelText ?? ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, selected),
            child: Text(confirmText ?? ctx.l10n.commonOk),
          ),
        ],
      ),
    ),
  );
}
