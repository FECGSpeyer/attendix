import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/quill_utils.dart';
import '../../../data/models/attendance/attendance.dart';

const String _customReason = 'Sonstiger Grund';

/// Reason sheet for Absagen / Verspätung (Ionic ExcuseReasonPicker).
///
/// Shows the tenant's absence or late reasons plus "Sonstiger Grund (Text)".
/// When the Termin is today the free text is preselected, otherwise the
/// first predefined reason. Returns the reason or null when cancelled.
Future<String?> showExcuseReasonSheet(
  BuildContext context, {
  required bool isLate,
  required bool isToday,
  required List<String> absenceReasons,
  required List<String> lateReasons,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ExcuseReasonSheet(
      isLate: isLate,
      reasons: isLate ? lateReasons : absenceReasons,
      isToday: isToday,
    ),
  );
}

class _ExcuseReasonSheet extends StatefulWidget {
  const _ExcuseReasonSheet({
    required this.isLate,
    required this.reasons,
    required this.isToday,
  });

  final bool isLate;
  final List<String> reasons;
  final bool isToday;

  @override
  State<_ExcuseReasonSheet> createState() => _ExcuseReasonSheetState();
}

class _ExcuseReasonSheetState extends State<_ExcuseReasonSheet> {
  late String _selection;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selection = widget.isToday || widget.reasons.isEmpty
        ? _customReason
        : widget.reasons.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _confirmable => _selection == _customReason
      ? _controller.text.trim().length > 4
      : _selection.isNotEmpty;

  void _confirm() {
    if (!_confirmable) return;
    Navigator.of(context).pop(
      _selection == _customReason ? _controller.text.trim() : _selection,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Abbrechen',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.isLate ? 'Verspätung' : 'Abmeldung',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    tooltip: 'Bestätigen',
                    color: AppColors.primary,
                    onPressed: _confirmable ? _confirm : null,
                  ),
                ],
              ),
              for (final reason in [...widget.reasons, _customReason])
                RadioListTile<String>(
                  value: reason,
                  groupValue: _selection,
                  onChanged: (v) => setState(() => _selection = v ?? _selection),
                  title: Text(reason == _customReason ? 'Sonstiger Grund (Text)' : reason),
                ),
              if (_selection == _customReason)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Grund',
                      hintText: 'Mindestens 5 Zeichen eingeben...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton(
                  onPressed: _confirmable ? _confirm : null,
                  child: const Text('Bestätigen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return answer == true ? 'Ja' : 'Nein';
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
}) {
  final answers = <String, dynamic>{
    for (final f in fields)
      f.id: (existing != null && existing.containsKey(f.id))
          ? (existing[f.id] is List ? List<String>.from((existing[f.id] as List).map((e) => e.toString())) : existing[f.id])
          : registrationFieldDefault(f),
  };
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
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
  State<_RegistrationFieldsSheet> createState() => _RegistrationFieldsSheetState();
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
        setState(() => _error = 'Bitte "$missing" ausfüllen');
        return;
      }
    }
    Navigator.of(context).pop(_answers);
  }

  Widget _buildField(RegistrationField field) {
    switch (field.type) {
      case RegistrationFieldType.boolean:
        return SwitchListTile(
          title: Text(field.label),
          value: _answers[field.id] == true,
          onChanged: (v) => setState(() => _answers[field.id] = v),
        );
      case RegistrationFieldType.select:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<String>(
            value: (field.options ?? []).contains(_answers[field.id]) ? _answers[field.id] as String : null,
            decoration: InputDecoration(labelText: field.label, border: const OutlineInputBorder()),
            items: [
              for (final opt in field.options ?? const <String>[])
                DropdownMenuItem(value: opt, child: Text(opt)),
            ],
            onChanged: (v) => setState(() => _answers[field.id] = v ?? ''),
          ),
        );
      case RegistrationFieldType.multiSelect:
        final selected = List<String>.from(_answers[field.id] as List? ?? const []);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(field.label, style: const TextStyle(fontWeight: FontWeight.w600)),
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.editMode ? 'Anmeldefelder' : 'Anmeldung',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Abbrechen'),
                    ),
                  ],
                ),
              ),
              for (final f in widget.fields) _buildField(f),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(widget.editMode ? 'Speichern' : 'Anmelden'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the description (HTML from the Ionic editor) of a Termin.
Future<void> showEventDescriptionSheet(BuildContext context, String description) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Beschreibung', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              SelectableText(QuillUtils.stripHtml(description)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Note input dialog ("Notiz für Anmeldung" / "Notiz anpassen").
Future<String?> showEventNoteDialog(
  BuildContext context, {
  required String title,
  required String confirmText,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Gib hier deine Notiz ein'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
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
