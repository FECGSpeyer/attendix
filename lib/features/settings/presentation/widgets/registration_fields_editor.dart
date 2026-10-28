import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../shared/widgets/common/swipe_actions.dart';
import '../../../../l10n/l10n.dart';

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
      ToastHelper.showWarning(context, context.l10n.typeSettingsEnterFieldLabel);
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
        ToastHelper.showWarning(context, context.l10n.typeSettingsTwoOptions);
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.l10n.typeSettingsNoSignupFields,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.medium),
            ),
          ),
        for (var i = 0; i < widget.fields.length; i++)
          // Ionic: ion-item-sliding with a trash option.
          SwipeActions.delete(
            key: ValueKey('reg-field-${widget.fields[i].id}-$i'),
            onDelete: () => widget.onChanged([...widget.fields]..removeAt(i)),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.fields[i].label),
              subtitle: Text([
                _typeLabel(context, widget.fields[i].type),
                if (widget.fields[i].options?.isNotEmpty ?? false) widget.fields[i].options!.join(', '),
              ].join(' · ')),
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _labelController,
          decoration: InputDecoration(
            labelText: context.l10n.typeSettingsFieldLabel,
            hintText: context.l10n.typeSettingsFieldLabelPh,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _type,
          decoration: InputDecoration(labelText: context.l10n.typeSettingsType, border: const OutlineInputBorder()),
          items: [
            for (final t in const [
              RegistrationFieldType.text,
              RegistrationFieldType.boolean,
              RegistrationFieldType.select,
              RegistrationFieldType.multiSelect,
            ])
              DropdownMenuItem(value: t, child: Text(_typeLabel(context, t))),
          ],
          onChanged: (v) => setState(() => _type = v ?? RegistrationFieldType.text),
        ),
        if (_needsOptions) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _optionsController,
            decoration: InputDecoration(
              labelText: context.l10n.typeSettingsOptionsComma,
              hintText: context.l10n.typeSettingsOptionsPh,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add_circle_outline),
          label: Text(context.l10n.typeSettingsAddField),
        ),
      ],
    );
  }
}

/// Localized label of a [RegistrationFieldType] (Ionic typeSettings.* keys).
String _typeLabel(BuildContext context, String type) {
  final l10n = context.l10n;
  switch (type) {
    case RegistrationFieldType.text:
      return l10n.typeSettingsText;
    case RegistrationFieldType.boolean:
      return l10n.typeSettingsYesNo;
    case RegistrationFieldType.select:
      return l10n.typeSettingsSingle;
    case RegistrationFieldType.multiSelect:
      return l10n.typeSettingsMulti;
    default:
      return type;
  }
}
