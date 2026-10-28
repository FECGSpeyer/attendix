import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Repository für Zusatzfelder (tenants.additional_fields / song_additional_fields)
/// und das Bereinigen der Werte in player/songs.
class ExtraFieldsRepository extends BaseRepository with TenantAwareRepository {
  ExtraFieldsRepository(super.ref);

  /// Speichert die Felddefinitionen der aktuellen Instanz.
  Future<void> saveFields({
    required List<ExtraField> personFields,
    required List<ExtraField> songFields,
  }) async {
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

  Future<List<Map<String, dynamic>>> _loadRows(String table) async {
    final response = await supabase
        .from(table)
        .select('id, additional_fields')
        .eq('tenantId', currentTenantId);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> _updateRow(String table, int id, Map<String, dynamic> fields) async {
    await supabase
        .from(table)
        .update({'additional_fields': fields})
        .eq('id', id)
        .eq('tenantId', currentTenantId);
  }

  /// Entfernt Werte gelöschter Felder, ergänzt fehlende Standardwerte und
  /// korrigiert ungültige Auswahlwerte (player bzw. songs).
  Future<void> sanitizeValues({
    required String table,
    required List<ExtraField> definitions,
    List<Object>? churchIds,
  }) async {
    try {
      final rows = await _loadRows(table);
      final validIds = definitions.map((f) => f.id).toSet();
      for (final row in rows) {
        final fields = Map<String, dynamic>.from((row['additional_fields'] as Map?) ?? {});
        var changed = false;

        for (final key in fields.keys.toList()) {
          if (!validIds.contains(key)) {
            fields.remove(key);
            changed = true;
          }
        }

        for (final def in definitions) {
          final cur = fields[def.id];
          if (cur == null) {
            fields[def.id] = extraFieldDefaultValue(def.type,
                defaultValue: def.defaultValue, options: def.options, churchIds: churchIds);
            changed = true;
          } else if (def.type == 'select' && def.options != null && !def.options!.contains(cur)) {
            fields[def.id] = extraFieldDefaultValue(def.type, defaultValue: def.defaultValue, options: def.options);
            changed = true;
          }
        }

        if (changed) {
          await _updateRow(table, row['id'] as int, fields);
        }
      }
    } catch (e, stack) {
      // Wie Ionic: Bereinigung ist best effort
      if (kDebugMode) debugPrint('[ExtraFieldsRepository] sanitizeValues($table) failed: $e\n$stack');
    }
  }

  /// Ersetzt [oldValue] durch [newValue] für ein Feld bei allen Personen.
  /// Gibt die Anzahl aktualisierter Personen zurück.
  Future<int> updateFieldValue(String fieldId, dynamic oldValue, dynamic newValue) async {
    try {
      final rows = await _loadRows('player');
      var count = 0;
      for (final row in rows) {
        final fields = Map<String, dynamic>.from((row['additional_fields'] as Map?) ?? {});
        if (fields[fieldId] == oldValue) {
          fields[fieldId] = newValue;
          await _updateRow('player', row['id'] as int, fields);
          count++;
        }
      }
      return count;
    } catch (e, stack) {
      handleError(e, stack, 'updateFieldValue');
      rethrow;
    }
  }

  /// Setzt den Wert eines Feldes bei allen Personen auf [defaultValue].
  Future<int> resetFieldValues(String fieldId, dynamic defaultValue) async {
    try {
      final rows = await _loadRows('player');
      var count = 0;
      for (final row in rows) {
        final fields = Map<String, dynamic>.from((row['additional_fields'] as Map?) ?? {});
        if (fields[fieldId] == defaultValue) continue;
        fields[fieldId] = defaultValue;
        await _updateRow('player', row['id'] as int, fields);
        count++;
      }
      return count;
    } catch (e, stack) {
      handleError(e, stack, 'resetFieldValues');
      rethrow;
    }
  }
}
