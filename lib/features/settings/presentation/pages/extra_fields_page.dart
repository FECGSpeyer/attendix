import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/files_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/extra_fields_repository.dart';

enum ExtraFieldTarget { person, song }

/// ID eines Zusatzfeldes aus dem Namen (wie Ionic: lowercase, `_` statt Leerzeichen)
String extraFieldIdFromName(String name) {
  return name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');
}

String extraFieldTypeName(String type) {
  switch (type) {
    case 'text':
      return 'Text';
    case 'textarea':
      return 'Textbereich';
    case 'number':
      return 'Zahl';
    case 'select':
      return 'Auswahl';
    case 'date':
      return 'Datum';
    case 'boolean':
      return 'Ja/Nein';
    case 'bfecg_church':
      return 'BFECG Gemeinde';
    default:
      return 'Unbekannt';
  }
}

/// Validierung vor dem Speichern (null = ok, sonst Fehlermeldung)
String? validateExtraFields(List<ExtraField> fields) {
  for (final f in fields) {
    if (f.name.trim().isEmpty) return 'Alle Zusatzfelder müssen einen Namen haben.';
    if (f.type == 'select') {
      if (f.options == null || f.options!.isEmpty) {
        return 'Das Auswahlfeld „${f.name}“ muss mindestens eine Option haben.';
      }
      if (f.options!.any((o) => o.trim().isEmpty)) {
        return 'Die Optionen im Feld „${f.name}“ dürfen nicht leer sein.';
      }
    }
  }
  return null;
}

/// Zusatzfelder für Personen und Werke (Ionic: settings/general/extra-fields)
class ExtraFieldsPage extends ConsumerStatefulWidget {
  const ExtraFieldsPage({super.key});

  @override
  ConsumerState<ExtraFieldsPage> createState() => _ExtraFieldsPageState();
}

