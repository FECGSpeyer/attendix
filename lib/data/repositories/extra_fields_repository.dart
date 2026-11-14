import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/helper_member.dart';
import '../../core/utils/paged_query.dart';
import '../models/tenant/tenant.dart';
import 'base_repository.dart';

/// Provider (ohne Tenant – nutze extraFieldsRepositoryWithTenantProvider)
final extraFieldsRepositoryProvider = Provider<ExtraFieldsRepository>((ref) {
  return ExtraFieldsRepository(ref);
});

/// Standardwert eines Zusatzfeldes (wie Utils.getFieldTypeDefaultValue in Ionic).
dynamic extraFieldDefaultValue(
  String type, {
  dynamic defaultValue,
  List<String>? options,
  List<Object>? churchIds,
}) {
  if (defaultValue != null) return defaultValue;
  if (type == 'bfecg_church' && (churchIds?.isNotEmpty ?? false)) return churchIds!.first;
  if (type == 'select') return (options?.isNotEmpty ?? false) ? options!.first : '';
  switch (type) {
    case 'text':
    case 'textarea':
      return '';
    case 'number':
      return 0;
    case 'date':
      return DateTime.now().toUtc().toIso8601String();
    case 'boolean':
      return true;
    default:
      return '';
  }
}

/// JSON eines Zusatzfeldes im Ionic-Format (camelCase-Keys, wie in tenants.additional_fields).
Map<String, dynamic> extraFieldToJson(ExtraField f) => {
      'id': f.id,
      'name': f.name,
      'type': f.type,
      'defaultValue': f.defaultValue,
      'options': f.options ?? <String>[],
      'visibleToPlayers': f.visibleToPlayers ?? false,
      'editableByPlayers': f.editableByPlayers ?? false,
      'displayMode': f.displayMode ?? 'chip',
    };

/// Whether [key] of `additional_fields` is an internal key of the app (e.g.
/// [helperUntilKey], `_handover_request`) and not the value of a Zusatzfeld.
bool isInternalExtraFieldKey(String key) => key.startsWith('_') || key == helperUntilKey;

/// The cleaned values of one row, null when nothing changes: values of
/// deleted fields are removed, missing values get the default, an invalid
/// selection value gets the default. Internal keys
/// ([isInternalExtraFieldKey]) are kept; with [previousIds] (the field ids
/// before the save) only values of those fields are removed, so keys the
/// definitions never had stay untouched. [renamedOptions] (field id → old
/// option → new option) moves the values of a renamed option along.
Map<String, dynamic>? sanitizeExtraFieldValues(
  Map<String, dynamic> values,
  List<ExtraField> definitions, {
  List<Object>? churchIds,
  Set<String>? previousIds,
  Map<String, Map<String, String>>? renamedOptions,
}) {
  final fields = Map<String, dynamic>.from(values);
  final validIds = definitions.map((f) => f.id).toSet();
  var changed = false;

  for (final key in fields.keys.toList()) {
    if (validIds.contains(key) || isInternalExtraFieldKey(key)) continue;
    if (previousIds != null && !previousIds.contains(key)) continue;
    fields.remove(key);
    changed = true;
  }

  for (final def in definitions) {
    final cur = fields[def.id];
    if (cur == null) {
      fields[def.id] = extraFieldDefaultValue(def.type,
          defaultValue: def.defaultValue, options: def.options, churchIds: churchIds);
      changed = true;
    } else if (def.type == 'select' && def.options != null && !def.options!.contains(cur)) {
      final renamed = renamedOptions?[def.id]?[cur];
      fields[def.id] = renamed != null && def.options!.contains(renamed)
          ? renamed
          : extraFieldDefaultValue(def.type, defaultValue: def.defaultValue, options: def.options);
      changed = true;
    }
  }
  return changed ? fields : null;
}

/// Options of select fields renamed between [before] and [after] (field id →
/// old option → new option): with the same number of options, an old
/// option no longer present maps to the new one at its position, if that
/// one is new too.
Map<String, Map<String, String>> renamedExtraFieldOptions(List<ExtraField> before, List<ExtraField> after) {
  final result = <String, Map<String, String>>{};
  for (final next in after) {
    if (next.type != 'select') continue;
    final prev = before.where((f) => f.id == next.id && f.type == 'select').firstOrNull;
    final oldOptions = prev?.options ?? const <String>[];
    final newOptions = next.options ?? const <String>[];
    if (oldOptions.length != newOptions.length) continue;
    final map = <String, String>{};
    for (var i = 0; i < oldOptions.length; i++) {
      if (!newOptions.contains(oldOptions[i]) && !oldOptions.contains(newOptions[i])) {
        map[oldOptions[i]] = newOptions[i];
      }
    }
    if (map.isNotEmpty) result[next.id] = map;
  }
  return result;
}

/// Repository für Zusatzfelder (tenants.additional_fields / song_additional_fields)
/// und das Bereinigen der Werte in player/songs.
class ExtraFieldsRepository extends BaseRepository with TenantAwareRepository {
  ExtraFieldsRepository(super.ref);

  /// Speichert die Felddefinitionen der aktuellen Instanz.
  Future<void> saveFields({
    required List<ExtraField> personFields,
    required List<ExtraField> songFields,
  }) async {
    ensureNotDemo('saveFields'); // DEMO_GUARD
    try {
      await supabase.from('tenants').update({
        'additional_fields': personFields.map(extraFieldToJson).toList(),
        'song_additional_fields': songFields.map(extraFieldToJson).toList(),
      }).eq('id', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'saveFields');
      rethrow;
    }
  }

