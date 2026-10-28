import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/utils/file_mime.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/songs/presentation/widgets/copy_to_tenant_sheet.dart';
import 'package:attendix/features/team_organization/presentation/widgets/quick_create_attendance.dart';
import 'package:attendix/features/tenant_selection/tenant_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('songs/import uses the effective song library', () {
    final src = _read('lib/data/repositories/import_repository.dart');
    final page = _read('lib/features/songs/presentation/pages/song_import_page.dart');

    test('duplicate check and insert use songTenantId ?? currentTenantId', () {
      expect(src, contains('final libraryTenantId = songTenantId ?? currentTenantId;'));
      expect(src, contains(".eq('tenantId', libraryTenantId)"));
      expect(src, contains("data['tenantId'] = songTenantId ?? currentTenantId;"));
    });

    test('page passes the song source tenant', () {
      expect(page, contains('getExistingSongKeys(songTenantId: settings.songSourceTenantId)'));
      expect(page, contains('insertSong(row.data, songTenantId: songTenantId)'));
    });
  });

  test('history add dialog loads songs from the song repository (paged, source tenant)', () {
    final src = _read('lib/core/providers/history_providers.dart');
    final start = src.indexOf('final planSongsProviderHistory');
    final body = src.substring(start);
    expect(body, contains('songTenantSettingsProvider.future'));
    expect(body, contains('repo.getSongs()'));
    expect(body, isNot(contains(".from('songs')")));
  });

  group('copy to instance', () {
    test('instrument_ids = mapped target ids without null/1/2, first-seen order', () {
      expect(copiedSongInstrumentIds([5, null, 1, 2, 7, 5, 3]), [5, 7, 3]);
      expect(copiedSongInstrumentIds([null, 1, 2]), isEmpty);
    });

    test('a failed download aborts the copy', () {
      final src = _read('lib/features/songs/presentation/widgets/copy_to_tenant_sheet.dart');
      expect(src, isNot(contains('if (bytes == null) continue;')));
      expect(src, contains('throw l10n.songsFlutterFileDownloadFailed(file.fileName);'));
    });
  });

  group('song file MIME (Ionic file.type)', () {
    test('known extensions map to the browser MIME type', () {
      expect(songFileMimeType('mp4'), 'video/mp4');
      expect(songFileMimeType('MOV'), 'video/quicktime');
      expect(songFileMimeType('mid'), 'audio/midi');
      expect(songFileMimeType('musicxml'), 'application/vnd.recordare.musicxml+xml');
      expect(songFileMimeType('pdf'), 'application/pdf');
    });

    test('unknown extensions have no type (empty fileType like the browser)', () {
      expect(songFileMimeType('mscz'), isNull);
      final src = _read('lib/core/services/song_file_service.dart');
      expect(src, contains("'fileType': songFileMimeType(file.extension ?? '') ?? '',"));
    });

    test('file_uploaded tracks the mime', () {
      final src = _read('lib/features/settings/presentation/pages/files_page.dart');
      expect(src, contains("'mime': songFileMimeType(f.extension ?? '')"));
      expect(src, isNot(contains("'mime': null")));
    });
  });

  group('song realtime DELETE', () {
    test('only deletes of loaded songs are relevant', () {
      final songs = [const Song(id: 1, name: 'A'), const Song(id: 2, name: 'B')];
      expect(isRelevantSongDelete({'id': 2}, songs), isTrue);
      expect(isRelevantSongDelete({'id': 99}, songs), isFalse);
      expect(isRelevantSongDelete({}, songs), isFalse);
      expect(isRelevantSongDelete({'id': 99}, null), isTrue);
    });

    test('delete listeners are registered without a column filter', () {
      for (final path in [
        'lib/core/providers/song_providers.dart',
        'lib/core/providers/realtime_providers.dart',
      ]) {
        final src = _read(path);
        final deletes = RegExp(r'event: PostgresChangeEvent\.delete,[^)]*?callback', dotAll: true)
            .allMatches(src)
            .map((m) => m.group(0)!)
            .toList();
        expect(deletes, isNotEmpty, reason: path);
        for (final d in deletes) {
          expect(d, isNot(contains('filter:')), reason: path);
        }
      }
    });
  });

  test('songTenantSettings race: providers await the song source tenant', () {
    final songs = _read('lib/core/providers/song_providers.dart');
    final current = songs.substring(songs.indexOf('final currentSongsProvider'));
    expect(current.substring(0, 200), contains('await _readySongRepository(ref)'));
    final planning = _read('lib/features/planning/presentation/pages/planning_page.dart');
    final plan = planning.substring(planning.indexOf('final planSongsProvider'));
    expect(plan.substring(0, 250), contains('songTenantSettingsProvider.future'));
    final service = _read('lib/core/services/song_file_service.dart');
    expect(service, contains('final readySongFileServiceProvider'));
  });

  test('song list has an offline cache (Ionic offline_songs_v1_<tid>)', () {
    final src = _read('lib/data/repositories/song_repository.dart');
    expect(src, contains("'offline_songs_v1_\$tenantId'"));
    expect(src, contains('_readOfflineSongs(tenantId)'));
  });

  group('team-org quick create', () {
    const type = AttendanceType(
      id: 't1',
      name: 'Probe',
      defaultStatus: AttendanceStatus.present,
      startTime: '19:00',
      endTime: '21:00',
    );

    test('row carries is_org_plan', () {
      expect(newAttendanceRow(type, DateTime(2026, 11, 3), isOrgPlan: true)['is_org_plan'], isTrue);
      expect(newAttendanceRow(type, DateTime(2026, 11, 3))['is_org_plan'], isFalse);
    });

    test('persons with a shift go through ShiftUtils.getStatusByShift', () {
      final src = _read('lib/features/team_organization/presentation/widgets/quick_create_attendance.dart');
      expect(src, contains('ShiftUtils.getStatusByShift('));
      final rows = newPersonAttendanceRows([
        {'id': 1, 'shift_id': 'abc', 'shift_start': '2026-01-01', 'shift_name': 'A'},
        {'id': 2},
      ], type, DateTime(2026, 11, 3));
      expect(rows, hasLength(2));
      final repo = _read('lib/data/repositories/protocol_repository.dart');
      expect(repo, contains("select('id, instrument, additional_fields, shift_id, shift_start, shift_name')"));
    });
  });

  group('tenant creation', () {
    test('super developer is always ADMIN, creator too unless super dev', () {
      final rows = buildNewTenantUsers(tenantId: 7, userId: 'u1', email: 'a@b.de');
      expect(rows, hasLength(2));
      expect(rows[0]['userId'], superDeveloperUserId);
      expect(rows[0]['email'], 'developer@attendix.de');
      expect(rows.every((r) => r['role'] == Role.admin.value && r['tenantId'] == 7), isTrue);
      expect(rows[1]['userId'], 'u1');

      final dev = buildNewTenantUsers(tenantId: 7, userId: superDeveloperUserId, email: 'developer@attendix.de');
      expect(dev, hasLength(1));
    });

    test('timezone comes from the device and the page navigates like Ionic', () {
      final payload = buildNewTenantPayload(shortName: 'a', longName: 'b', type: 'choir', timezone: 'America/New_York');
      expect(payload['timezone'], 'America/New_York');
      final page = _read('lib/features/tenant_selection/presentation/pages/tenant_create_page.dart');
      expect(page, contains('timezone: deviceTimezone()'));
      expect(page, contains('context.l10n.dbInstanceCreated'));
      expect(page, contains('context.go(Role.admin.defaultRoute)'));
    });
  });

  test('message detail: lookup in all user tenants and switch instance', () {
    final repo = _read('lib/data/repositories/message_repository.dart');
    expect(repo, contains("final tenantIds = {currentTenantId, ...userTenantIds}.toList();"));
    expect(repo, contains(".inFilter('tenantId', tenantIds)"));
    final page = _read('lib/features/messages/presentation/pages/message_detail_page.dart');
    expect(page, contains('_switchTenantIfNeeded(message)'));
    expect(page, contains('currentTenantProvider.notifier).setTenant(tenant)'));
  });

  test('meeting_created is not tracked (not an Ionic event)', () {
    expect(_read('lib/core/providers/meeting_providers.dart'), isNot(contains('meetingCreated')));
  });
}