class _ExtraFieldsPageState extends ConsumerState<ExtraFieldsPage> {
  List<ExtraField> _personFields = [];
  List<ExtraField> _songFields = [];
  bool _saving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final tenant = ref.read(currentTenantProvider);
    _personFields = [...?tenant?.additionalFields];
    _songFields = [...?tenant?.songAdditionalFields];
  }

  List<ExtraField> _fields(ExtraFieldTarget t) => t == ExtraFieldTarget.person ? _personFields : _songFields;

  void _setFields(ExtraFieldTarget t, List<ExtraField> fields) {
    setState(() {
      if (t == ExtraFieldTarget.person) {
        _personFields = fields;
      } else {
        _songFields = fields;
      }
      _hasChanges = true;
    });
  }

  List<Object> get _churchIds =>
      (ref.read(churchesProvider).valueOrNull ?? []).map((c) => c.id).whereType<String>().toList();

  Future<void> _addField(ExtraFieldTarget target) async {
    final result = await _showFieldSheet(target: target);
    if (result == null) return;
    final fields = _fields(target);
    final id = result.type == 'bfecg_church' ? 'bfecg_church' : extraFieldIdFromName(result.name);
    if (id.isEmpty) {
      if (mounted) ToastHelper.showError(context, 'Die ID des Zusatzfeldes darf nicht leer sein.');
      return;
    }
    if (fields.any((f) => f.id == id)) {
      if (mounted) {
        ToastHelper.showError(context, 'Ein Zusatzfeld mit dieser ID existiert bereits. Bitte wähle einen anderen Namen.');
      }
      return;
    }
    _setFields(target, [...fields, result.copyWith(id: id)]);
  }

  Future<void> _editField(ExtraFieldTarget target, int index) async {
    final fields = _fields(target);
    final result = await _showFieldSheet(target: target, existing: fields[index]);
    if (result == null) return;
    final updated = [...fields];
    updated[index] = result;
    _setFields(target, updated);
  }

  Future<void> _removeField(ExtraFieldTarget target, int index) async {
    final fields = _fields(target);
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Zusatzfeld löschen?',
      message: 'Möchtest du das Zusatzfeld „${fields[index].name}“ wirklich löschen?',
      confirmText: 'Löschen',
      isDestructive: true,
    );
    if (!confirmed) return;
    _setFields(target, [...fields]..removeAt(index));
  }

  void _reorder(ExtraFieldTarget target, int oldIndex, int newIndex) {
    final fields = [..._fields(target)];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = fields.removeAt(oldIndex);
    fields.insert(newIndex, item);
    _setFields(target, fields);
  }

  Future<void> _save() async {
    final error = validateExtraFields([..._personFields, ..._songFields]);
    if (error != null) {
      ToastHelper.showError(context, error);
      return;
    }
    final repo = ref.read(extraFieldsRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return;
    setState(() => _saving = true);
    try {
      await repo.saveFields(personFields: _personFields, songFields: _songFields);
      await repo.sanitizeValues(table: 'player', definitions: _personFields, churchIds: _churchIds);
      await repo.sanitizeValues(table: 'songs', definitions: _songFields);

      final tenant = ref.read(currentTenantProvider);
      if (tenant != null) {
        await ref.read(currentTenantProvider.notifier).setTenantLocal(
              tenant.copyWith(additionalFields: _personFields, songAdditionalFields: _songFields),
            );
      }
      if (!mounted) return;
      setState(() => _hasChanges = false);
      ToastHelper.showSuccess(context, 'Felder gespeichert');
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Fehler beim Speichern');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Feld-Editor (Bottom Sheet)
  // ---------------------------------------------------------------------------

  Future<ExtraField?> _showFieldSheet({required ExtraFieldTarget target, ExtraField? existing}) {
    final isEdit = existing != null;
    final isPerson = target == ExtraFieldTarget.person;
    final tenantId = ref.read(currentTenantIdProvider);
    final nameController = TextEditingController(text: existing?.name ?? '');
    final defaultController = TextEditingController(
      text: existing != null && existing.type != 'boolean' && existing.defaultValue != null
          ? '${existing.defaultValue}'
          : '',
    );
    var type = existing?.type ?? 'text';
    var displayMode = existing?.displayMode ?? 'chip';
    var visible = existing?.visibleToPlayers ?? false;
    var editable = existing?.editableByPlayers ?? false;
    var boolDefault = existing?.type == 'boolean' ? existing?.defaultValue == true : false;
    final options = <TextEditingController>[
      for (final o in existing?.options ?? const <String>[]) TextEditingController(text: o),
    ];
    final originalOptions = [...?existing?.options];

    return showModalBottomSheet<ExtraField>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> removeOption(int i) async {
            final value = options[i].text;
            if (isEdit && isPerson && value.isNotEmpty && originalOptions.contains(value)) {
              final ok = await DialogHelper.showConfirmation(
                ctx,
                title: 'Option löschen?',
                message: 'Wenn du die Option „$value“ löschst, werden alle betroffenen Datensätze auf den Standardwert zurückgesetzt.',
                confirmText: 'Löschen',
                isDestructive: true,
              );
              if (!ok) return;
              final remaining = options.map((c) => c.text).toList()..removeAt(i);
              final newDefault = remaining.isNotEmpty ? remaining.first : '';
              try {
                final count = await ref
                    .read(extraFieldsRepositoryWithTenantProvider)
                    .updateFieldValue(existing.id, value, newDefault);
                if (count > 0 && mounted) ToastHelper.showSuccess(context, '$count Personen aktualisiert');
              } catch (_) {
                if (mounted) ToastHelper.showError(context, 'Fehler beim updaten der Zusatzfelder');
                return;
              }
            }
            setSheet(() => options.removeAt(i).dispose());
          }

          Future<void> resetValues() async {
            final ok = await DialogHelper.showConfirmation(
              ctx,
              title: 'Werte zurücksetzen?',
              message:
                  'Möchtest du alle Werte des Feldes „${nameController.text}“ auf den Standardwert zurücksetzen? Dies kann nicht rückgängig gemacht werden!',
              confirmText: 'Zurücksetzen',
              isDestructive: true,
            );
            if (!ok) return;
            final optionValues = options.map((c) => c.text).toList();
            final resolved = extraFieldDefaultValue(
              type,
              defaultValue: type == 'select'
                  ? null
                  : type == 'boolean'
                      ? boolDefault
                      : _parseDefault(type, defaultController.text),
              options: optionValues,
              churchIds: _churchIds,
            );
            try {
              final count = await ref.read(extraFieldsRepositoryWithTenantProvider).resetFieldValues(existing!.id, resolved);
              if (mounted) ToastHelper.showSuccess(context, '$count Personen aktualisiert');
            } catch (_) {
              if (mounted) ToastHelper.showError(context, 'Fehler beim updaten der Zusatzfelder');
            }
          }

          void submit() {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              ToastHelper.showError(ctx, 'Bitte gib einen gültigen Namen für das Zusatzfeld ein.');
              return;
            }
            final optionValues = options.map((c) => c.text).toList();
            dynamic defaultValue;
            if (type == 'select') {
              if (optionValues.isEmpty) {
                ToastHelper.showError(ctx, 'Bitte füge mindestens eine Option für das Auswahlfeld hinzu.');
                return;
              }
              if (optionValues.any((o) => o.trim().isEmpty)) {
                ToastHelper.showError(ctx, 'Optionen dürfen nicht leer sein.');
                return;
              }
              defaultValue = optionValues.first;
            } else if (type == 'boolean') {
              defaultValue = boolDefault;
            } else if (type == 'bfecg_church') {
              defaultValue = existing?.defaultValue;
            } else {
              defaultValue = _parseDefault(type, defaultController.text);
            }
            Navigator.pop(
              sheetContext,
              ExtraField(
                id: existing?.id ?? '',
                name: name,
                type: type,
                defaultValue: defaultValue,
                options: type == 'select' ? optionValues : const [],
                visibleToPlayers: isPerson ? visible : false,
                editableByPlayers: isPerson && visible ? editable : false,
                displayMode: displayMode,
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEdit ? 'Feld bearbeiten' : 'Neues Feld hinzufügen',
                            style: Theme.of(ctx).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetContext)),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    if (isEdit)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Typ'),
                        trailing: Text(extraFieldTypeName(type)),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: type,
                        decoration: const InputDecoration(labelText: 'Typ'),
                        items: [
                          const DropdownMenuItem(value: 'text', child: Text('Text')),
                          const DropdownMenuItem(value: 'number', child: Text('Zahl')),
                          const DropdownMenuItem(value: 'boolean', child: Text('Ja/Nein')),
                          const DropdownMenuItem(value: 'select', child: Text('Auswahl')),
                          if (isPerson && tenantId == 12)
                            const DropdownMenuItem(value: 'bfecg_church', child: Text('BFECG Gemeinde')),
                        ],
                        onChanged: (v) => setSheet(() {
                          type = v ?? 'text';
                          boolDefault = false;
                          defaultController.text = type == 'number' ? '0' : '';
                        }),
                      ),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    DropdownButtonFormField<String>(
                      value: displayMode,
                      decoration: const InputDecoration(labelText: 'Anzeige in Listen'),
                      items: const [
                        DropdownMenuItem(value: 'chip', child: Text('Als Chip')),
                        DropdownMenuItem(value: 'underneath', child: Text('Unter dem Namen')),
                      ],
                      onChanged: (v) => setSheet(() => displayMode = v ?? 'chip'),
                    ),
                    if (isPerson) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Für Mitglieder sichtbar'),
                        subtitle: const Text('Aktivieren, damit Mitglieder dieses Feld in ihren Stammdaten sehen können.'),
                        value: visible,
                        onChanged: (v) => setSheet(() => visible = v),
                      ),
                      if (visible)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Von Mitgliedern bearbeitbar'),
                          subtitle: const Text('Aktivieren, damit Mitglieder den Wert selbst ändern können.'),
                          value: editable,
                          onChanged: (v) => setSheet(() => editable = v),
                        ),
                    ],
                    if (type == 'select') ...[
                      const SizedBox(height: AppDimensions.paddingS),
                      Row(
                        children: [
                          Expanded(child: Text('Optionen', style: Theme.of(ctx).textTheme.titleSmall)),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => setSheet(() => options.add(TextEditingController())),
                          ),
                        ],
                      ),
                      if (options.isEmpty)
                        Text(isEdit ? 'Keine Optionen' : 'Keine Optionen ausgewählt',
                            style: const TextStyle(color: AppColors.medium)),
                      for (var i = 0; i < options.length; i++)
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: options[i],
                                textCapitalization: TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: 'Wert eingeben...',
                                  helperText: i == 0 ? 'Erste Option ist der Standardwert' : null,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              onPressed: () => removeOption(i),
                            ),
                          ],
                        ),
                    ],
                    if (type != 'select' && type != 'bfecg_church') ...[
                      const SizedBox(height: AppDimensions.paddingS),
                      if (type == 'boolean')
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Standardwert'),
                          value: boolDefault,
                          onChanged: (v) => setSheet(() => boolDefault = v),
                        )
                      else
                        TextField(
                          controller: defaultController,
                          keyboardType: type == 'number' ? TextInputType.number : TextInputType.text,
                          decoration: InputDecoration(
                            labelText: isEdit ? 'Standardwert' : 'Standardwert (optional)',
                          ),
                        ),
                    ],
                    if (isEdit && isPerson) ...[
                      const SizedBox(height: AppDimensions.paddingS),
                      TextButton(
                        onPressed: resetValues,
                        child: const Text('Alle Werte auf Standard zurücksetzen',
                            style: TextStyle(color: AppColors.warning)),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.paddingM),
                    ElevatedButton(
                      onPressed: submit,
                      child: Text(isEdit ? 'Übernehmen' : 'Feld hinzufügen'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      nameController.dispose();
      defaultController.dispose();
      for (final c in options) {
        c.dispose();
      }
    });
  }

  static dynamic _parseDefault(String type, String text) {
    if (type == 'number') return num.tryParse(text.trim()) ?? 0;
    return text;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Future<void> _confirmLeave() async {
    final leave = await DialogHelper.showConfirmation(
      context,
      title: 'Ungespeicherte Änderungen',
      message: 'Du hast ungespeicherte Änderungen. Möchtest du die Seite trotzdem verlassen?',
      confirmText: 'Verwerfen',
      isDestructive: true,
    );
    if (leave && mounted) {
      setState(() => _hasChanges = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kirchen vorladen (Standardwert für BFECG-Gemeinde)
    ref.watch(churchesProvider);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Zusatzfelder'),
          actions: [
            IconButton(
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          children: [
            _buildSection(ExtraFieldTarget.person, 'Zusätzliche Felder für Personen'),
            const SizedBox(height: AppDimensions.paddingL),
            _buildSection(ExtraFieldTarget.song, 'Zusätzliche Felder für Werke'),
            const SizedBox(height: AppDimensions.paddingL),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ExtraFieldTarget target, String title) {
    final fields = _fields(target);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Neues Feld hinzufügen',
              onPressed: () => _addField(target),
            ),
          ],
        ),
        Card(
          child: fields.isEmpty
              ? const ListTile(title: Text('Es wurden noch keine zusätzlichen Felder hinzugefügt.'))
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: fields.length,
                  onReorder: (o, n) => _reorder(target, o, n),
                  itemBuilder: (context, i) {
                    final f = fields[i];
                    final lines = <String>[
                      if (f.id != 'bfecg_church') 'Typ: ${extraFieldTypeName(f.type)}',
                      'Anzeige: ${f.displayMode == 'underneath' ? 'Unter dem Namen' : 'Als Chip'}',
                      if (target == ExtraFieldTarget.person && (f.visibleToPlayers ?? false))
                        'Für Mitglieder sichtbar${(f.editableByPlayers ?? false) ? ' (bearbeitbar)' : ''}',
                    ];
                    return ListTile(
                      key: ValueKey('${target.name}-${f.id}-$i'),
                      title: Text(f.name),
                      subtitle: Text(lines.join('\n')),
                      isThreeLine: lines.length > 2,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                            onPressed: () => _editField(target, i),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                            onPressed: () => _removeField(target, i),
                          ),
                          if (fields.length > 1)
                            ReorderableDragStartListener(
                              index: i,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