  /// Lädt `id, additional_fields` aller Zeilen von [table].
  /// [rowTenantId]: Instanz der Zeilen (Standard: aktuelle Instanz; für Werke
  /// die effektive Werk-Instanz `song_source_tenant_id ?? eigene Instanz`).
  /// [activeOnly]: nur aktive, nicht ausstehende Personen (Ionic db.getPlayers()).
  Future<List<Map<String, dynamic>>> _loadRows(
    String table, {
    int? rowTenantId,
    bool activeOnly = false,
  }) async {
    final tenantId = rowTenantId ?? currentTenantId;
    // DB_REVIEW_REST (M9): paged, more than 1000 persons/songs possible.
    final response = await fetchAllPages<dynamic>((from, to) async {
      var query = supabase
          .from(table)
          .select('id, additional_fields')
          .eq('tenantId', tenantId);
      if (activeOnly) {
        query = query.isFilter('left', null).isFilter('pending', false);
      }
      return await query.order('id', ascending: true).range(from, to) as List;
    });
    return response.cast<Map<String, dynamic>>();
  }

  /// Gibt zurück, ob tatsächlich eine Zeile aktualisiert wurde
  /// (nicht bei parallel gelöschter Zeile oder RLS).
  Future<bool> _updateRow(String table, int id, Map<String, dynamic> fields, {int? rowTenantId}) async {
    final tenantId = rowTenantId ?? currentTenantId;
    final updated = await supabase
        .from(table)
        .update({'additional_fields': fields})
        .eq('id', id)
        .eq('tenantId', tenantId)
        .select('id');
    return (updated as List).isNotEmpty;
  }

  /// Wie Ionic: einzelne fehlgeschlagene Updates werden übersprungen
  /// (nicht gezählt), statt den ganzen Vorgang abzubrechen.
  Future<bool> _tryUpdateRow(String table, int id, Map<String, dynamic> fields) async {
    try {
      return await _updateRow(table, id, fields);
    } catch (e) {
      if (kDebugMode) debugPrint('[ExtraFieldsRepository] update $table#$id failed: $e');
      return false;
    }
  }

  /// Entfernt Werte gelöschter Felder, ergänzt fehlende Standardwerte und
  /// korrigiert ungültige Auswahlwerte (player bzw. songs), siehe
  /// [sanitizeExtraFieldValues].
  /// Personen: nur aktive, nicht ausstehende (Ionic db.getPlayers()).
  /// Werke: [songTenantId] = effektive Werk-Instanz (Ionic db.getSongs()).
  Future<void> sanitizeValues({
    required String table,
    required List<ExtraField> definitions,
    List<Object>? churchIds,
    int? songTenantId,
    Set<String>? previousIds,
    Map<String, Map<String, String>>? renamedOptions,
  }) async {
    final isPlayer = table == 'player';
    final rowTenantId = isPlayer ? null : songTenantId;
    try {
      final rows = await _loadRows(table, rowTenantId: rowTenantId, activeOnly: isPlayer);
      for (final row in rows) {
        final fields = sanitizeExtraFieldValues(
          (row['additional_fields'] as Map?)?.cast<String, dynamic>() ?? const {},
          definitions,
          churchIds: churchIds,
          previousIds: previousIds,
          renamedOptions: renamedOptions,
        );
        if (fields != null) {
          await _updateRow(table, row['id'] as int, fields, rowTenantId: rowTenantId);
        }
      }
    } catch (e, stack) {
      // Wie Ionic: Bereinigung ist best effort
      if (kDebugMode) debugPrint('[ExtraFieldsRepository] sanitizeValues($table) failed: $e\n$stack');
    }
  }

  /// Ersetzt [oldValue] durch [newValue] für ein Feld bei allen Personen.
  /// Gibt die Anzahl erfolgreich aktualisierter Personen zurück; wirft nur,
  /// wenn die Personen nicht geladen werden können.
  Future<int> updateFieldValue(String fieldId, dynamic oldValue, dynamic newValue) async {
    ensureNotDemo('updateFieldValue'); // DEMO_GUARD
    final List<Map<String, dynamic>> rows;
    try {
      rows = await _loadRows('player');
    } catch (e, stack) {
      handleError(e, stack, 'updateFieldValue');
      rethrow;
    }
    var count = 0;
    for (final row in rows) {
      final fields = Map<String, dynamic>.from((row['additional_fields'] as Map?) ?? {});
      if (fields[fieldId] == oldValue) {
        fields[fieldId] = newValue;
        if (await _tryUpdateRow('player', row['id'] as int, fields)) count++;
      }
    }
    return count;
  }

  /// Setzt den Wert eines Feldes bei allen Personen auf [defaultValue].
  /// Gibt die Anzahl erfolgreich aktualisierter Personen zurück; wirft nur,
  /// wenn die Personen nicht geladen werden können.
  Future<int> resetFieldValues(String fieldId, dynamic defaultValue) async {
    ensureNotDemo('resetFieldValues'); // DEMO_GUARD
    final List<Map<String, dynamic>> rows;
    try {
      rows = await _loadRows('player');
    } catch (e, stack) {
      handleError(e, stack, 'resetFieldValues');
      rethrow;
    }
    var count = 0;
    for (final row in rows) {
      final fields = Map<String, dynamic>.from((row['additional_fields'] as Map?) ?? {});
      if (fields[fieldId] == defaultValue) continue;
      fields[fieldId] = defaultValue;
      if (await _tryUpdateRow('player', row['id'] as int, fields)) count++;
    }
    return count;
  }
}
