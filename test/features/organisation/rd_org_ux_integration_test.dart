import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/organisation_providers.dart';
import 'package:attendix/core/providers/plan_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/organisation/organisation.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/features/attendance/presentation/pages/rd_events_page.dart';
import 'package:attendix/features/organisation/presentation/widgets/rd_org_info_sheet.dart';
import 'package:attendix/features/organisation/presentation/widgets/rd_org_plans_ui.dart';
import 'package:attendix/features/planning/presentation/pages/plan_viewer_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:attendix/shared/shell/rd_sidebar.dart';
import 'package:attendix/shared/widgets/redesign/rd_group_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../factories/test_factories.dart';

final _tenantHome = TestFactories.createTenant(id: 7, shortName: 'PC', longName: 'Posaunenchor');
final _tenantOther = TestFactories.createTenant(id: 8, shortName: 'JC', longName: 'Jugendchor');
final _tenantExternal = TestFactories.createTenant(id: 9, shortName: 'EX', longName: 'Gastgruppe');
const _org = Organisation(id: 42, name: 'FECG Speyer');

class _FixedTenant extends CurrentTenantNotifier {
  _FixedTenant(super.ref) {
    state = _tenantHome;
  }
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) => ProviderScope(
      overrides: [
        currentTenantProvider.overrideWith(_FixedTenant.new),
        effectiveRoleProvider.overrideWithValue(Role.admin),
        ...overrides,
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        home: Scaffold(body: child),
      ),
    );

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  group('rdTodayOrgPlans', () {
    final now = DateTime(2026, 11, 27, 12, 45);
    const fields = [
      PlanField(id: '1', name: '123', time: '5'),
      PlanField(id: '2', name: 'Trefft', time: '60'),
    ];

    test('picks today ad-hoc and other-group ORG plans, sorts live first, skips own & unpublished', () {
      final own = OrgPlanEntry.attendance(PlanAttendance(
        id: 1,
        tenantId: 7,
        tenantName: 'Posaunenchor',
        date: '2026-11-27',
        isOrgPlan: true,
        plan: const Plan(title: 'Eigene Probe', time: '12:30', fields: fields),
      ));
      final otherLater = OrgPlanEntry.attendance(PlanAttendance(
        id: 2,
        tenantId: 8,
        tenantName: 'Jugendchor',
        date: '2026-11-27',
        isOrgPlan: true,
        plan: const Plan(title: 'Abendprobe', time: '19:00', fields: fields),
      ));
      final adHocLive = OrgPlanEntry.adHoc(const SharedPlan(
        id: 'sp1',
        editKey: 'k',
        planTitle: 'Wortunterhaltung',
        date: '2026-11-27',
        time: '12:35',
        fields: fields,
      ));
      final unpublished = OrgPlanEntry.adHoc(const SharedPlan(
        id: 'sp2',
        editKey: 'k',
        planTitle: 'Entwurf',
        date: '2026-11-27',
        time: '12:35',
        fields: fields,
        unpublished: true,
      ));
      final tomorrow = OrgPlanEntry.adHoc(const SharedPlan(
        id: 'sp3',
        editKey: 'k',
        planTitle: 'Morgen',
        date: '2026-11-28',
        time: '12:35',
        fields: fields,
      ));

      final items = rdTodayOrgPlans(
        [own, otherLater, adHocLive, unpublished, tomorrow],
        currentTenantId: 7,
        now: now,
      );
      expect(items.map((i) => i.entry.title), ['Wortunterhaltung', 'Abendprobe']);
      expect(items.first.isLive, isTrue);
      expect(items.first.currentItem, 'Trefft');
      expect(items.last.isLive, isFalse);
    });
  });

  group('PlanViewerPage origin context', () {
    testWidgets('shows origin badge, hint, custom back label, and switch-group action', (tester) async {
      var switched = false;
      await tester.pumpWidget(_wrap(
        PlanViewerPage(
          attendance: const PlanAttendance(
            id: 5,
            date: '2026-11-27',
            plan: Plan(
              title: 'Wortunterhaltung',
              time: '12:32',
              fields: [PlanField(id: 'a', name: 'Trefft', time: '30')],
            ),
          ),
          backLabel: 'Schließen',
          originBadge: 'ORG · Jugendchor',
          originHint: 'FECG Speyer',
          openInGroupAction: (label: 'In „JC“ öffnen', onTap: () => switched = true),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Schließen'), findsOneWidget);
      expect(find.byKey(const Key('rd-plan-view-origin')), findsOneWidget);
      expect(find.text('ORG · Jugendchor'), findsOneWidget);
      expect(find.text('FECG Speyer'), findsOneWidget);
      await tester.tap(find.byKey(const Key('rd-plan-view-switch-group')));
      expect(switched, isTrue);
    });
  });

  group('RdTodayOrgPlansCard', () {
    testWidgets('renders today ORG plan card with ORG badge when org & entry exist', (tester) async {
      final today = _isoDay(DateTime.now());
      final entry = OrgPlanEntry.adHoc(SharedPlan(
        id: 'sp1',
        editKey: 'k',
        planTitle: 'Wortunterhaltung',
        date: today,
        time: '19:00',
        fields: const [PlanField(id: 'a', name: 'Gesang', time: '10')],
      ));

      await tester.pumpWidget(_wrap(
        const RdTodayOrgPlansCard(),
        overrides: [
          currentOrganisationProvider.overrideWith((_) async => _org),
          orgPlansProvider.overrideWith((_) async => [entry]),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rd-today-org-plans-card')), findsOneWidget);
      expect(find.text('Wortunterhaltung'), findsOneWidget);
      expect(find.text('FECG Speyer'), findsOneWidget);
      expect(find.text('Ohne Termin'), findsOneWidget);
    });

    testWidgets('renders nothing without an organisation', (tester) async {
      await tester.pumpWidget(_wrap(
        const RdTodayOrgPlansCard(),
        overrides: [
          currentOrganisationProvider.overrideWith((_) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rd-today-org-plans-card')), findsNothing);
    });
  });

  group('RdEventsPage 3rd segment Org-Pläne & ORG pill', () {
    testWidgets('shows Org-Pläne segment & ORG pill on own org Termin when org exists', (tester) async {
      final today = _isoDay(DateTime.now());
      final ownOrgTermin = Attendance(
        id: 101,
        tenantId: 7,
        date: today,
        typeInfo: 'Konzert',
        isOrgPlan: true,
      );
      final orgEntry = OrgPlanEntry.adHoc(SharedPlan(
        id: 'sp-9',
        editKey: 'k',
        planTitle: 'Wortunterhaltung',
        date: today,
        time: '12:32',
        fields: const [PlanField(id: '1', name: 'Trefft', time: '20')],
      ));

      final router = GoRouter(
        initialLocation: '/termine',
        routes: [
          GoRoute(path: '/termine', builder: (_, __) => const RdEventsPage()),
          GoRoute(path: '/settings/org-plans', builder: (_, __) => const Scaffold(body: Text('org-plans-page'))),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentTenantProvider.overrideWith(_FixedTenant.new),
          effectiveRoleProvider.overrideWithValue(Role.admin),
          canCreateAttendanceProvider.overrideWithValue(false),
          currentOrganisationProvider.overrideWith((_) async => _org),
          orgPlansProvider.overrideWith((_) async => [orgEntry]),
          realtimeAttendanceListProvider.overrideWith((_) async => [ownOrgTermin]),
          attendanceTypesProvider.overrideWith((_) async => const []),
        ],
        child: MaterialApp.router(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();

      // Own ORG Termin shows the ORG pill in Kommend.
      expect(find.text('Konzert'), findsOneWidget);
      expect(find.text('FECG Speyer'), findsOneWidget);
      // 3rd segment "Org-Pläne" is visible.
      expect(find.text('Org-Pläne'), findsOneWidget);

      await tester.tap(find.text('Org-Pläne'));
      await tester.pumpAndSettle();

      expect(find.text('Wortunterhaltung'), findsOneWidget);
      expect(find.text('Ohne Termin'), findsOneWidget);
    });
  });

  group('RdGroupSwitchSheet organisation grouping', () {
    testWidgets('groups org tenants under org badge with manage link for leads', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, __) => Scaffold(
              body: TextButton(
                onPressed: () => showRdGroupSwitchSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
          GoRoute(path: '/settings/org-settings', builder: (_, __) => const Scaffold(body: Text('org-settings'))),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentTenantProvider.overrideWith(_FixedTenant.new),
          effectiveRoleProvider.overrideWithValue(Role.admin),
          userTenantsProvider.overrideWith((_) async => [_tenantHome, _tenantOther, _tenantExternal]),
          currentOrganisationProvider.overrideWith((_) async => _org),
          linkedTenantsProvider.overrideWith((_) async => [_tenantOther]),
        ],
        child: MaterialApp.router(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('FECG Speyer'), findsOneWidget);
      expect(find.text('Organisation verwalten'), findsOneWidget);
      expect(find.text('WEITERE GRUPPEN'), findsOneWidget);
      expect(find.text('Posaunenchor'), findsOneWidget);
      expect(find.text('Jugendchor'), findsOneWidget);
      expect(find.text('Gastgruppe'), findsOneWidget);
    });
  });

  group('RdOrgInfoSheet', () {
    testWidgets('opens from tappable org pill and explains shared vs. group-local items', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showRdOrgInfoSheet(context),
            child: const Text('open-info'),
          ),
        ),
        overrides: [
          currentOrganisationProvider.overrideWith((_) async => _org),
          allLinkedTenantsProvider.overrideWith((_) async => [_tenantHome, _tenantOther]),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open-info'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('rd-org-info-sheet')), findsOneWidget);
      expect(find.text('FECG Speyer'), findsOneWidget);
      expect(find.text('2 verbundene Gruppen'), findsOneWidget);
      expect(find.text('Posaunenchor · Diese Gruppe'), findsOneWidget);
      expect(find.text('Jugendchor'), findsOneWidget);
      expect(find.text('Org-Pläne'), findsOneWidget);
      expect(find.textContaining('Team-Aufgaben gehören immer nur zu deiner jeweiligen Gruppe'), findsOneWidget);
      expect(find.byKey(const Key('rd-org-info-manage')), findsOneWidget);
    });
  });

  group('RdSidebar orgPlans routing', () {
    test('maps /settings/org-plans to RdSideExtra.orgPlans for leads', () {
      expect(
        rdSideExtraFor('/settings/org-plans', manage: true, team: false),
        RdSideExtra.orgPlans,
      );
      expect(
        rdSideExtraFor('/settings/org-plans/planung', manage: true, team: false),
        RdSideExtra.orgPlans,
      );
      expect(
        rdSideExtraFor('/settings/org-plans', manage: false, team: false),
        isNull,
      );
    });
  });
}
