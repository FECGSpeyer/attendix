import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/attendance/attendance.dart';
import '../../../l10n/l10n.dart';
import '../adaptive/adaptive.dart';
import '../layout/ionic_ios.dart' show IonSheetHeader;

/// Default answer of a registration field.
dynamic registrationFieldDefault(RegistrationField field) {
  switch (field.type) {
    case RegistrationFieldType.boolean:
      return false;
    case RegistrationFieldType.multiSelect:
      return <String>[];
    default:
      return '';
  }
}

/// Validates answers: text fields must not be empty. Returns the label of
/// the first missing field or null.
String? missingRegistrationField(
  List<RegistrationField> fields,
  Map<String, dynamic> answers,
) {
  for (final field in fields) {
    if (field.type == RegistrationFieldType.text &&
        (answers[field.id]?.toString().trim().isEmpty ?? true)) {
      return field.label;
    }
  }
  return null;
}

/// Readable answer ("Ja", "A, B", text).
String registrationAnswerText(RegistrationField field, dynamic answer) {
  if (answer == null) return '';
  if (field.type == RegistrationFieldType.boolean) {
    return answer == true
        ? l10nWithoutContext.commonYes
        : l10nWithoutContext.commonNo;
  }
  if (answer is List) return answer.join(', ');
  return answer.toString();
}

/// Sheet for the registration fields (Anmeldefelder) of a Termin.
///
/// [editMode] = "Anmeldefelder anpassen" (Speichern) instead of sign in
/// (Anmelden). Returns the answers or null when cancelled.
Future<Map<String, dynamic>?> showRegistrationFieldsSheet(
  BuildContext context, {
  required List<RegistrationField> fields,
  Map<String, dynamic>? existing,
  bool editMode = false,
  bool requireText = true,
  bool closeIcon = false,
}) {
  final answers = <String, dynamic>{
    for (final f in fields)
      f.id: (existing != null && existing.containsKey(f.id))
          ? (existing[f.id] is List
              ? List<String>.from(
                  (existing[f.id] as List).map((e) => e.toString()),
                )
              : existing[f.id])
          : registrationFieldDefault(f),
  };
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    showDragHandle: true,
    isDismissible: editMode,
    builder: (ctx) => _RegistrationFieldsSheet(
      fields: fields,
      answers: answers,
      editMode: editMode,
      requireText: requireText,
    ),
  );
}

class _RegistrationFieldsSheet extends StatefulWidget {
  const _RegistrationFieldsSheet({
    required this.fields,
    required this.answers,
    required this.editMode,
    required this.requireText,
  });

  final List<RegistrationField> fields;
  final Map<String, dynamic> answers;
  final bool editMode;
  final bool requireText;

  @override
  State<_RegistrationFieldsSheet> createState() =>
      _RegistrationFieldsSheetState();
}

class _RegistrationFieldsSheetState extends State<_RegistrationFieldsSheet> {
  late final Map<String, dynamic> _answers = Map.of(widget.answers);
  final Map<String, TextEditingController> _controllers = {};
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(RegistrationField field) {
    return _controllers.putIfAbsent(
      field.id,
      () => TextEditingController(text: _answers[field.id]?.toString() ?? ''),
    );
  }

  void _submit() {
    if (widget.requireText) {
      final missing = missingRegistrationField(widget.fields, _answers);
      if (missing != null) {
        setState(() => _error = context.l10n.signoutFillField(missing));
        return;
      }
    }
    Navigator.of(context).pop(_answers);
  }

  Widget _buildField(RegistrationField field) {
    switch (field.type) {
      case RegistrationFieldType.boolean:
        return IonSwitchListTile(
          title: Text(field.label),
          value: _answers[field.id] == true,
          onChanged: (v) => setState(() => _answers[field.id] = v),
        );
      case RegistrationFieldType.select:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: AppDropdownFormField<String>(
            interface: AppSelectInterface.alert,
            value: (field.options ?? []).contains(_answers[field.id])
                ? _answers[field.id] as String
                : null,
            decoration: InputDecoration(
              labelText: field.label,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final opt in field.options ?? const <String>[])
                DropdownMenuItem(value: opt, child: Text(opt)),
            ],
            onChanged: (v) => setState(() => _answers[field.id] = v ?? ''),
          ),
        );
      case RegistrationFieldType.multiSelect:
        final selected =
            List<String>.from(_answers[field.id] as List? ?? const []);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                field.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final opt in field.options ?? const <String>[])
              CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(opt),
                value: selected.contains(opt),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    selected.add(opt);
                  } else {
                    selected.remove(opt);
                  }
                  _answers[field.id] = selected;
                }),
              ),
          ],
        );
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _controllerFor(field),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: field.label,
              hintText: '...',
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => _answers[field.id] = v,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // UX_SONGS_SELF: Ionic modal toolbar (title, cancel at end)
    final title = widget.editMode
        ? context.l10n.attendanceRegFields
        : context.l10n.coreFlutterRegistration;
    final end = <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: IonButtonLabel(context.l10n.commonCancel),
      ),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IonSheetHeader(title: title, end: end),
              ..._rows(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _rows(BuildContext context) => [
        for (final f in widget.fields) _buildField(f),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _submit,
            icon: Icon(AppIcons.checkCircleOutline),
            label: IonButtonLabel(widget.editMode
                ? context.l10n.commonSave
                : context.l10n.signoutSignIn),
          ),
        ),
      ];
}

