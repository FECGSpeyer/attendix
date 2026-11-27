import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Pre-existing bug fix (Sprint 2a Task 8): auth_service.dart used the
/// wrong table name `tenant_users` (snake_case) while the actual DB table
/// is `tenantUsers` (camelCase). Same for the columns `user_id` /
/// `tenant_id`. Confirmed by inspecting Ionic db.service.ts and
/// supabase/sql/enable_rls_all_tables.sql.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/core/services/auth/auth_service.dart').readAsStringSync();
  });

  test('uses tenantUsers (camelCase) table name', () {
    expect(source, contains("from('tenantUsers')"),
        reason: 'must target tenantUsers, the actual DB table name');
    expect(source, isNot(contains("from('tenant_users')")),
        reason: 'tenant_users (snake_case) is wrong — fixed in Sprint 2a');
  });

  test('uses camelCase column names for tenantUsers', () {
    // Spot-check that user_id / tenant_id no longer appear as bare
    // column names (they may still appear in code comments, so we only
    // check inside string literals).
    expect(source, isNot(contains("'user_id'")),
        reason: 'column name is userId, not user_id');
    expect(source, isNot(contains("'tenant_id'")),
        reason: 'column name is tenantId, not tenant_id');
  });
}
