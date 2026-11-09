import 'package:attendix/features/redesign/presentation/shell/rd_shell.dart';
import 'package:attendix/features/redesign/presentation/shell/rd_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  // Sidebar/tab bar follow the page on top, also when it was pushed from
  // another area (Mitglieder › Verlauf › Termin); back returns there.
  testWidgets('shell sees the pushed page, back restores the area', (tester) async {
    final router = GoRouter(
      initialLocation: '/mitglieder/1/verlauf',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Column(
            children: [
              Text('tab ${rdShownLocation(context)}'),
              Expanded(child: child),
            ],
          ),
          routes: [
            GoRoute(path: '/mitglieder/:id/verlauf', builder: (_, __) => const Text('verlauf')),
            GoRoute(path: '/termine/:id', builder: (_, __) => const Text('termin')),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('tab /mitglieder/1/verlauf'), findsOneWidget);

    router.push('/termine/5');
    await tester.pumpAndSettle();
    expect(find.text('tab /termine/5'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('tab /mitglieder/1/verlauf'), findsOneWidget);
  });

  test('sidebar marks Auswertung, Mitteilungen, Verwaltung, Hilfe, else the tab', () {
    RdSideExtra? at(String l, {bool manage = true, bool team = true}) =>
        rdSideExtraFor(l, manage: manage, team: team);
    expect(at('/ich/verwaltung/auswertung'), RdSideExtra.stats);
    expect(at('/ich/verwaltung/mitteilungen'), RdSideExtra.messages);
    expect(at('/ich/verwaltung/mitteilung'), RdSideExtra.messages);
    expect(at('/ich/verwaltung/rollen'), RdSideExtra.manage);
    expect(at('/settings/help/article/x'), RdSideExtra.help);
    expect(at('/settings/team-organization'), RdSideExtra.team);
    expect(at('/settings/team-organization', team: false), isNull);
    expect(at('/settings/tasks/4'), RdSideExtra.team);
    expect(at('/settings/protocol/9'), RdSideExtra.team);
    expect(at('/messages/5'), RdSideExtra.messages);
    expect(at('/settings/auto-messages/2'), RdSideExtra.messages);
    expect(at('/messages/5', manage: false), isNull);
    expect(at('/ich/verwaltung/auswertung', manage: false), isNull);
    expect(at('/termine/3'), isNull);
    expect(at('/ich'), isNull);
  });
}
