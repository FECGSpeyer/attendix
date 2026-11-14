import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';

import '../../../core/theme/redesign/rd_theme.dart';
import '../../../l10n/l10n.dart';
import 'adaptive_platform.dart';
import 'app_alert_inputs.dart';
import 'app_dialog.dart';
import 'app_select.dart';
import 'app_toolbar.dart' show ionModalToolbarHeight;
import 'ion_button_label.dart';
import '../dialogs/ion_modal.dart' show showIonModal;
import '../layout/ionic_md.dart' show IonMd;

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

/// Ionic `ion-select multiple interface="modal"` (`ion-select-modal`): a
/// modal (full screen on phones, the centred 600px card from 768px) with the
/// toolbar title [header] and "Schließen" at the end, below it one
/// `ion-checkbox` item per option (checkbox first, `justify="start"
/// labelPlacement="end"`; iOS round 22pt, md square 18px). Every tick counts
/// at once (Ionic writes the value on each change, there is no OK / Cancel):
/// [onChanged] gets the new selection after each tick.
///
/// Returns the selection when the modal closes (in option order). Under the
/// Beta skin it falls back to [showAppMultiSelect] (alert, choice with OK).
Future<List<T>?> showAppMultiSelectModal<T>({
  required BuildContext context,
  required List<AppSelectOption<T>> options,
  required List<T> values,
  String? header,
  ValueChanged<List<T>>? onChanged,
}) async {
  if (context.rdSkin != null) {
    final picked = await showAppMultiSelect<T>(
      context: context,
      options: options,
      values: values,
      header: header,
    );
    if (picked != null) onChanged?.call(picked);
    return picked;
  }
  final selected = {...values};
  List<T> ordered() => [for (final o in options) if (selected.contains(o.value)) o.value];
  await showIonModal<void>(
    context,
    builder: (_) => _MultiSelectModal<T>(
      header: header,
      options: options,
      selected: selected,
      onToggle: (value, checked) {
        checked ? selected.add(value) : selected.remove(value);
        onChanged?.call(ordered());
      },
    ),
  );
  return ordered();
}

class _MultiSelectModal<T> extends StatefulWidget {
  const _MultiSelectModal({
    required this.header,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String? header;
  final List<AppSelectOption<T>> options;
  final Set<T> selected;
  final void Function(T value, bool checked) onToggle;

  @override
  State<_MultiSelectModal<T>> createState() => _MultiSelectModalState<T>();
}

class _MultiSelectModalState<T> extends State<_MultiSelectModal<T>> {
  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    final theme = Theme.of(context);
    final rows = <Widget>[];
    for (final o in widget.options) {
      final checked = widget.selected.contains(o.value);
      rows.add(Semantics(
        checked: checked,
        enabled: o.enabled,
        child: Opacity(
          opacity: o.enabled ? 1 : (ios ? 0.4 : 0.3),
          child: InkWell(
            splashFactory: ios ? NoSplash.splashFactory : null,
            onTap: !o.enabled
                ? null
                : () => setState(() => widget.onToggle(o.value, !checked)),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: ios ? 44 : IonMd.itemMinHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    ios ? _IosModalCheckbox(checked: checked) : _MdModalCheckbox(checked: checked),
                    SizedBox(width: ios ? 12 : 16),
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                          fontSize: ios ? 17 : IonMd.itemFontSize,
                          color: theme.colorScheme.onSurface,
                        ),
                        child: o.child ?? Text(o.label!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
      // iOS item line from the label to the end; md items have none here.
      if (ios) rows.add(const Divider(height: 0.5, thickness: 0.5, indent: 50));
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: ionModalToolbarHeight(context),
        automaticallyImplyLeading: false,
        title: widget.header == null ? null : Text(widget.header!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: IonButtonLabel(context.l10n.commonClose),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: ios ? 0 : 8,
          bottom: (ios ? 0 : 8) + MediaQuery.paddingOf(context).bottom,
        ),
        children: rows,
      ),
    );
  }
}

/// iOS `ion-checkbox`: 22pt circle; checked = primary with a white check.
class _IosModalCheckbox extends StatelessWidget {
  const _IosModalCheckbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? primary : Colors.transparent,
        border: checked
            ? null
            : Border.all(
                color: dark ? const Color(0xFF545458) : const Color(0xFFC8C7CC),
                width: 1.5,
              ),
      ),
      child: checked ? Icon(AppIcons.check, size: 15, color: Colors.white) : null,
    );
  }
}

/// md `ion-checkbox`: 18px square, radius 2, 2px border; checked = primary.
class _MdModalCheckbox extends StatelessWidget {
  const _MdModalCheckbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final off = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: checked ? primary : Colors.transparent,
        border: Border.all(color: checked ? primary : off, width: 2),
      ),
      child: checked ? Icon(AppIcons.check, size: 14, color: theme.colorScheme.onPrimary) : null,
    );
  }
}
