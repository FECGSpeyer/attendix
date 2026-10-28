import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// MEDIA_REALTIME: source-analysis checks for realtime wiring and haptics.
void main() {
  final realtime = File('lib/core/providers/realtime_providers.dart').readAsStringSync();
  final settings =
      File('lib/features/settings/presentation/pages/settings_page.dart').readAsStringSync();

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

  test('settings pending card uses the realtime provider (Ionic pending-player-changes)', () {
    expect(settings, contains('ref.watch(realtimePendingPlayersProvider)'));
    expect(settings, isNot(contains('ref.watch(pendingPlayersProvider)')));
  });

  test('haptics on people remove/pause and history delete (Ionic Haptics.impact)', () {
    final people =
        File('lib/features/people/presentation/pages/people_list_page.dart').readAsStringSync();
    final history =
        File('lib/features/history/presentation/pages/history_page.dart').readAsStringSync();
    expect(
      RegExp(r'_removePlayer\(Person person\) async \{\s*HapticHelper\.medium\(\)').hasMatch(people),
      isTrue,
    );
    expect(
      RegExp(r'_showPauseDialog\(Person person\) async \{\s*HapticHelper\.light\(\)').hasMatch(people),
      isTrue,
    );
    expect(history, contains('HapticHelper.medium()'));
  });
}
