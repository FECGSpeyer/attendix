import 'dart:io';
import 'dart:typed_data';

import 'package:attendix/core/services/ai_service.dart';
import 'package:attendix/core/services/pdf_branding.dart';
import 'package:attendix/core/services/plan_export_service.dart';
import 'package:attendix/core/services/tracking/tracking_event.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/features/self_service/data/providers/upcoming_songs_provider.dart';
import 'package:attendix/features/self_service/presentation/widgets/upcoming_songs_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

/// MISC2: branding on exports, tracking call sites, AI synonyms,
/// "Alle Noten drucken".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Tenant Security - OrganisationSettingsRepository.getBrandingSource', () {
    late String source;
    setUpAll(() {
      source = File('lib/data/repositories/organisation_settings_repository.dart').readAsStringSync();
    });

    test('tenant branding fallback is limited to the current tenant', () {
      final m = RegExp(r"getBrandingSource\(\)[\s\S]*?\.from\('tenants'\)[^;]+").firstMatch(source);
      expect(m, isNotNull);
      expect(m!.group(0), contains(".eq('id', currentTenantId)"));
    });

    test('organisation is resolved via the current tenant', () {
      final m = RegExp(r"getCurrentOrganisation\(\) async[\s\S]*?maybeSingle").firstMatch(source);
      expect(m!.group(0), contains(".eq('tenant_id', currentTenantId)"));
    });
  });

  group('PdfBranding', () {
    test('fromSource returns null when nothing is configured', () async {
      expect(await PdfBranding.fromSource(), isNull);
      expect(await PdfBranding.fromSource(logoUrl: '', text: '  '), isNull);
    });

    test('fromSource keeps trimmed text without logo', () async {
      final b = await PdfBranding.fromSource(text: '  Musikverein  ');
      expect(b, isNotNull);
      expect(b!.text, 'Musikverein');
      expect(b.hasLogo, isFalse);
    });

    testWidgets('downscaleToPng caps the longest edge at 120px', (tester) async {
      final png = File('assets/icons/app_icon.png').readAsBytesSync();
      final result = await tester.runAsync(() => PdfBranding.downscaleToPng(png));
      expect(result, isNotNull);
      expect(result!.width <= 120 && result.height <= 120, isTrue);
      expect(result.png.sublist(1, 4), 'PNG'.codeUnits);
    });

    testWidgets('downscaleToPng returns null for undecodable bytes', (tester) async {
      final result = await tester.runAsync(
          () => PdfBranding.downscaleToPng(Uint8List.fromList([1, 2, 3, 4])));
      expect(result, isNull);
    });
  });

  group('PlanExportService with branding', () {
    const page = PlanExportPage(
      title: 'Probe',
      subtitle: 'Samstag, 18.10.2025',
      time: '17:00',
      fields: [PlanField(id: '1', name: 'Einspielen', time: '10')],
    );

    test('builds PDF with and without branding (A4 and 2x A5)', () async {
      const service = PlanExportService();
      const branding = PdfBranding(text: 'Musikverein Beispiel');
      final plain = await service.buildPdf([page]);
      final branded = await service.buildPdf([page], branding: branding);
      final twoUp = await service.buildPdf([page], sideBySide: true, branding: branding);
      for (final bytes in [plain, branded, twoUp]) {
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      }
      expect(branded.length, greaterThan(plain.length));
    });
  });

  group('Tracking events wire names', () {
    test('match Ionic tracking.service.ts', () {
      expect(TrackingEvent.login.wireName, 'login');
      expect(TrackingEvent.attendanceCheckIn.wireName, 'attendance_check_in');
      expect(TrackingEvent.parentSignOut.wireName, 'parent_signout');
      expect(TrackingEvent.fileUploaded.wireName, 'file_uploaded');
      expect(TrackingEvent.notificationSettingsChanged.wireName, 'notification_settings_changed');
    });

    test('call sites exist for all migrated events', () {
      String read(String p) => File(p).readAsStringSync();
      final expectations = {
        'lib/core/router/app_router.dart': ['TrackingEvent.login'],
        'lib/core/providers/signout_providers.dart': ['TrackingEvent.attendanceCheckIn', 'TrackingEvent.attendanceCheckOut'],
        'lib/features/parents/presentation/pages/parents_portal_page.dart': ['TrackingEvent.parentSignIn', 'TrackingEvent.parentSignOut'],
        'lib/features/songs/presentation/pages/song_detail_page.dart': ['TrackingEvent.songShared'],
        'lib/features/export/presentation/pages/export_page.dart': ['TrackingEvent.reportExported'],
        'lib/core/providers/player_providers.dart': ['TrackingEvent.playerAdded', 'TrackingEvent.playerUpdated', 'TrackingEvent.playerRemoved'],
        'lib/core/providers/teacher_providers.dart': ['TrackingEvent.teacherAdded', 'TrackingEvent.teacherUpdated'],
        'lib/core/providers/group_providers.dart': ['TrackingEvent.instrumentAdded', 'TrackingEvent.instrumentUpdated', 'TrackingEvent.instrumentRemoved'],
        'lib/features/notifications/presentation/pages/notifications_page.dart': ['TrackingEvent.notificationSettingsChanged'],
        'lib/features/settings/presentation/pages/files_page.dart': ['TrackingEvent.fileUploaded'],
        'lib/core/providers/meeting_providers.dart': ['TrackingEvent.meetingCreated'],
      };
      expectations.forEach((path, events) {
        final src = read(path);
        for (final e in events) {
          expect(src, contains(e), reason: '$e missing in $path');
        }
      });
    });
  });

  group('AiService.normalizeSynonyms', () {
    test('trims, removes quotes and joins with comma', () {
      expect(AiService.normalizeSynonyms('"Geige, Violine,  Fiddle."\n'), 'Geige, Violine, Fiddle');
      expect(AiService.normalizeSynonyms('Cello,,Violoncello'), 'Cello, Violoncello');
    });
  });

  group('collectCurrentSongPrintEntries', () {
    Song song(int id, List<SongFile> files) => Song(id: id, name: 'Werk $id', files: files);
    final groups = [
      UpcomingSongGroup(date: '01.01.2026', songs: [
        SongHistory(song: song(1, const [SongFile(url: 'a.pdf', fileName: 'a.pdf', fileType: 'pdf', instrumentId: 5)])),
        SongHistory(song: song(2, const [SongFile(url: 'b.pdf', fileName: 'b.pdf', fileType: 'pdf', note: 'Chor')])),
        SongHistory(song: song(3, const [SongFile(url: 'c.pdf', fileName: 'c.pdf', fileType: 'pdf', instrumentId: 9)])),
      ]),
    ];

    test('picks the file for the player instrument', () {
      final entries = collectCurrentSongPrintEntries(groups, 5, isChoir: false);
      expect(entries.map((e) => e.song.id), [1]);
    });

    test('choir falls back to files noted "Chor"', () {
      final entries = collectCurrentSongPrintEntries(groups, 5, isChoir: true);
      expect(entries.map((e) => e.song.id), [1, 2]);
    });
  });
}
