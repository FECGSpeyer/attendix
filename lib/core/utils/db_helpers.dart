import 'dart:math';

/// DB_FIX: Dart port of Ionic `src/app/utilities/db-helpers.ts`
/// (pickPersonFields) and `Utils.getId()`.
///
/// Every write to `player` must go through [pickPersonFields] so that
/// client-only model fields (e.g. `telegramId`) never reach PostgREST
/// (PGRST204 "column not found" fails the whole statement).

/// Columns of `player` that Ionic's `pickPersonFields` writes, restricted to
/// the columns that exist in the schema (`supabase.ts` player Row).
///
/// Intentionally excluded (like Ionic):
///   - `img`        — written only through the image upload paths
///   - `sort_order` — written only by the manual reorder
/// The pickPersonFields extras that are not DB columns (mobile, street, zip,
/// city, title, registration_date, gender, place_of_birth, nationality,
/// iban, bic, bank) are not part of the Person model and are left out.
const Set<String> kPlayerWritableColumns = {
  'id',
  'tenantId',
  'firstName',
  'lastName',
  'birthday',
  'email',
  'phone',
  'instrument',
  'instruments',
  'playsSince',
  'isLeader',
  'isCritical',
  'hasTeacher',
  'teacher',
  'history',
  'created_at',
  'joined',
  'left',
  'legacyId',
  'legacyConductorId',
  'notes',
  'testResult',
  'examinee',
  'correctBirthday',
  'criticalReason',
  'appId',
  'additional_fields',
  'paused',
  'paused_until',
  'pending',
  'self_register',
  'parent_id',
  'shift_id',
  'shift_name',
  'shift_start',
  'range',
  'otherExercise',
  'otherOrchestras',
  'lastSolve',
  'global_person_id',
};

/// Timestamp columns that reject empty strings (Ionic normalises '' → null).
const Set<String> _playerTimestampColumns = {
  'birthday',
  'joined',
  'left',
  'paused_until',
  'registration_date',
  'lastSolve',
  'shift_start',
  'playsSince',
  'created_at',
};

/// Ionic `pickPersonFields`: keep only writable `player` columns, normalise
/// blank timestamps to null and coerce `criticalReason` (int column; the
/// Flutter model keeps it as String) to an int.
Map<String, dynamic> pickPersonFields(Map<String, dynamic> person) {
  final picked = <String, dynamic>{};
  for (final entry in person.entries) {
    if (!kPlayerWritableColumns.contains(entry.key)) continue;
    var value = entry.value;
    if (_playerTimestampColumns.contains(entry.key) && value == '') {
      value = null;
    }
    if (entry.key == 'criticalReason' && value is String) {
      value = int.tryParse(value);
    }
    picked[entry.key] = value;
  }
  return picked;
}

/// Ionic `pickGroupFields` (db-helpers.ts): writable `instruments` columns.
const Set<String> kGroupWritableColumns = {
  'id',
  'tenantId',
  'name',
  'category',
  'synonyms',
  'notes',
  'sort_order',
  'maingroup',
  'clefs',
  'range',
  'tuning',
  'created_at',
  'legacyId',
};

/// Ionic `pickGroupFields`: keep only writable `instruments` columns.
Map<String, dynamic> pickGroupFields(Map<String, dynamic> group) => {
      for (final e in group.entries)
        if (kGroupWritableColumns.contains(e.key)) e.key: e.value,
    };

final Random _idRandom = Random();

/// Ionic `Utils.getId()`: random id in [1000000000, 999999999999].
/// Ionic addPlayer sets the player id client-side with this.
int generateIonicId() {
  const min = 1000000000;
  const max = 999999999999;
  // Random.nextInt is limited to 2^32, so combine two draws.
  final span = max - min + 1;
  final high = _idRandom.nextInt(1 << 20);
  final low = _idRandom.nextInt(1 << 30);
  return min + ((high * (1 << 30) + low) % span);
}
