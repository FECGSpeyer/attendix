import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../planning/presentation/widgets/plan_field_dialogs.dart';

const _fieldTypes = <String, String>{
  'text': 'Text',
  'textarea': 'Textbereich',
  'number': 'Zahl',
  'date': 'Datum',
  'boolean': 'Ja/Nein',
  'select': 'Auswahl',
};

String _typeName(String type) => _fieldTypes[type] ?? 'Unbekannt';

/// Field id of an org-wide extra field (Ionic `org_<orgId>_<name>`).
String orgFieldId(int orgId, String name) =>
    'org_${orgId}_${name.toLowerCase().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-z0-9_]'), '')}';

/// "Personen-Zusatzfelder" of the organisation (Ionic `OrgPersonFieldsPage`).
///
/// Edits `tenant_groups.additional_fields`; values of deleted fields are
/// removed from `tenant_group_person_fields` on save.
class OrgPersonFieldsPage extends ConsumerStatefulWidget {
  const OrgPersonFieldsPage({super.key});

  @override
  ConsumerState<OrgPersonFieldsPage> createState() => _OrgPersonFieldsPageState();
}

class _OrgPersonFieldsPageState extends ConsumerState<OrgPersonFieldsPage> {
  List<OrgExtraField>? _fields;
  Set<String> _originalIds = {};
  bool _saving = false;

  bool get _isSuperAdmin => ref.read(effectiveRoleProvider) == Role.admin;

  Future<void> _add(int orgId) async {
    final field = await showModalBottomSheet<OrgExtraField>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FieldEditorSheet(),
    );
    if (field == null || !mounted) return;
    final id = orgFieldId(orgId, field.name);
    if (_fields!.any((f) => f.id == id)) {
      ToastHelper.showError(context, 'Ein Zusatzfeld mit diesem Namen existiert bereits.');
      return;
    }
    setState(() => _fields = [..._fields!, field.copyWith(id: id)]);
  }

  Future<void> _edit(int index) async {
    final field = await showModalBottomSheet<OrgExtraField>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FieldEditorSheet(initial: _fields![index]),
    );
    if (field == null) return;
    setState(() {
      final list = [..._fields!];
      list[index] = field;
      _fields = list;
    });
  }

  Future<void> _remove(int index) async {
    final ok = await showPlanConfirm(
      context,
      title: 'Zusatzfeld löschen?',
      message: 'Möchtest du das Zusatzfeld „${_fields![index].name}“ wirklich löschen?',
      confirmText: 'Löschen',
      destructive: true,
    );
    if (ok) setState(() => _fields = [..._fields!]..removeAt(index));
  }

  Future<void> _save(int orgId) async {
    if (!_isSuperAdmin) return;
    for (final f in _fields!) {
      if (f.name.trim().isEmpty || !f.id.startsWith('org_${orgId}_')) {
        ToastHelper.showError(context, 'Ungültige Organisations-Zusatzfelder.');
        return;
      }
      if (f.type == 'select' && f.options.isEmpty) {
        ToastHelper.showError(context, 'Das Auswahlfeld „${f.name}“ benötigt Optionen.');
        return;
      }
    }
    setState(() => _saving = true);
    final current = _fields!.map((f) => f.id).toSet();
    final deleted = _originalIds.where((id) => !current.contains(id)).toList();
    final ok = await ref.read(planSettingsNotifierProvider.notifier).updateOrgExtraFields(_fields!, deleted);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _originalIds = current;
      ToastHelper.showSuccess(context, 'Organisations-Zusatzfelder gespeichert.');
    } else {
      ToastHelper.showError(context, 'Fehler beim Speichern');
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(currentOrganisationProvider).valueOrNull;
    final isSuperAdmin = ref.watch(effectiveRoleProvider) == Role.admin;
    if (_fields == null && org != null) {
      _fields = [...?org.additionalFields];
      _originalIds = _fields!.map((f) => f.id).toSet();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personen-Zusatzfelder'),
        actions: [
          IconButton(
            tooltip: 'Speichern',
            icon: const Icon(Icons.check),
            onPressed: _saving || !isSuperAdmin || org?.id == null ? null : () => _save(org!.id!),
          ),
        ],
      ),
      body: _fields == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.medium),
                  title: Text(
                    'Diese Felder und ihre Werte gelten für dieselbe Person gemeinsam in allen Instanzen der Organisation.',
                    style: TextStyle(fontSize: 13, color: AppColors.medium),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('ZUSÄTZLICHE FELDER FÜR PERSONEN',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.medium)),
                      ),
                      IconButton(
                        tooltip: 'Neues Feld hinzufügen',
                        icon: const Icon(Icons.add),
                        onPressed: isSuperAdmin && org?.id != null ? () => _add(org!.id!) : null,
                      ),
                    ],
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: _fields!.isEmpty
                      ? const ListTile(title: Text('Es wurden noch keine organisationsweiten Zusatzfelder hinzugefügt.'))
                      : ReorderableListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          onReorder: (from, to) {
                            if (!isSuperAdmin) return;
                            setState(() {
                              final list = [..._fields!];
                              final item = list.removeAt(from);
                              list.insert(to > from ? to - 1 : to, item);
                              _fields = list;
                            });
                          },
                          children: [
                            for (var i = 0; i < _fields!.length; i++) _fieldTile(i, isSuperAdmin),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _fieldTile(int i, bool isSuperAdmin) {
    final f = _fields![i];
    final mode = f.displayMode == 'underneath' ? 'Unter dem Namen' : 'Als Chip';
    return ListTile(
      key: ValueKey(f.id),
      title: Text(f.name),
      subtitle: Text([
        'Typ: ${_typeName(f.type)}',
        'Anzeige: $mode',
        if (f.visibleToPlayers) 'Für Mitglieder sichtbar${f.editableByPlayers ? ' (bearbeitbar)' : ''}',
      ].join('\n')),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: isSuperAdmin ? () => _edit(i) : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: isSuperAdmin ? () => _remove(i) : null,
          ),
          if (isSuperAdmin) ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
        ],
      ),
    );
  }
}

