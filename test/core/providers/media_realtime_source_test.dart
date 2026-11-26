import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// MEDIA_REALTIME: source-analysis checks for realtime wiring and haptics.
void main() {
  final realtime = File('lib/core/providers/realtime_providers.dart').readAsStringSync();
  final members =
      File('lib/features/redesign/presentation/pages/rd_members_page.dart').readAsStringSync();
  final pending =
      File('lib/features/redesign/presentation/pages/rd_pending_page.dart').readAsStringSync();

  group('Multi-Tenant Security: realtime providers', () {
    test('every postgres channel filters by tenantId', () {
      final channels = RegExp(r'\.onPostgresChanges\(').allMatches(realtime).length;
      final tenantFilters = RegExp(r"column: 'tenantId',").allMatches(realtime).length;
      // person_attendances has no tenantId column (documented exception;
      // the refetch itself is tenant-filtered).
      final documentedExceptions =
          RegExp(r'person_attendances has no tenantId column').allMatches(realtime).length +
              // Supabase does not filter DELETE events by column; they are
              // received unfiltered and matched by id / refetched tenant-filtered.
              RegExp(r'event: PostgresChangeEvent\.delete,').allMatches(realtime).length;
      expect(channels, greaterThan(0));
      expect(tenantFilters + documentedExceptions, channels);
    });

    test('unused realtimeSongsProvider / RealtimeManager are removed', () {
      expect(realtime, isNot(contains('realtimeSongsProvider')));
      expect(realtime, isNot(contains('class RealtimeManager')));
    });
  });

  test('members and pending pages use the realtime provider (Ionic pending-player-changes)', () {
    expect(members, contains('ref.watch(realtimePendingPlayersProvider)'));
    expect(members, isNot(contains('ref.watch(pendingPlayersProvider)')));
    expect(pending, contains('ref.watch(realtimePendingPlayersProvider)'));
    expect(pending, isNot(contains('ref.watch(pendingPlayersProvider)')));
  });

  test('haptics on destructive confirmations and attendance recording', () {
    final dialog = File('lib/core/utils/dialog_helper.dart').readAsStringSync();
    final event =
        File('lib/features/redesign/presentation/pages/rd_event_page.dart').readAsStringSync();
    final eventEdit =
        File('lib/features/redesign/presentation/pages/rd_event_edit_page.dart').readAsStringSync();
    expect(dialog, contains('if (isDestructive) HapticHelper.medium();'));
    expect(event, contains('HapticHelper.light();'));
    expect(eventEdit, contains('HapticHelper.medium();'));
  });
}
