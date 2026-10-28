// SOL_FIX4: paginated backfill queries (player_repository) and the shift
// recalculation trigger on the person detail page.
import 'dart:io';

import 'package:attendix/core/utils/people_shift_status.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Body of a method starting at [signature] up to the next doc comment of
/// the following member.
String _method(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNot(-1), reason: '$signature not found');
  final end = source.indexOf('\n  /// ', start + signature.length);
  return source.substring(start, end == -1 ? source.length : end);
}

void main() {
  group('Multi-Tenant Security: SOL_FIX4 paginated backfill', () {
    final src = _read('lib/data/repositories/player_repository.dart');

    for (final signature in [
      'Future<void> addPlayerToAttendancesByDate(',
      'Future<void> addToUpcomingAttendances(',
      'Future<void> syncPlayerWithUpcomingAttendances(',
      'Future<Set<String>> _existingAttendanceIds(',
    ]) {
      test('$signature loads all pages with stable order and tenant filter', () {
        final body = _method(src, signature);
        expect(body, contains('fetchAllPages<'));
        expect(body, contains(".order('id', ascending: true)"));
        expect(body, contains('.range(from, to)'));
        expect(
          body,
          anyOf(
            contains(".eq('tenantId', targetTenantId)"),
            contains(".eq('tenantId', currentTenantId)"),
            contains(".eq('attendance.tenantId', tenantId ?? currentTenantId)"),
          ),
        );
      });
    }
  });

  group('SOL_FIX4 shiftAssignmentChanged', () {
    bool changed({
      String? oldId = 's1',
      String? oldName = 'Früh',
      String? oldStart = '2026-01-05T00:00:00.000',
      String? newId = 's1',
      String? newName = 'Früh',
      DateTime? newStart,
      bool keepStart = true,
    }) =>
        shiftAssignmentChanged(
          oldShiftId: oldId,
          oldShiftName: oldName,
          oldShiftStart: oldStart,
          newShiftId: newId,
          newShiftName: newName,
          newShiftStart: keepStart ? DateTime.parse('2026-01-05T00:00:00.000') : newStart,
        );

    test('no change', () => expect(changed(), isFalse));
    test('plan id change', () => expect(changed(newId: 's2'), isTrue));
    test('shift name change with the same plan',
        () => expect(changed(newName: 'Spät'), isTrue));
    test('start date change with the same plan', () {
      expect(changed(keepStart: false, newStart: DateTime(2026, 2, 1)), isTrue);
      expect(changed(keepStart: false, newStart: null), isTrue);
    });
    test('start date set for the first time',
        () => expect(changed(oldStart: null), isTrue));
    test('empty and null are the same', () {
      expect(
        shiftAssignmentChanged(
          oldShiftId: '',
          oldShiftName: null,
          oldShiftStart: null,
          newShiftId: null,
          newShiftName: '',
          newShiftStart: null,
        ),
        isFalse,
      );
    });

    test('person detail save uses all three shift fields', () {
      final page =
          _read('lib/features/people/presentation/pages/person_detail_page.dart');
      final idx = page.indexOf('if (shiftAssignmentChanged(');
      expect(idx, isNot(-1));
      final call = page.substring(idx, page.indexOf('updateShiftAssignmentsForPerson', idx));
      expect(call, contains('oldShiftName: person.shiftName'));
      expect(call, contains('oldShiftStart: person.shiftStart'));
      expect(call, contains('newShiftStart: _shiftStart'));
      expect(page, isNot(contains('if (_selectedShiftId != person.shiftId)')));
    });
  });
}
