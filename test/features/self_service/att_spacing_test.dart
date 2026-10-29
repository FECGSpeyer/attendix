// ATT_SPACING: vertical rhythm of "Meine Termine" and "Übersicht" on the
// iPhone like the Ionic iOS app (1rem = 17px, CSS `line-height: normal`,
// `.list-ios.list-inset` margin 16, item lines inside the 64pt min-height,
// overview `ion-segment { padding: 8px }` centred in the 74pt toolbar).
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/duty_providers.dart';
import 'package:attendix/core/providers/message_providers.dart';
import 'package:attendix/core/providers/player_absence_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/self_service_providers.dart';
import 'package:attendix/core/providers/signout_providers.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/self_service/data/providers/upcoming_songs_provider.dart';
import 'package:attendix/features/self_service/presentation/pages/self_service_overview_page.dart';
import 'package:attendix/features/self_service/presentation/pages/signout_page.dart';
import 'package:attendix/l10n/generated/app_localizations.dart';
import 'package:attendix/shared/widgets/adaptive/ion_toolbar_segment.dart';
import 'package:attendix/shared/widgets/event_list/event_list_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../factories/test_factories.dart';

/// No SharedPreferences mock: the tenant restore never reaches Supabase.
class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref);

  @override
  Future<void> setTenant(Tenant? tenant) async {}
}

const _type = AttendanceType(id: 'u', name: 'Übung');

/// 31 past Termine, 20 attended → "65 %" and "Alle 31 anzeigen".
List<CrossTenantPersonAttendance> _past() => [
      for (var i = 0; i < 31; i++)
        CrossTenantPersonAttendance(
          id: 'a$i',
          date: DateTime(2026, 9, 30).subtract(Duration(days: i)).toIso8601String(),
          status: i < 20 ? AttendanceStatus.present : AttendanceStatus.absent,
          attendanceType: _type,
          includeInAverage: true,
          tenantId: 1,
          tenantName: 'Chor',
          tenantColor: '#000000',
        ),
    ];

/// Wide enough that no label wraps with the 1em-wide glyphs of the test
/// font (the vertical rhythm does not depend on the width).
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
}

