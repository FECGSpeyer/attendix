// U1: Person bearbeiten, Verlauf and Neue Person in the new design (Beta).
// Without the Beta the old pages keep their Ionic look (FAB, accordions).
import 'dart:io';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/church_providers.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/parent_providers.dart';
import 'package:attendix/core/providers/shift_providers.dart';
import 'package:attendix/core/providers/teacher_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/people/presentation/pages/person_create_page.dart';
import 'package:attendix/features/people/presentation/pages/person_detail_page.dart';
import 'package:attendix/features/people/presentation/widgets/ion/ion_widgets.dart';
import 'package:attendix/features/people/presentation/widgets/person_detail/person_detail.dart'
    show upcomingAttendancesProvider;
import 'package:attendix/features/redesign/presentation/pages/rd_person_history_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../mocks/supabase_mocks.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref);

  @override
  Future<void> setTenant(Tenant? tenant) async {}
}

final _person = TestFactories.createPerson(id: 1, firstName: 'Anna', lastName: 'Beispiel')
    .copyWith(email: 'anna@example.org', phone: '0176 1234567');

final _auth = () {
  final auth = MockGoTrueClient();
  when(() => auth.currentUser).thenReturn(null);
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  return auth;
}();

ThemeData _beta() => buildRdTheme(RdFarbwelt.petrol, Brightness.light).copyWith(platform: TargetPlatform.iOS);
ThemeData _ionic() => AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS, web: false);

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget home) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      supabaseAuthProvider.overrideWithValue(_auth),
      currentUserProvider.overrideWith((ref) => Stream.value(null)),
      currentAuthUserIdProvider.overrideWithValue(null),
      groupsProvider.overrideWith((ref) async => const []),
      groupsMapProvider.overrideWith((ref) async => const {}),
      churchesProvider.overrideWith((ref) async => const []),
      teachersProvider.overrideWith((ref) async => const []),
      parentsProvider.overrideWith((ref) async => const []),
      shiftsProvider.overrideWith((ref) async => const []),
      currentRoleProvider.overrideWithValue(Role.admin),
      effectiveRoleProvider.overrideWithValue(Role.admin),
      personProvider(1).overrideWith((ref) async => _person),
      personAttendanceStatsProvider(1).overrideWith(
          (ref) async => {'total': 0, 'attended': 0, 'percentage': 0, 'lateCount': 0, 'lateCountExcused': 0}),
      personHistoryProvider(1).overrideWith((ref) async => const []),
      upcomingAttendancesProvider(1).overrideWith((ref) async => [
            {'date': '2026-11-03', 'meetingName': 'Probe', 'status': 1, 'notes': null},
          ]),
    ],
    child: MaterialApp(
      theme: theme,
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  ));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Neue Person', () {
    testWidgets('Beta: Speichern in the header, fields in a card, no FAB', (tester) async {
      await _pump(tester, _beta(), const PersonCreatePage());
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(IonFabButton), findsNothing);
      expect(find.widgetWithText(TextButton, 'Speichern'), findsOneWidget);
    });

    testWidgets('without the Beta the FAB stays', (tester) async {
      await _pump(tester, _ionic(), const PersonCreatePage());
      expect(find.byType(IonFabButton), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Speichern'), findsNothing);
    });
  });

  group('Person bearbeiten', () {
    testWidgets('Beta: the FAB action sits in the header', (tester) async {
      await _pump(tester, _beta(), const PersonDetailPage(personId: 1));
      expect(find.byType(IonFabButton), findsNothing);
      // E-mail without account → "Account erstellen" (key), like the FAB.
      expect(find.widgetWithIcon(IconButton, Icons.key_outlined), findsOneWidget);
    });

    testWidgets('editing: the phone number gets its own Anrufen button', (tester) async {
      tester.view.physicalSize = const Size(393, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(tester, _beta(), const PersonDetailPage(personId: 1));
      // A tap on the row opens the editor, calling is the button next to it.
      if (find.text('0176 1234567').evaluate().isEmpty) {
        await tester.tap(find.text('Allgemein').first);
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('0176 1234567'), findsOneWidget);
      expect(find.byTooltip('Anrufen'), findsOneWidget);
    });

    testWidgets('without the Beta the FAB stays', (tester) async {
      await _pump(tester, _ionic(), const PersonDetailPage(personId: 1));
      expect(find.byType(IonFabButton), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.key_outlined), findsNothing);
    });
  });

  group('Verlauf', () {
    testWidgets('shows the coming Termine and the history', (tester) async {
      await _pump(tester, _beta(), const RdPersonHistoryPage(personId: 1));
      expect(find.text('Verlauf'), findsOneWidget);
      expect(find.text('Anna Beispiel'), findsOneWidget);
      expect(find.textContaining('Probe'), findsOneWidget);
      expect(find.text('Historie'), findsOneWidget);
    });

    test('route of the new design', () {
      expect(RedesignRoutes.personHistory(5), '/mitglieder/5/verlauf');
      expect(RedesignRoutes.isRedesignRoute('/mitglieder/5/verlauf'), isTrue);
      final router = File('lib/core/router/app_router.dart').readAsStringSync();
      expect(router, contains("name: 'redesignPersonHistory'"));
      final page = File('lib/features/redesign/presentation/pages/rd_person_page.dart').readAsStringSync();
      expect(page, contains('RedesignRoutes.personHistory(personId)'));
    });
  });

  group('IonAccordion', () {
    testWidgets('Beta: section heading, content in a card, toggles', (tester) async {
      var toggled = 0;
      await _pump(
        tester,
        _beta(),
        Scaffold(
          body: IonAccordion(
            title: 'Allgemein',
            expanded: true,
            onToggle: () => toggled++,
            child: const Text('Inhalt'),
          ),
        ),
      );
      final card = find.ancestor(of: find.text('Inhalt'), matching: find.byType(Container)).first;
      final deco = tester.widget<Container>(card).decoration as BoxDecoration?;
      expect(deco?.borderRadius, isNotNull);
      await tester.tap(find.text('Allgemein'));
      expect(toggled, 1);

      // Keyboard: Tab focuses the heading, Enter and Space toggle.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(toggled, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(toggled, 3);
    });

    testWidgets('Beta: screen reader gets a button with title and expanded state', (tester) async {
      final handle = tester.ensureSemantics();
      Future<void> pumpWith(bool expanded) => _pump(
            tester,
            _beta(),
            Scaffold(
              body: IonAccordion(title: 'Account', expanded: expanded, onToggle: () {}, child: const Text('Inhalt')),
            ),
          );
      await pumpWith(false);
      expect(
        tester.getSemantics(find.text('Account')),
        matchesSemantics(
          label: 'Account',
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      await pumpWith(true);
      expect(
        tester.getSemantics(find.text('Account')),
        matchesSemantics(
          label: 'Account',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('Verlauf: a missing person shows "gibt es nicht mehr" with retry', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
          supabaseAuthProvider.overrideWithValue(_auth),
          currentRoleProvider.overrideWithValue(Role.admin),
          personProvider(2).overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: _beta(),
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RdPersonHistoryPage(personId: 2),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Diese Person gibt es hier nicht mehr.'), findsOneWidget);
      expect(find.text('Erneut versuchen'), findsOneWidget);
    });

    testWidgets('Verlauf: a load error shows it; Erneut versuchen and pull-to-refresh reload the person',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
          supabaseAuthProvider.overrideWithValue(_auth),
          currentRoleProvider.overrideWithValue(Role.admin),
          personProvider(3).overrideWith((ref) async {
            calls++;
            if (calls == 1) throw Exception('Netzwerk weg');
            return _person;
          }),
          personAttendanceStatsProvider(3).overrideWith(
              (ref) async => {'total': 0, 'attended': 0, 'percentage': 0, 'lateCount': 0, 'lateCountExcused': 0}),
          personHistoryProvider(3).overrideWith((ref) async => const []),
          upcomingAttendancesProvider(3).overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: _beta(),
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RdPersonHistoryPage(personId: 3),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      final l10n = await AppLocalizations.delegate.load(const Locale('de'));
      expect(find.text(l10n.redesignTodayLoadFailed), findsOneWidget);

      await tester.tap(find.text('Erneut versuchen'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 2);
      expect(find.text('Anna Beispiel'), findsOneWidget);
      expect(find.text('Historie'), findsOneWidget);

      await tester.fling(find.text('Verlauf'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(calls, 3);
    });
  });
}
