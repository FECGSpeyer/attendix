import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_groups_page.dart';
import 'package:attendix/features/redesign/presentation/widgets/manage/rd_manage_list.dart';
import 'package:attendix/features/redesign/presentation/widgets/rd_widgets.dart' show RdPill;
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bounded pumps: loading spinners never settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('de'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
  home: child,
);

const _sections = [
  RdManageListSection(
    key: 1,
    title: 'Streicher',
    items: [
      RdManageListItem(id: 1, title: 'Violine', subtitle: 'Violinschlüssel', count: '4 Personen'),
      RdManageListItem(id: 2, title: 'Bratsche', count: '0 Personen', countWarn: true),
    ],
  ),
  RdManageListSection(
    key: 2,
    title: 'Bläser',
    items: [RdManageListItem(id: 3, title: 'Flöte', count: '2 Personen')],
  ),
];

void main() {
  group('RdManageListPage (Verwaltungsliste)', () {
    testWidgets('shows title, intro, sections with counts and the add button', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          RdManageListPage(
            title: 'Gruppen',
            intro: 'Gruppen ordnen die Mitglieder.',
            sections: _sections,
            emptyText: 'leer',
            addLabel: 'Gruppe hinzufügen',
            onAdd: () {},
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Verwaltung'), findsOneWidget);
      expect(find.text('Gruppen'), findsOneWidget);
      expect(find.text('Gruppen ordnen die Mitglieder.'), findsOneWidget);
      // Sections with the number of entries on the right.
      expect(find.text('Streicher'), findsOneWidget);
      expect(find.text('Bläser'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      // Entries: initials, title, subtitle, count; no drag handles.
      expect(find.text('VI'), findsOneWidget);
      expect(find.text('Violinschlüssel'), findsOneWidget);
      expect(find.text('4 Personen'), findsOneWidget);
      expect(find.widgetWithText(RdPill, '0 Personen'), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle), findsNothing);
      expect(find.byKey(const Key('rd-manage-list-add')), findsOneWidget);
      // Nothing to sort and no actions: no "•••".
      expect(find.byKey(const Key('rd-manage-list-more')), findsNothing);
    });

    testWidgets('empty and error states', (tester) async {
      _phone(tester);
      var retried = false;
      await tester.pumpWidget(
        _app(
          const RdManageListPage(
            title: 'Schichtpläne',
            intro: 'x',
            sections: [RdManageListSection(items: [])],
            emptyText: 'Noch keine Schichtpläne angelegt.',
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Noch keine Schichtpläne angelegt.'), findsOneWidget);

      await tester.pumpWidget(
        _app(
          RdManageListPage(
            title: 'Schichtpläne',
            intro: 'x',
            sections: null,
            loadFailed: true,
            onRetry: () => retried = true,
            emptyText: 'leer',
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Das konnte nicht geladen werden.'), findsOneWidget);
      await tester.tap(find.text('Erneut versuchen'));
      expect(retried, isTrue);
    });

    testWidgets('"Reihenfolge ändern" shows handles, "Fertig" saves the moved order', (tester) async {
      _phone(tester);
      List<RdManageListSection>? saved;
      var calls = 0;
      await tester.pumpWidget(
        _app(
          RdManageListPage(
            title: 'Gruppen',
            intro: 'x',
            sections: _sections,
            emptyText: 'leer',
            onReorder: (sections) async {
              calls++;
              saved = sections;
              return true;
            },
          ),
        ),
      );
      await _settle(tester);

      // "Fertig" without a move saves nothing.
      await tester.tap(find.byKey(const Key('rd-manage-list-more')));
      await _settle(tester);
      await tester.tap(find.text('Reihenfolge ändern'));
      await _settle(tester);
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
      await tester.tap(find.byKey(const Key('rd-manage-list-done')));
      await _settle(tester);
      expect(calls, 0);
      expect(find.byIcon(Icons.drag_handle), findsNothing);

      // Move "Violine" below "Bratsche".
      await tester.tap(find.byKey(const Key('rd-manage-list-more')));
      await _settle(tester);
      await tester.tap(find.text('Reihenfolge ändern'));
      await _settle(tester);
      final handle = find.byIcon(Icons.drag_handle).first;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await _settle(tester);

      await tester.tap(find.byKey(const Key('rd-manage-list-done')));
      await _settle(tester);
      expect(calls, 1);
      expect(saved!.first.items.map((i) => i.id), [2, 1]);
      expect(saved!.last.items.map((i) => i.id), [3]);
      // Back to the normal list.
      expect(find.byIcon(Icons.drag_handle), findsNothing);
    });

    testWidgets('a failed save keeps the sorting mode', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          RdManageListPage(
            title: 'Gruppen',
            intro: 'x',
            sections: _sections,
            emptyText: 'leer',
            onReorder: (_) async => false,
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.byKey(const Key('rd-manage-list-more')));
      await _settle(tester);
      await tester.tap(find.text('Reihenfolge ändern'));
      await _settle(tester);
      final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.drag_handle).first));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await _settle(tester);
      await tester.tap(find.byKey(const Key('rd-manage-list-done')));
      await _settle(tester);
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
    });
  });

  group('Gruppen', () {
    test('sections by category, main group and counts', () {
      final l10n = lookupAppLocalizations(const Locale('de'));
      const categories = [
        GroupCategory(id: 10, name: 'Streicher', sortOrder: 1),
        GroupCategory(id: 20, name: 'Leitung', sortOrder: 2),
      ];
      const groups = [
        Group(id: 1, name: 'Violine', categoryId: 10, tuning: 'C', clefs: ['g'], sortOrder: 2),
        Group(id: 2, name: 'Bratsche', categoryId: 10, clefs: ['c'], sortOrder: 1),
        Group(id: 3, name: 'Dirigenten', categoryId: 20, maingroup: true),
      ];
      final sections = rdGroupSections(l10n, groups, categories, counts: {1: 5}, tenantType: 'orchestra');

      expect(sections.map((s) => s.title), ['Streicher', 'Leitung']);
      expect(sections.first.items.map((i) => i.title), ['Bratsche', 'Violine']);
      expect(sections.first.items.last.subtitle, 'Stimmung C · Violinschlüssel');
      expect(sections.first.items.last.count, '5 Personen');
      expect(sections.first.items.first.countWarn, isTrue);
      expect(sections.last.items.single.subtitle, 'Hauptgruppe');

      // Choir: no music subtitle; without categories no headings.
      final choir = rdGroupSections(l10n, groups, const [], tenantType: 'choir');
      expect(choir.single.title, isNull);
      expect(choir.single.items.firstWhere((i) => i.title == 'Violine').subtitle, isNull);
      expect(choir.single.items.first.count, isNull);
    });

    test('lists and the group page are for leads only', () {
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.groups, Role.helper), RedesignRoutes.manage);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.groupEdit(3), Role.helper), RedesignRoutes.manage);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.attendanceTypes, Role.viewer), RedesignRoutes.manage);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.shiftPlans, Role.player), RedesignRoutes.manage);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.groupEdit(3), Role.responsible), isNull);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.shiftPlans, Role.admin), isNull);
    });
  });
}