Widget _app(Widget page, List<Override> overrides) => ProviderScope(
      overrides: [
        effectiveRoleProvider.overrideWithValue(Role.player),
        currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
        unreadNotificationCountProvider.overrideWith((ref) async => 0),
        userNotificationsRealtimeProvider.overrideWith((ref) {}),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    );

Rect _rect(WidgetTester tester, Finder f) => tester.getRect(f);

/// Tops of the row titles (one per row).
List<double> _rowTops(WidgetTester tester) => find
    .text('Übung')
    .evaluate()
    .map((e) => tester.getRect(find.byElementPredicate((x) => x == e)).top)
    .toList()
  ..sort();

void main() {
  setUpAll(() => initializeDateFormatting());

  group('Übersicht (iOS)', () {
    Future<void> pump(WidgetTester tester) async {
      _phone(tester);
      final atts = _past();
      await tester.pumpWidget(_app(const SelfServiceOverviewPage(), [
        allPersonAttendancesAcrossTenantsProvider.overrideWith((ref) async => atts),
      ]));
      await tester.pumpAndSettle();
    }

    testWidgets('segment: 64pt track (8pt page padding) centred in the toolbar',
        (tester) async {
      await pump(tester);
      final bar = _rect(tester, find.byType(IonToolbarSegment<String>));
      final track = _rect(
        tester,
        find
            .descendant(
                of: find.byType(IonToolbarSegment<String>),
                matching: find.byType(Container))
            .first,
      );
      expect(bar.height, 74);
      expect(track.height, 64);
      // toolbar padding 3 + (68 − 64) / 2
      expect(track.top - bar.top, 5);
      // 8pt padding around the 48pt (44 + 2 × 2) buttons
      final label = _rect(tester, find.text('Chronologisch'));
      expect(label.center.dy, closeTo(track.center.dy, 0.5));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('rows 80pt apart, list margin 16, "Alle anzeigen" inside',
        (tester) async {
      await pump(tester);
      final tops = _rowTops(tester);
      expect(tops.length, 3);
      expect(tops[1] - tops[0], closeTo(80, 0.5));
      expect(tops[2] - tops[1], closeTo(80, 0.5));

      // "Vergangen" → list margin 16 → label margin 10 → title
      final past = _rect(tester, find.text('Vergangen'));
      expect(tops[0] - past.bottom, closeTo(26, 0.5));

      // row 80 − label margin 10 + more-link padding 14
      final more = _rect(tester, find.text('Alle 31 anzeigen'));
      expect(more.top - tops[2], closeTo(84, 0.5));

      // ev-section h2 1.35rem with line-height normal
      final title = tester.widget<Text>(find.text('Vergangen'));
      expect(title.style?.fontSize, closeTo(22.95, 0.01));
      final row = tester.widget<Text>(find.text('Übung').first);
      expect(row.style?.fontSize, 17);
      expect(row.style?.fontWeight, FontWeight.w600);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('empty state: 17pt in --ion-color-medium, margin 12',
        (tester) async {
      await pump(tester);
      final text = tester.widget<Text>(find.text('Keine anstehenden Termine'));
      expect(text.style?.fontSize, 17);
      expect(text.style?.color, const Color(0xFF636469));
      final empty = _rect(tester, find.text('Keine anstehenden Termine'));
      final upcoming = _rect(tester, find.text('Anstehend'));
      expect(empty.top - upcoming.bottom, closeTo(12, 0.5));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('Meine Termine (iOS)', () {
    Future<void> pump(WidgetTester tester) async {
      _phone(tester);
      final past = _past();
      await tester.pumpWidget(_app(const SignoutPage(), [
        userTenantsProvider.overrideWith((ref) async => const <Tenant>[]),
        isApplicantProvider.overrideWithValue(false),
        currentSelfServicePlayerProvider.overrideWith(
            (ref) async => TestFactories.createPerson(id: 1, firstName: 'Leon')),
        signoutDataProvider.overrideWith(
            (ref) async => SignoutData(past: past, percentage: 65)),
        myDutyOverviewProvider.overrideWith((ref) async => const MyDutyOverview()),
        upcomingSongsProvider.overrideWith((ref) async => const []),
        canSelfPauseProvider.overrideWithValue(false),
        canSelfReportAbsenceProvider.overrideWithValue(false),
        canAccessFilesProvider.overrideWithValue(false),
        teamOrgEnabledProvider.overrideWithValue(false),
      ]));
      await tester.pumpAndSettle();
    }

    testWidgets('greeting fits the 48pt avatar row; "Vergangen" 22pt below',
        (tester) async {
      await pump(tester);
      final greeting = _rect(tester, find.text('Shalom Leon!'));
      final past = _rect(tester, find.text('Vergangen'));
      // h1 22.95 + 2 + p 14.875 (line-height normal) = 47.1 < 48:
      // 48 − 0.44 + ev-section padding 22 (Ionic ≈70, was 75)
      expect(past.top - greeting.top, closeTo(69.56, 0.5));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('summary, 64pt rows and "Alle 31 anzeigen" like Ionic',
        (tester) async {
      await pump(tester);
      final past = _rect(tester, find.text('Vergangen'));
      final perc = _rect(tester, find.text('65%'));
      // list margin 16 + ev-summary padding 14
      expect(perc.top - past.bottom, closeTo(30, 0.5));

      final tops = _rowTops(tester);
      expect(tops.length, 3);
      // the inner line lies inside the 64pt min-height
      expect(tops[1] - tops[0], closeTo(64, 0.01));
      expect(tops[2] - tops[1], closeTo(64, 0.01));

      // title centred in the 64pt row (label 60pt) → row end + 14 padding
      final more = _rect(tester, find.text('Alle 31 anzeigen'));
      expect(more.top - tops[2], closeTo(66, 0.5));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('md keeps its metrics', () {
    testWidgets('EventListCard margin 6 / EventRow title 16 on Android',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Column(children: [
            EventListCard(plain: true, children: [
              EventRow(date: '2026-09-01', title: 'Übung'),
              EventRow(date: '2026-09-02', title: 'Probe'),
            ]),
          ]),
        ),
      ));
      final title = tester.widget<Text>(find.text('Übung'));
      expect(title.style?.fontSize, 16);
      final a = _rect(tester, find.byType(EventRow).first);
      final b = _rect(tester, find.byType(EventRow).last);
      expect(a.top, 6);
      // line inside the row on md too
      expect(b.top - a.top, a.height);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
