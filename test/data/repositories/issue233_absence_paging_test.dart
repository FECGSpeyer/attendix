import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// #233: tenant-wide absence loads must page through all rows.
void main() {
  String body(String path, String signature) {
    final s = File(path).readAsStringSync();
    final i = s.indexOf(signature);
    expect(i, isNonNegative, reason: signature);
    return s.substring(i, s.indexOf('handleError', i));
  }

  for (final (path, sig) in [
    ('lib/data/repositories/player_absence_repository.dart',
        'Future<List<PlayerAbsence>> getAbsencesForTenant()'),
    ('lib/data/repositories/dashboard_repository.dart',
        'Future<List<DashboardAbsence>> getAbsences()'),
  ]) {
    test('$sig is paged, ordered and tenant-filtered', () {
      final b = body(path, sig);
      expect(b, contains('fetchAllPages'));
      expect(b, contains(".order('id')"));
      expect(b, contains('.range(from, to)'));
      expect(b, contains(".eq('tenant_id', currentTenantId)"));
    });
  }
}
