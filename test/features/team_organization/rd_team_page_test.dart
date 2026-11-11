import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/data/models/team_org/team_org.dart';
import 'package:attendix/features/team_organization/presentation/pages/team_organization_page.dart';
import 'package:attendix/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

const _me = PersonRef(id: 1, firstName: 'Leon', lastName: 'Jäger');
const _anna = PersonRef(id: 2, firstName: 'Anna', lastName: 'Berg');

Widget _app({String? tab, bool leader = true, bool circle = true}) => ProviderScope(
      overrides: [
        redesignEnabledProvider.overrideWithValue(true),
        isTeamLeaderProvider.overrideWithValue(leader),
        inTeamCircleProvider.overrideWithValue(circle),
        teamPersonProvider.overrideWith((ref) async => TestFactories.createPerson(id: 1)),
        protocolTypesProvider.overrideWith(
            (ref) async => [const ProtocolType(id: 'lt', name: 'Leitungstreffen', enableProtocol: true)]),
        teamTasksProvider.overrideWith((ref) async => const [
              TeamTask(id: 't1', title: 'Raum reservieren', responsiblePersonId: 1, responsiblePerson: _me),
              TeamTask(id: 't2', title: 'Noten bestellen', responsiblePersonId: 2, responsiblePerson: _anna),
            ]),
        myTasksProvider.overrideWith((ref) async => const <TeamTask>[]),
        agendaItemsProvider.overrideWith(
            (ref) async => const [AgendaItem(id: 'a1', title: 'Ausflug', proposedBy: 2, proposalStatus: 'pending')]),
        protocolsProvider.overrideWith((ref) async => const [
              Protocol(id: 'p1', attendanceId: 9, attendance: AttendanceRef(id: 9, date: '2026-01-04', typeId: 'lt')),
            ]),
        upcomingProtocolAttendancesProvider
            .overrideWith((ref) async => [ProtocolAttendance(id: 10, date: '2099-01-05', typeId: 'lt')]),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TeamOrganizationPage(initialTab: tab),
      ),
    );

void main() {
  testWidgets('Beta Team: Besprechungen first, with planned, topics and past', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Team'), findsOneWidget);
    expect(find.text('Besprechungen'), findsOneWidget);
    expect(find.text('Leitungstreffen'), findsNWidgets(2));
    expect(find.textContaining('1 neuer Vorschlag'), findsOneWidget);
    expect(find.text('Entwurf'), findsOneWidget);
  });

  testWidgets('Beta Team: Aufgaben opens on the own tasks, Team shows all', (tester) async {
    await tester.pumpWidget(_app(tab: 'tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Raum reservieren'), findsOneWidget);
    expect(find.text('Noten bestellen'), findsNothing);
    await tester.tap(find.text('Team · 2'));
    await tester.pumpAndSettle();
    expect(find.text('Noten bestellen'), findsOneWidget);
  });

  testWidgets('Beta Team: outside the circle only "Meine Aufgaben"', (tester) async {
    await tester.pumpWidget(_app(leader: false, circle: false));
    await tester.pumpAndSettle();
    expect(find.text('Meine Aufgaben'), findsOneWidget);
    expect(find.text('Besprechungen'), findsNothing);
  });
}
