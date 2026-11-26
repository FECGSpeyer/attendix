import 'package:flutter/material.dart';

import 'settings_list.dart';

/// `ion-item` + `ion-input labelPlacement="stacked"` row.
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
    return IonStackedField(
      label: label,
      helper: helper,
      hint: hint,
      flush: flush,
      builder: builder,
    );
  }
}

/// Stacked label + read-only value row.
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
    return IonStackedValue(
      label: label,
      value: value,
      helper: helper,
      onTap: onTap,
      trailing: trailing,
      flush: flush,
    );
  }
}
