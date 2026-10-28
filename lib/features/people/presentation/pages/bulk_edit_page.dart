import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';

/// A field that can be bulk edited.
class _FieldOption {
  const _FieldOption({
    required this.key,
    required this.label,
    this.extraField,
  });

  /// 'instrument', 'isLeader', 'notes', 'phone' or `extra_<id>`
  final String key;
  final String label;
  final ExtraField? extraField;

  bool get isExtra => extraField != null;
  FieldType? get fieldType =>
      extraField == null ? null : FieldType.fromValue(extraField!.type);
}

/// Bulk edit one field for many persons (Ionic people/bulk-edit).
///
/// Returns `true` via Navigator.pop when persons were updated.
class BulkEditPage extends ConsumerStatefulWidget {
  const BulkEditPage({super.key, required this.players});

  final List<Person> players;

  @override
  ConsumerState<BulkEditPage> createState() => _BulkEditPageState();
}

class _BulkEditPageState extends ConsumerState<BulkEditPage> {
  late final List<_FieldOption> _fieldOptions;
  _FieldOption? _selected;
  final Map<int, dynamic> _original = {};
  final Map<int, dynamic> _edited = {};
  dynamic _bulkValue;
  bool _isSaving = false;

  /// Bumped when values change externally so text fields re-initialise.
  int _version = 0;

  List<Person> get _players =>
      widget.players.where((p) => p.id != null).toList();

  @override
  void initState() {
    super.initState();
    final tenant = ref.read(currentTenantProvider);
    _fieldOptions = [
      const _FieldOption(key: 'instrument', label: 'Gruppe'),
      const _FieldOption(key: 'isLeader', label: 'Stimmführer'),
      const _FieldOption(key: 'notes', label: 'Notizen'),
      const _FieldOption(key: 'phone', label: 'Telefon'),
      for (final f in tenant?.additionalFields ?? const <ExtraField>[])
        _FieldOption(key: 'extra_${f.id}', label: f.name, extraField: f),
    ];
  }

  dynamic _valueOf(Person p, _FieldOption field) {
    if (field.isExtra) return p.additionalFields?[field.extraField!.id];
    return switch (field.key) {
      'instrument' => p.instrument,
      'isLeader' => p.isLeader,
      'notes' => p.notes,
      'phone' => p.phone,
      _ => null,
    };
  }

  dynamic _defaultBulkValue(_FieldOption field, List<Group> groups) {
    if (!field.isExtra) {
      return switch (field.key) {
        'instrument' => groups.isNotEmpty ? groups.first.id : null,
        'isLeader' => false,
        _ => '',
      };
    }
    final def = field.extraField!.defaultValue;
    return switch (field.fieldType) {
      FieldType.boolean => def is bool ? def : false,
      FieldType.select => def ??
          ((field.extraField!.options?.isNotEmpty ?? false)
              ? field.extraField!.options!.first
              : null),
      FieldType.number => def,
      _ => def ?? '',
    };
  }

  void _onFieldSelected(String? key, List<Group> groups) {
    final field = _fieldOptions.where((f) => f.key == key).firstOrNull;
    setState(() {
      _selected = field;
      _original.clear();
      _edited.clear();
      _version++;
      if (field != null) {
        _bulkValue = _defaultBulkValue(field, groups);
        for (final p in _players) {
          final v = _valueOf(p, field);
          _original[p.id!] = v;
          _edited[p.id!] = v;
        }
      }
    });
  }

  void _applyToAll() {
    setState(() {
      for (final p in _players) {
        _edited[p.id!] = _bulkValue;
      }
      _version++;
    });
  }

  int get _changedCount =>
      _players.where((p) => _original[p.id] != _edited[p.id]).length;