/// Note input dialog ("Notiz für Anmeldung" / "Notiz anpassen").
Future<String?> showEventNoteDialog(
  BuildContext context, {
  required String title,
  required String confirmText,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showAppDialog<String>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(title),
      // Ionic alert input `type: 'textarea'` (overview.page.ts / signout.page.ts).
      content: AppAlertInput(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        minLines: 2,
        textarea: true,
        textCapitalization: TextCapitalization.sentences,
        placeholder: ctx.l10n.signoutEnterNote,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// Result of [showRegistrationFieldAlert]: [value] null = nothing chosen.
typedef RegistrationFieldAlertResult = ({dynamic value});

/// Ionic attendance.page `showRegFieldAlert`: with exactly one Anmeldefeld
/// the answer is edited in an alert with the field label as header – text
/// input (placeholder „...“), Ja/Nein radios, options as radios or (multi
/// select) checkboxes – and „Abbrechen“ / „Speichern“. Returns null when
/// cancelled.
Future<RegistrationFieldAlertResult?> showRegistrationFieldAlert(
  BuildContext context, {
  required RegistrationField field,
  dynamic existing,
}) {
  return showAppDialog<RegistrationFieldAlertResult>(
    context: context,
    builder: (_) => _RegistrationFieldAlert(field: field, existing: existing),
  );
}

class _RegistrationFieldAlert extends StatefulWidget {
  const _RegistrationFieldAlert({required this.field, this.existing});

  final RegistrationField field;
  final dynamic existing;

  @override
  State<_RegistrationFieldAlert> createState() =>
      _RegistrationFieldAlertState();
}

class _RegistrationFieldAlertState extends State<_RegistrationFieldAlert> {
  late final TextEditingController _text = TextEditingController(
    text: widget.existing is String ? widget.existing as String : '',
  );
  // Without a previous answer nothing is preselected ('' counts as none).
  late dynamic _single = widget.existing == '' ? null : widget.existing;
  late final Set<String> _multi = {
    if (widget.existing is List)
      ...(widget.existing as List).map((e) => e.toString()),
  };

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Widget _choice(
    String label,
    bool checked,
    VoidCallback onTap, {
    bool checkbox = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final icon = checkbox
        ? (checked ? AppIcons.checkBox : AppIcons.checkBoxOutlineBlank)
        : (checked
            ? AppIcons.radioButtonChecked
            : AppIcons.radioButtonUnchecked);
    // Selection state is only shown via the icon: expose it to screen readers.
    return Semantics(
      container: true,
      button: true,
      checked: checked,
      inMutuallyExclusiveGroup: !checkbox,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: checked ? primary : null),
        title: Text(label),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final l10n = context.l10n;
    Widget content;
    switch (field.type) {
      case RegistrationFieldType.text:
        content = AppAlertInput(
          controller: _text,
          autofocus: true,
          placeholder: '...',
        );
      case RegistrationFieldType.boolean:
        content = AppAlertRadioGroup<bool>(
          options: [
            AppAlertOption(true, l10n.commonYes),
            AppAlertOption(false, l10n.commonNo),
          ],
          groupValue: _single is bool ? _single as bool : null,
          onChanged: (v) => setState(() => _single = v),
          beta: Column(mainAxisSize: MainAxisSize.min, children: [
            _choice(
              l10n.commonYes,
              _single == true,
              () => setState(() => _single = true),
            ),
            _choice(
              l10n.commonNo,
              _single == false,
              () => setState(() => _single = false),
            ),
          ]),
        );
      default:
        final multi = field.type == RegistrationFieldType.multiSelect;
        final options = [
          for (final o in field.options ?? const <String>[])
            AppAlertOption(o, o),
        ];
        final beta = Column(mainAxisSize: MainAxisSize.min, children: [
          for (final o in field.options ?? const <String>[])
            multi
                ? _choice(
                    o,
                    _multi.contains(o),
                    () => setState(
                      () => _multi.contains(o) ? _multi.remove(o) : _multi.add(o),
                    ),
                    checkbox: true,
                  )
                : _choice(o, _single == o, () => setState(() => _single = o)),
        ]);
        content = multi
            ? AppAlertCheckboxGroup<String>(
                options: options,
                values: _multi,
                onChanged: (o, checked) =>
                    setState(() => checked ? _multi.add(o) : _multi.remove(o)),
                beta: beta,
              )
            : AppAlertRadioGroup<String>(
                options: options,
                groupValue: _single is String ? _single as String : null,
                onChanged: (o) => setState(() => _single = o),
                beta: beta,
              );
    }
    return AppAlertDialog(
      title: Text(field.label),
      scrollable: true,
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () {
            final dynamic value = switch (field.type) {
              RegistrationFieldType.text => _text.text,
              RegistrationFieldType.multiSelect => [
                  for (final o in field.options ?? const <String>[])
                    if (_multi.contains(o)) o,
                ],
              // Nothing chosen → null, never ''.
              _ => _single == '' ? null : _single,
            };
            Navigator.of(context).pop((value: value));
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
