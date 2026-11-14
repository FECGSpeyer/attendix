import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/team_org/team_org.dart';
import 'package:attendix/data/repositories/agenda_item_repository.dart';
import 'package:attendix/data/repositories/protocol_repository.dart';
import 'package:attendix/data/repositories/task_repository.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_widgets.dart';
import 'package:attendix/features/team_organization/presentation/pages/protocol_page.dart';
import 'package:attendix/features/team_organization/presentation/widgets/protocol_beta_widgets.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Beta protocol page of the leadership: two columns on a wide window,
/// one column with three buttons on the phone.

const _topics = [
  AgendaItem(id: 'a1', title: 'Weihnachtskonzert'),
  AgendaItem(id: 'a2', title: 'Notenständer'),
];

final _tasks = [
  const TeamTask(id: 't1', title: 'Noten bestellen', agendaItemId: 'a1'),
];

class _ProtocolRepo extends ProtocolRepository {
  _ProtocolRepo(super.ref);

  @override
  Future<ProtocolAttendance?> getAttendance(int attendanceId) async => ProtocolAttendance(
        id: attendanceId,
        date: '2026-11-12',
        typeId: 'lt',
        startTime: '19:00',
        plan: const {
          'time': '19:00',
          'fields': [
            {'id': 'f1', 'name': 'Weihnachtskonzert', 'time': '20', 'agendaItemId': 'a1'},
            {'id': 'f2', 'name': 'Notenständer', 'time': '10', 'agendaItemId': 'a2'},
          ],
        },
        persons: [
          // Six present people broke the old "Anwesend" card.
          for (var i = 0; i < 6; i++)
            ProtocolAttendee(id: 'p$i', personId: i + 1, status: 1, firstName: 'Person', lastName: 'Nr$i'),
        ],
      );

  @override
  Future<Protocol?> getProtocolForAttendance(int attendanceId) async => Protocol(
        id: 'p1',
        attendanceId: attendanceId,
        status: 'draft',
        outcomes: const {'f1': 'decided', 'f2': 'postponed'},
        content: const {},
      );
}

class _TaskRepo extends TaskRepository {
  _TaskRepo(super.ref);

  @override
  Future<List<TeamTask>> getTasksForAttendance(int attendanceId) async => _tasks;
}

class _AgendaRepo extends AgendaItemRepository {
  _AgendaRepo(super.ref);

  @override
  Future<List<AgendaItem>> getAgendaItemsByIds(List<String> ids) async =>
      _topics.where((t) => ids.contains(t.id)).toList();

  @override
  Future<List<AgendaItem>> getAgendaItems() async => _topics;
}

Future<void> _open(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      redesignEnabledProvider.overrideWithValue(true),
      isTeamLeaderProvider.overrideWithValue(true),
      agendaItemsProvider.overrideWith((ref) async => _topics),
      protocolTypesProvider.overrideWith((ref) async => const [ProtocolType(id: 'lt', name: 'Besprechung')]),
      protocolRepositoryWithTenantProvider.overrideWith(_ProtocolRepo.new),
      taskRepositoryWithTenantProvider.overrideWith(_TaskRepo.new),
      agendaItemRepositoryWithTenantProvider.overrideWith(_AgendaRepo.new),
    ],
    child: MaterialApp(
      theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
      locale: const Locale('de'),
      localizationsDelegates: const [...AppLocalizations.localizationsDelegates, FlutterQuillLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ProtocolPage(attendanceId: 9),
    ),
  ));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('wide: two columns, status as a word, next point as a button', (tester) async {
    await _open(tester, const Size(1200, 900));

    // One main action, in the header (not inside a scrolling column).
    expect(find.byKey(const Key('rd-protocol-finish')), findsOneWidget);
    expect(find.byType(RdPrimaryButton), findsOneWidget);
    // The Ablaufplan says the status of every point.
    expect(find.widgetWithText(RdPill, 'Beschlossen'), findsOneWidget);
    expect(find.widgetWithText(RdPill, 'Vertagt'), findsOneWidget);
    expect(find.text('6 anwesend'), findsOneWidget);
    expect(find.text('TOP 1 · 19:00 · 20 MIN'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rd-protocol-next')));
    await tester.pump();
    expect(find.text('TOP 2 · 19:20 · 10 MIN'), findsOneWidget);
    // Last point: no next one.
    expect(find.byKey(const Key('rd-protocol-next')), findsNothing);

    await tester.tap(find.byKey(const Key('rd-protocol-general')));
    await tester.pump();
    expect(find.text('Gilt für die ganze Sitzung, unabhängig vom Punkt.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rd-protocol-tasks')));
    await tester.pump();
    expect(find.text('Noten bestellen'), findsOneWidget);
  });

  testWidgets('phone: three buttons on top, result chips in one row, only "Abschließen" below', (tester) async {
    // The narrowest phones: nothing may overflow.
    await _open(tester, const Size(320, 700));

    expect(find.byType(ProtocolStripButton), findsNWidgets(3));
    expect(find.byType(RdPrimaryButton), findsOneWidget);
    expect(find.byType(RdOutlineButton), findsNothing);

    final chips = find.byType(ProtocolOutcomeChips);
    expect(chips, findsOneWidget);
    double top(String label) => tester.getTopLeft(find.descendant(of: chips, matching: find.text(label))).dy;
    expect(top('Besprochen'), top('Vertagt'));

    await tester.tap(find.byKey(const Key('rd-protocol-tasks')));
    await tester.pumpAndSettle();
    expect(find.text('TOP 1'), findsOneWidget);
  });
}