  Future<void> _save() async {
    final field = _selected;
    if (field == null || _changedCount == 0) return;

    setState(() => _isSaving = true);
    final repo = ref.read(playerRepositoryWithTenantProvider);
    final changed = _changedCount;
    try {
      // (old person, updated person) pairs for the attendance sync
      final toSync = <(Person, Person)>[];
      await Future.wait(_players
          .where((p) => _original[p.id] != _edited[p.id])
          .map((p) async {
        final value = _edited[p.id];
        if (!field.isExtra) {
          await repo.updatePlayerFields(p.id!, {field.key: value});
          if (field.key == 'instrument') {
            toSync.add((p, p.copyWith(instrument: value as int?)));
          }
        } else {
          final merged = <String, dynamic>{
            ...?p.additionalFields,
            field.extraField!.id: value,
          };
          await repo.updatePlayerFields(p.id!, {'additional_fields': merged});
          toSync.add((p, p.copyWith(additionalFields: merged)));
        }
      }));

      // PEOPLE2: Ionic bulk-edit → syncPlayerWithUpcomingAttendances: a group
      // or filter field change adds/removes the person in upcoming
      // attendances. Best effort: the edit itself already succeeded.
      for (final (old, updated) in toSync) {
        try {
          await repo.syncPlayerWithUpcomingAttendances(
            updated,
            oldInstrument: old.instrument,
            oldAdditionalFields: old.additionalFields,
          );
        } catch (_) {}
      }

      ref.invalidate(playersProvider);
      if (!mounted) return;
      ToastHelper.showSuccess(context, '$changed Person(en) aktualisiert');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Fehler beim Speichern');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider).valueOrNull ?? const <Group>[];
    final churches = ref.watch(churchesProvider).valueOrNull ?? const <Church>[];
    final field = _selected;
    final hasExtra = _fieldOptions.any((f) => f.isExtra);

    String groupName(int? id) =>
        groups.where((g) => g.id == id).map((g) => g.name).firstOrNull ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk-Bearbeitung'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: field?.key,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Feld auswählen'),
            hint: const Text('Feld wählen...'),
            items: [
              const DropdownMenuItem<String>(
                enabled: false,
                child: Text('Standard-Felder',
                    style: TextStyle(color: AppColors.medium, fontSize: 12)),
              ),
              for (final f in _fieldOptions.where((f) => !f.isExtra))
                DropdownMenuItem(value: f.key, child: Text(f.label)),
              if (hasExtra) ...[
                const DropdownMenuItem<String>(
                  enabled: false,
                  child: Text('Zusatzfelder',
                      style: TextStyle(color: AppColors.medium, fontSize: 12)),
                ),
                for (final f in _fieldOptions.where((f) => f.isExtra))
                  DropdownMenuItem(value: f.key, child: Text(f.label)),
              ],
            ],
            onChanged: (key) => _onFieldSelected(key, groups),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          if (field == null)
            const Padding(
              padding: EdgeInsets.only(top: AppDimensions.paddingXL),
              child: Column(
                children: [
                  Icon(Icons.edit_note, size: 48, color: AppColors.medium),
                  SizedBox(height: AppDimensions.paddingS),
                  Text(
                    'Wähle ein Feld aus, um die Werte für alle Personen zu bearbeiten.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.medium),
                  ),
                ],
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Für alle setzen',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppDimensions.paddingS),
                    _ValueEditor(
                      key: ValueKey('bulk-${field.key}'),
                      field: field,
                      value: _bulkValue,
                      groups: groups,
                      churches: churches,
                      onChanged: (v) => setState(() => _bulkValue = v),
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _applyToAll,
                        icon: const Icon(Icons.done_all),
                        label: const Text('Für alle setzen'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Text('Personen (${_players.length})',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppDimensions.paddingS),
            Card(
              child: Column(
                children: [
                  for (final p in _players)
                    Container(
                      color: _original[p.id] != _edited[p.id]
                          ? AppColors.primary.withAlpha(20)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingM,
                        vertical: AppDimensions.paddingS,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${p.firstName} ${p.lastName}',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(p.groupName ?? groupName(p.instrument),
                                    style: const TextStyle(
                                        color: AppColors.medium, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppDimensions.paddingS),
                          Expanded(
                            child: _ValueEditor(
                              key: ValueKey('${field.key}-${p.id}-$_version'),
                              field: field,
                              value: _edited[p.id],
                              groups: groups,
                              churches: churches,
                              dense: true,
                              onChanged: (v) => setState(() => _edited[p.id!] = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            FilledButton(
              onPressed: _changedCount == 0 || _isSaving ? null : _save,
              child: Text(_isSaving
                  ? 'Speichern...'
                  : _changedCount > 0
                      ? (_changedCount == 1
                          ? '1 Änderung speichern'
                          : '$_changedCount Änderungen speichern')
                      : 'Keine Änderungen'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Editor for one value of the selected field.
class _ValueEditor extends StatelessWidget {
  const _ValueEditor({
    super.key,
    required this.field,
    required this.value,
    required this.groups,
    required this.churches,
    required this.onChanged,
    this.dense = false,
  });

  final _FieldOption field;
  final dynamic value;
  final List<Group> groups;
  final List<Church> churches;
  final ValueChanged<dynamic> onChanged;
  final bool dense;

  Widget _text({TextInputType? keyboard, String? hint, bool number = false}) {
    return TextFormField(
      initialValue: value?.toString() ?? '',
      keyboardType: keyboard,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(hintText: hint, isDense: dense),
      onChanged: (v) {
        if (number) {
          onChanged(v.trim().isEmpty ? null : num.tryParse(v.replaceAll(',', '.')));
        } else {
          onChanged(v);
        }
      },
    );
  }

  Widget _dropdown<T>(List<DropdownMenuItem<T>> items, String hint) {
    final values = items.map((i) => i.value).toSet();
    return DropdownButtonFormField<T>(
      // ignore: deprecated_member_use
      value: values.contains(value) ? value as T : null,
      isExpanded: true,
      decoration: InputDecoration(isDense: dense),
      hint: Text(hint),
      items: items,
      onChanged: (v) => onChanged(v),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!field.isExtra) {
      switch (field.key) {
        case 'instrument':
          return _dropdown<int?>(
            [for (final g in groups) DropdownMenuItem(value: g.id, child: Text(g.name))],
            dense ? 'Gruppe...' : 'Gruppe wählen...',
          );
        case 'isLeader':
          return Align(
            alignment: Alignment.centerRight,
            child: Switch(value: value == true, onChanged: onChanged),
          );
        case 'notes':
          return _text(hint: 'Notiz...');
        case 'phone':
          return _text(keyboard: TextInputType.phone, hint: 'Telefon...');
      }
    }

    final options = field.extraField?.options ?? const <String>[];
    switch (field.fieldType) {
      case FieldType.number:
        return _text(
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            hint: field.label,
            number: true);
      case FieldType.boolean:
        return Align(
          alignment: Alignment.centerRight,
          child: Switch(value: value == true, onChanged: onChanged),
        );
      case FieldType.select:
        return _dropdown<String>(
          [for (final o in options) DropdownMenuItem(value: o, child: Text(o))],
          field.label,
        );
      case FieldType.bfecgChurch:
        return _dropdown<String>(
          [
            for (final c in churches)
              if (c.id != null) DropdownMenuItem(value: c.id!, child: Text(c.name)),
          ],
          field.label,
        );
      case FieldType.date:
        final current = DateTime.tryParse(value?.toString() ?? '');
        return OutlinedButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: current ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              locale: const Locale('de', 'DE'),
            );
            if (picked != null) onChanged(DateFormat('yyyy-MM-dd').format(picked));
          },
          child: Text(current != null
              ? DateFormat('dd.MM.yyyy').format(current)
              : 'Datum wählen'),
        );
      default:
        return _text(hint: field.label);
    }
  }
}
