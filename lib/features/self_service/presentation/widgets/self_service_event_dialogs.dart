part of 'self_service_event_actions.dart';

/// Dialog for a single registration field: text input, yes/no radios,
/// single-select radios, or multi-select checkboxes. In sign-in mode the
/// primary button triggers sign-in; in edit mode it saves the updated value.
Future<Map<String, dynamic>?> showSingleRegistrationFieldDialog(
  BuildContext context, {
  required RegistrationField field,
  dynamic existing,
  bool editMode = false,
}) {
  return showAppDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: editMode,
    builder: (ctx) => _SingleFieldDialog(field: field, existing: existing, editMode: editMode),
  );
}

class _SingleFieldDialog extends StatefulWidget {
  const _SingleFieldDialog({required this.field, required this.existing, required this.editMode});

  final RegistrationField field;
  final dynamic existing;
  final bool editMode;

  @override
  State<_SingleFieldDialog> createState() => _SingleFieldDialogState();
}

class _SingleFieldDialogState extends State<_SingleFieldDialog> {
  late dynamic _value;
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    final field = widget.field;
    final existing = widget.existing;
    if (field.type == RegistrationFieldType.multiSelect) {
      _value = existing is List ? existing.map((e) => e.toString()).toList() : <String>[];
    } else {
      _value = existing ?? (field.type == RegistrationFieldType.boolean ? false : '');
    }
    _text = TextEditingController(
      text: field.type == RegistrationFieldType.text ? '${_value ?? ''}' : '',
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Widget _content() {
    final field = widget.field;
    switch (field.type) {
      case RegistrationFieldType.boolean:
        return RadioGroup<bool>(
          groupValue: _value is bool ? _value as bool : null,
          onChanged: (v) => setState(() => _value = v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final opt in const [true, false])
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  value: opt,
                  title: Text(opt ? context.l10n.commonYes : context.l10n.commonNo),
                ),
            ],
          ),
        );
      case RegistrationFieldType.select:
        return RadioGroup<String>(
          groupValue: _value is String ? _value as String : null,
          onChanged: (v) => setState(() => _value = v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final opt in field.options ?? const <String>[])
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: opt,
                  title: Text(opt),
                ),
            ],
          ),
        );
      case RegistrationFieldType.multiSelect:
        final selected = _value as List<String>;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in field.options ?? const <String>[])
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: selected.contains(opt),
                title: Text(opt),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    selected.add(opt);
                  } else {
                    selected.remove(opt);
                  }
                }),
              ),
          ],
        );
      default:
        return TextField(
          controller: _text,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: '...'),
          onChanged: (v) => _value = v,
        );
    }
  }

  /// Renders the field input in the adaptive alert control matching [field.type].
  Widget _alertContent() {
    final field = widget.field;
    final viewContent = SingleChildScrollView(child: _content());
    switch (field.type) {
      case RegistrationFieldType.boolean:
        return AppAlertRadioGroup<bool>(
          options: [
            AppAlertOption(true, context.l10n.commonYes),
            AppAlertOption(false, context.l10n.commonNo),
          ],
          groupValue: _value is bool ? _value as bool : null,
          onChanged: (v) => setState(() => _value = v),
          beta: viewContent,
        );
      case RegistrationFieldType.select:
        return AppAlertRadioGroup<String>(
          options: [
            for (final opt in field.options ?? const <String>[]) AppAlertOption(opt, opt),
          ],
          groupValue: _value is String ? _value as String : null,
          onChanged: (v) => setState(() => _value = v),
          beta: viewContent,
        );
      case RegistrationFieldType.multiSelect:
        final selected = _value as List<String>;
        return AppAlertCheckboxGroup<String>(
          options: [
            for (final opt in field.options ?? const <String>[]) AppAlertOption(opt, opt),
          ],
          values: selected.toSet(),
          onChanged: (opt, checked) => setState(() {
            checked ? selected.add(opt) : selected.remove(opt);
          }),
          beta: viewContent,
        );
      default:
        return AppAlertInputGroup(
          beta: viewContent,
          children: [
            AppAlertInput(
              controller: _text,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              placeholder: '...',
              onChanged: (v) => _value = v,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      title: Text(widget.field.label),
      content: _alertContent(),
      actions: [
        if (widget.editMode)
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
        TextButton(
          onPressed: () => Navigator.pop(context, <String, dynamic>{widget.field.id: _value}),
          child: Text(widget.editMode ? context.l10n.commonSave : context.l10n.signoutSignIn),
        ),
      ],
    );
  }
}
