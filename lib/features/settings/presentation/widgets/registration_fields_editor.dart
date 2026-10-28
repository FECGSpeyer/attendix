import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';

/// Editor for the "Anmeldefelder" of an attendance type
/// (Ionic `type.page.html` registration_fields section).
///
/// Fields can be added and removed at any time; existing answers stay in
/// `person_attendances.registration_answers` keyed by the field id.
class RegistrationFieldsEditor extends StatefulWidget {
  const RegistrationFieldsEditor({
    super.key,
    required this.fields,
    required this.onChanged,
  });

  final List<RegistrationField> fields;
  final ValueChanged<List<RegistrationField>> onChanged;

  @override
  State<RegistrationFieldsEditor> createState() => _RegistrationFieldsEditorState();
}

class _RegistrationFieldsEditorState extends State<RegistrationFieldsEditor> {
  final _labelController = TextEditingController();
  final _optionsController = TextEditingController();
  String _type = RegistrationFieldType.text;

  bool get _needsOptions =>
      _type == RegistrationFieldType.select || _type == RegistrationFieldType.multiSelect;

  @override
  void dispose() {
    _labelController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  void _add() {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      ToastHelper.showWarning(context, 'Bitte eine Feldbezeichnung eingeben');
      return;
    }
    List<String>? options;
    if (_needsOptions) {
      options = _optionsController.text
          .split(',')
          .map((o) => o.trim())
          .where((o) => o.isNotEmpty)
          .toList();
      if (options.length < 2) {
        ToastHelper.showWarning(context, 'Bitte mindestens 2 Optionen angeben');
        return;
      }
    }
    widget.onChanged([
      ...widget.fields,
      RegistrationField(id: const Uuid().v4(), label: label, type: _type, options: options),
    ]);
    setState(() {
      _labelController.clear();
      _optionsController.clear();
      _type = RegistrationFieldType.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.fields.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Keine Anmeldefelder konfiguriert',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.medium),
            ),
          ),
        for (var i = 0; i < widget.fields.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(widget.fields[i].label),
            subtitle: Text([
              RegistrationFieldType.label(widget.fields[i].type),
              if (widget.fields[i].options?.isNotEmpty ?? false) widget.fields[i].options!.join(', '),
            ].join(' · ')),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              tooltip: 'Entfernen',
              onPressed: () => widget.onChanged([...widget.fields]..removeAt(i)),
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _labelController,
          decoration: const InputDecoration(
            labelText: 'Feldbezeichnung',
            hintText: 'z.B. Instrument mitbringen?',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _type,
          decoration: const InputDecoration(labelText: 'Typ', border: OutlineInputBorder()),
          items: [
            for (final t in const [
              RegistrationFieldType.text,
              RegistrationFieldType.boolean,
              RegistrationFieldType.select,
              RegistrationFieldType.multiSelect,
            ])
              DropdownMenuItem(value: t, child: Text(RegistrationFieldType.label(t))),
          ],
          onChanged: (v) => setState(() => _type = v ?? RegistrationFieldType.text),
        ),
        if (_needsOptions) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _optionsController,
            decoration: const InputDecoration(
              labelText: 'Optionen (kommagetrennt)',
              hintText: 'Option A, Option B, Option C',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Feld hinzufügen'),
        ),
      ],
    );
  }
}
