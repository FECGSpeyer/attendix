import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import 'adaptive_platform.dart';

/// Ionic `<ion-radio>` inside an `ion-item` (outside alerts) – the drop-in
/// for `RadioListTile`.
///
/// - iOS look: Ionic iOS has no radio circle; the selected row shows a
///   primary checkmark, the others nothing.
/// - md look and Beta design: the Material radio.
///
/// [labelEnd] maps the Ionic placement: false (Ionic default,
/// `justify="space-between"`) = label first, control at the end of the row;
/// true (`justify="start" labelPlacement="end"`) = control first.
///
/// ```dart
/// IonRadioItem<Mode>(
///   value: Mode.all,
///   groupValue: _mode,
///   labelEnd: true,
///   title: Text(l10n.messagesAllActive),
///   onChanged: (v) => setState(() => _mode = v!),
/// )
/// ```
class IonRadioItem<T> extends StatelessWidget {
  const IonRadioItem({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.labelEnd = false,
    this.dense,
    this.contentPadding,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final bool labelEnd;
  final bool? dense;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    if (!useIosLook(context) || context.rdSkin != null) {
      // ignore: deprecated_member_use
      return RadioListTile<T>(
        value: value,
        // ignore: deprecated_member_use
        groupValue: groupValue,
        // ignore: deprecated_member_use
        onChanged: onChanged,
        controlAffinity:
            labelEnd ? ListTileControlAffinity.leading : ListTileControlAffinity.trailing,
        dense: dense,
        contentPadding: contentPadding,
        title: title,
        subtitle: subtitle,
      );
    }
    final selected = value == groupValue;
    final mark = SizedBox(
      width: 24,
      height: 24,
      child: selected ? Icon(AppIcons.check, color: AppColors.primary, size: 22) : null,
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: ListTile(
        dense: dense,
        contentPadding: contentPadding,
        enabled: onChanged != null,
        onTap: onChanged == null ? null : () => onChanged!(value),
        leading: labelEnd ? mark : null,
        trailing: labelEnd ? null : mark,
        title: title,
        subtitle: subtitle,
      ),
    );
  }
}