/// Add / edit sheet of one org extra field.
class _FieldEditorSheet extends StatefulWidget {
  const _FieldEditorSheet({this.initial});
  final OrgExtraField? initial;

  @override
  State<_FieldEditorSheet> createState() => _FieldEditorSheetState();
}

class _FieldEditorSheetState extends State<_FieldEditorSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _default =
      TextEditingController(text: widget.initial?.defaultValue is String ? widget.initial!.defaultValue as String : '');
  late String _type = widget.initial?.type ?? 'text';
  late String _displayMode = widget.initial?.displayMode ?? 'chip';
  late bool _visible = widget.initial?.visibleToPlayers ?? false;
  late bool _editable = widget.initial?.editableByPlayers ?? false;
  late bool _boolDefault = widget.initial?.defaultValue == true;
  late final List<TextEditingController> _options =
      (widget.initial?.options ?? const <String>[]).map((o) => TextEditingController(text: o)).toList();

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _default.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ToastHelper.showError(context, 'Bitte gib einen gültigen Namen für das Zusatzfeld ein.');
      return;
    }
    final options = _options.map((c) => c.text.trim()).where((o) => o.isNotEmpty).toList();
    if (_type == 'select' && options.isEmpty) {
      ToastHelper.showError(context, 'Bitte füge mindestens eine Auswahloption hinzu.');
      return;
    }
    final dynamic defaultValue = switch (_type) {
      'select' => options.first,
      'boolean' => _boolDefault,
      _ => _default.text,
    };
    Navigator.pop(
      context,
      OrgExtraField(
        id: widget.initial?.id ?? '',
        name: name,
        type: _type,
        defaultValue: defaultValue,
        options: _type == 'select' ? options : const [],
        visibleToPlayers: _visible,
        editableByPlayers: _visible && _editable,
        displayMode: _displayMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_isEdit ? 'Feld bearbeiten' : 'Neues Feld hinzufügen', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_isEdit)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Typ'),
                  trailing: Text(_typeName(_type)),
                )
              else
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Typ'),
                  items: [
                    for (final e in _fieldTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'text'),
                ),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              DropdownButtonFormField<String>(
                value: _displayMode,
                decoration: const InputDecoration(labelText: 'Anzeige in Listen'),
                items: const [
                  DropdownMenuItem(value: 'chip', child: Text('Als Chip')),
                  DropdownMenuItem(value: 'underneath', child: Text('Unter dem Namen')),
                ],
                onChanged: (v) => setState(() => _displayMode = v ?? 'chip'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Für Mitglieder sichtbar'),
                subtitle: const Text('Aktivieren, damit Mitglieder dieses Feld in ihren Stammdaten sehen können.'),
                value: _visible,
                onChanged: (v) => setState(() => _visible = v),
              ),
              if (_visible)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Von Mitgliedern bearbeitbar'),
                  subtitle: const Text('Aktivieren, damit Mitglieder den Wert selbst ändern können.'),
                  value: _editable,
                  onChanged: (v) => setState(() => _editable = v),
                ),
              if (_type == 'select') ...[
                Row(
                  children: [
                    const Expanded(child: Text('Optionen', style: TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => _options.add(TextEditingController())),
                    ),
                  ],
                ),
                if (_options.isEmpty) const Text('Keine Optionen ausgewählt'),
                for (var i = 0; i < _options.length; i++)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _options[i],
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Wert eingeben...',
                            helperText: i == 0 ? 'Erste Option ist der Standardwert' : null,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: () => setState(() => _options.removeAt(i).dispose()),
                      ),
                    ],
                  ),
              ] else if (_type == 'boolean')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Standardwert'),
                  value: _boolDefault,
                  onChanged: (v) => setState(() => _boolDefault = v),
                )
              else
                TextField(
                  controller: _default,
                  keyboardType: _type == 'number' ? TextInputType.number : TextInputType.text,
                  decoration: InputDecoration(labelText: _isEdit ? 'Standardwert' : 'Standardwert (optional)'),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: Text(_isEdit ? 'Änderungen übernehmen' : 'Feld hinzufügen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
