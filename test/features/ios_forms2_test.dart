// IOS_FORMS2: iOS look of "Termin hinzufügen", Werke, Werkhistorie,
// Dateiablage and the Übersicht data like Ionic.
import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/features/attendance/presentation/pages/attendance_create_page.dart';
import 'package:attendix/features/attendance/presentation/widgets/ion_glyph_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

const _duty = AttendanceType(id: 'd', name: 'Dienst', dutyMode: true);

void main() {
  group('Termin hinzufügen (iOS)', () {
    Future<void> pump(WidgetTester tester, TargetPlatform platform) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visibleAttendanceTypesProvider.overrideWith(
              (ref) async => const [
                AttendanceType(
                  id: 't1',
                  name: 'Generalprobe mit sehr langem Namen für den Test',
                ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.forPlatform(Brightness.light, platform).copyWith(platform: platform),
            home: const AttendanceCreatePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('"Typ" stays on one line next to a long type name ($platform)',
          (tester) async {
        await pump(tester, platform);
        final label = tester.getSize(find.text('Typ'));
        expect(label.height, lessThan(30));
        expect(label.width, greaterThan(label.height));
      });
    }

    testWidgets('iOS: select ⇅, plain "i", stadium submit row', (tester) async {
      await pump(tester, TargetPlatform.iOS);
      expect(find.byType(IonChevronExpandIcon), findsOneWidget);
      expect(find.byType(IonInformationIcon), findsOneWidget);
      expect(find.byType(DropdownButton<AttendanceType>), findsNothing);
      expect(find.text('Generalprobe mit sehr langem Namen für den Test'), findsOneWidget);
      final stadium = find.byWidgetPredicate(
        (w) => w is Material && w.shape is StadiumBorder,
      );
      expect(stadium, findsWidgets);
      expect(
        find.descendant(of: stadium, matching: find.text('Termin hinzufügen')),
        findsOneWidget,
      );
    });

    testWidgets('Material keeps the dropdown', (tester) async {
      await pump(tester, TargetPlatform.android);
      expect(find.byType(DropdownButton<AttendanceType>), findsOneWidget);
      expect(find.byType(IonChevronExpandIcon), findsNothing);
    });
  });

  group('Übersicht like Ionic', () {
    final repo = _read('lib/data/repositories/sign_in_out_repository.dart');
    final method = repo.substring(
      repo.indexOf('Future<List<CrossTenantPersonAttendance>> _ownAttendancesOfTenant'),
      repo.indexOf('static String tenantDisplayName'),
    );

    test('query uses the Ionic columns (no place / plan) and keeps the tenant filter', () {
      expect(method, contains('kOverviewAttendanceColumns'));
      expect(method, contains(".eq('attendance.tenantId', tenantId)"));
      expect(method, contains(".eq('tenantId', tenantId)"));
      final cols = RegExp(r"const String kOverviewAttendanceColumns =([^;]*);")
          .firstMatch(repo)!
          .group(1)!;
      expect(cols, isNot(contains('place')));
      expect(cols, isNot(contains('plan')));
      expect(cols, contains('files_folder'));
    });

    test('unassigned duty Termine are not filtered out', () {
      expect(method, isNot(contains('duty_mode')));
    });

    test('unassigned duty Termine count for the average', () {
      CrossTenantPersonAttendance att(String date, AttendanceStatus s, {String? duty}) =>
          CrossTenantPersonAttendance(
            id: date,
            date: date,
            status: s,
            attendanceType: _duty,
            dutyState: duty,
            tenantId: 1,
            tenantName: 'T',
            tenantColor: '#000000',
          );
      final data = buildOverviewData([
        att('2026-01-10T12:00:00', AttendanceStatus.present, duty: 'confirmed'),
        att('2026-01-11T12:00:00', AttendanceStatus.neutral),
      ], now: DateTime(2026, 6));
      expect(data.past, hasLength(2));
      expect(data.stats.percentage, 50);
    });
  });

  group('Werkhistorie / Dateiablage / Werke (source)', () {
    test('Werkhistorie opens as an iOS card sheet from Mehr, route kept', () {
      final history = _read('lib/features/history/presentation/pages/history_page.dart');
      expect(history, contains('Future<void> showHistoryModal('));
      expect(history, contains('useRootNavigator: true'));
      expect(history, contains("context.push('/history')"));
      final settings = _read('lib/features/settings/presentation/pages/settings_page.dart');
      expect(settings, contains('showHistoryModal(context)'));
      final router = _read('lib/core/router/app_router.dart');
      expect(router, contains("path: '/history'"));
    });

    test('Dateiablage header buttons in glass circles', () {
      final files = _read('lib/features/settings/presentation/pages/files_page.dart');
      expect(files, contains('IosCircleIcon(icon: Icons.arrow_back'));
      expect(files, contains('ToolbarButtonGroup(children: ['));
    });

    test('Werke filter in a glass circle, detail actions grouped', () {
      final list = _read('lib/features/songs/presentation/pages/songs_list_page.dart');
      expect(list, contains('IosCircleIcon(icon: Icons.tune'));
      final detail = _read('lib/features/songs/presentation/pages/song_detail_page.dart');
      expect(detail, contains('ToolbarButtonGroup(children: ['));
      expect(detail, contains('class _FilesGroup'));
    });
  });
}
