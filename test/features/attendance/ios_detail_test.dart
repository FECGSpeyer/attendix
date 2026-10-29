import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/features/attendance/presentation/pages/attendance_detail_page.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/attendance_grid.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/general_info_accordion.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/status_chip.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonDetailChevron;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';
import '../../helpers/widget_test_helpers.dart';

/// IOS_DETAIL: attendance detail page in Ionic iOS look.
void main() {
  Widget ios(Widget child) => Builder(
        builder: (ctx) => Theme(
          data: Theme.of(ctx).copyWith(platform: TargetPlatform.iOS),
          child: child,
        ),
      );

  group('sortPersonsByGroup (Ionic Utils.sortPlayers)', () {
    test('a group with sort_order comes before groups without one', () {
      final groups = [
        const Group(id: 1, name: 'Alt'),
        const Group(id: 2, name: 'Bass'),
        const Group(id: 3, name: 'Dirigenten', sortOrder: 0),
        const Group(id: 4, name: 'Sopran'),
      ];
      final persons = [
        TestFactories.createPerson(id: 1, lastName: 'A').copyWith(instrument: 4, groupName: 'Sopran'),
        TestFactories.createPerson(id: 2, lastName: 'B').copyWith(instrument: 2, groupName: 'Bass'),
        TestFactories.createPerson(id: 3, lastName: 'C').copyWith(instrument: 3, groupName: 'Dirigenten'),
        TestFactories.createPerson(id: 4, lastName: 'D').copyWith(instrument: 1, groupName: 'Alt'),
      ];
      final sorted = sortPersonsByGroup(persons, groups: groups);
      expect(sorted.map((p) => p.groupName), ['Dirigenten', 'Alt', 'Bass', 'Sopran']);
    });

    test('main group first, persons by sort_order then last name (localeCompare)', () {
      final groups = [
        const Group(id: 1, name: 'Bass', sortOrder: 1),
        const Group(id: 9, name: 'Dirigenten', maingroup: true, sortOrder: 5),
      ];
      final persons = [
        TestFactories.createPerson(id: 1, lastName: 'Zeller').copyWith(instrument: 1, groupName: 'Bass'),
        TestFactories.createPerson(id: 2, lastName: 'Özdemir').copyWith(instrument: 1, groupName: 'Bass'),
        TestFactories.createPerson(id: 3, lastName: 'Adler').copyWith(instrument: 1, groupName: 'Bass', sortOrder: 1),
        TestFactories.createPerson(id: 4, lastName: 'Bach').copyWith(instrument: 9, groupName: 'Dirigenten'),
      ];
      final sorted = sortPersonsByGroup(persons, groups: groups, mainGroupId: mainGroupIdOf(groups));
      expect(sorted.map((p) => p.id), [4, 3, 2, 1]);
    });

    test('equal group keys keep the incoming order (stable like JS sort)', () {
      final groups = [
        const Group(id: 1, name: 'X', sortOrder: 1),
        const Group(id: 2, name: 'A', sortOrder: 1),
      ];
      final persons = [
        TestFactories.createPerson(id: 1, lastName: 'M').copyWith(instrument: 1, groupName: 'X'),
        TestFactories.createPerson(id: 2, lastName: 'M').copyWith(instrument: 2, groupName: 'A'),
      ];
      expect(sortPersonsByGroup(persons, groups: groups).map((p) => p.id), [1, 2]);
    });
  });

  test('mainGroupIdOf picks the first maingroup', () {
    expect(mainGroupIdOf(const [Group(id: 1, name: 'A'), Group(id: 2, name: 'B', maingroup: true)]), 2);
    expect(mainGroupIdOf(const [Group(id: 1, name: 'A')]), isNull);
  });

  test('collapseHtmlWhitespace like HTML', () {
    expect(collapseHtmlWhitespace('Max  Mustermann'), 'Max Mustermann');
    expect(collapseHtmlWhitespace(' a \n b '), 'a b');
  });

  test('isDeadlineReadonly only for a past Termin with a deadline', () {
    final now = DateTime(2026, 6, 20);
    final past = TestFactories.createAttendance(id: 1, date: '2026-06-15');
    final future = TestFactories.createAttendance(id: 2, date: '2026-07-15');
    expect(isDeadlineReadonly(past, now: now), isFalse);
    expect(isDeadlineReadonly(past.copyWith(deadline: '2026-06-14T19:00:00Z'), now: now), isTrue);
    expect(isDeadlineReadonly(future.copyWith(deadline: '2026-07-14T19:00:00Z'), now: now), isFalse);
  });

  test('description link like Ionic: Helfer yes, viewer/player no', () {
    expect(canEditAttendanceDescription(Role.admin), isTrue);
    expect(canEditAttendanceDescription(Role.responsible), isTrue);
    expect(canEditAttendanceDescription(Role.helper), isTrue);
    expect(canEditAttendanceDescription(Role.voiceLeaderHelper), isTrue);
    expect(canEditAttendanceDescription(Role.viewer), isFalse);
    expect(canEditAttendanceDescription(Role.player), isFalse);
  });

  widgetTest('iOS status badge is a pill, not a circle', (tester) async {
    await tester.pumpApp(ios(const Center(child: AttendanceStatusBadge(status: AttendanceStatus.present))));
    final size = tester.getSize(find.byType(AttendanceStatusBadge));
    expect(size.width, greaterThanOrEqualTo(28));
    expect(size.height, lessThan(22));
    expect(size.width - size.height, greaterThan(6));
  });

  widgetTest('Allgemein (iOS): Anmeldefrist toggle and description link', (tester) async {
    final attendance = TestFactories.createAttendance(id: 7, date: '2099-01-10');
    await tester.pumpApp(ios(Scaffold(
      body: SingleChildScrollView(
        child: GeneralInfoAccordion(
          attendance: attendance,
          attendanceType: null,
          onTypeInfoChanged: (_) {},
          onNotesChanged: (_) {},
          onStartTimeSelect: () {},
          onEndTimeSelect: () {},
          onDeadlineToggle: (_) {},
          onDeadlineSelect: () {},
          onExportExcel: () {},
          onEditDescription: () {},
        ),
      ),
    )));
    await tester.tap(find.text('Allgemein'));
    await tester.pumpAndSettle();
    expect(find.text('Anmeldefrist setzen'), findsOneWidget);
    expect(find.text('Beschreibung & Anhang bearbeiten'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    // Info-Text / Notizen: plain rows, no outlined Material field
    expect(find.text('Info-Text'), findsOneWidget);
    expect(find.text('Notizen'), findsOneWidget);
  });

  widgetTest('Allgemein: accordion state is not restored from page storage', (tester) async {
    final attendance = TestFactories.createAttendance(id: 7, date: '2099-01-10');
    Widget build(Key key) => ios(Scaffold(
          body: SingleChildScrollView(
            child: GeneralInfoAccordion(
              key: key,
              attendance: attendance,
              attendanceType: null,
              onTypeInfoChanged: (_) {},
              onNotesChanged: (_) {},
              onStartTimeSelect: () {},
              onEndTimeSelect: () {},
              onDeadlineToggle: (_) {},
              onDeadlineSelect: () {},
              onExportExcel: () {},
            ),
          ),
        ));
    await tester.pumpApp(build(const ValueKey(1)));
    await tester.tap(find.text('Allgemein'));
    await tester.pumpAndSettle();
    expect(find.text('Anmeldefrist setzen'), findsOneWidget);
    // re-created (e.g. page re-entered) → collapsed again like Ionic
    await tester.pumpApp(build(const ValueKey(2)));
    await tester.pumpAndSettle();
    expect(find.text('Anmeldefrist setzen'), findsNothing);
  });

  group('showAppPopoverMenu', () {
    Widget host(void Function(String?) onResult) => Scaffold(
          appBar: AppBar(actions: [
            Builder(
              builder: (bc) => IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () async {
                  onResult(await showAppPopoverMenu<String>(context: bc, items: const [
                    AppPopoverMenuItem(value: 'filter', label: 'Status-Filter', icon: Icons.filter_list, submenu: true),
                    AppPopoverMenuItem(value: 'legend', label: 'Legende', icon: Icons.info_outline),
                  ]));
                },
              ),
            ),
          ]),
        );

    widgetTest('iOS: chevron on sub menu entries, returns the value', (tester) async {
      String? result;
      await tester.pumpApp(ios(host((v) => result = v)));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<String>), findsNothing);
      // IOS27_SWEEP: the ios27 detail chevron (IonDetailChevron)
      expect(find.byType(IonDetailChevron), findsOneWidget);
      await tester.tap(find.text('Legende'));
      await tester.pumpAndSettle();
      expect(result, 'legend');
    });

    widgetTest('Material: Ionic md popover card, returns the value', (tester) async {
      String? result;
      await tester.pumpApp(host((v) => result = v));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      // PARITY_R3: own md popover (no Material popup menu items)
      expect(find.byType(PopupMenuItem<String>), findsNothing);
      // IOS_THEME2: Ionic md popover shows the sub menu chevron too.
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await tester.tap(find.text('Status-Filter'));
      await tester.pumpAndSettle();
      expect(result, 'filter');
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      widgetTest('nested popover stays open and toggles ($platform)', (tester) async {
        final filter = <String>{};
        String? result = 'unset';
        List<AppPopoverMenuItem<String>> items() => [
              AppPopoverMenuItem(
                value: 'filter',
                label: 'Status-Filter',
                subtitle: filter.isEmpty ? null : 'Filter aktiv (${filter.length})',
                submenuItems: () => [
                  for (final s in ['Anwesend', 'Abwesend'])
                    AppPopoverSubItem(
                      label: s,
                      checked: filter.contains(s),
                      onTap: () => filter.contains(s) ? filter.remove(s) : filter.add(s),
                    ),
                ],
              ),
              const AppPopoverMenuItem(value: 'legend', label: 'Legende'),
            ];
        final wrap = platform == TargetPlatform.iOS ? ios : (Widget w) => w;
        await tester.pumpApp(wrap(Scaffold(
            appBar: AppBar(actions: [
              Builder(
                builder: (bc) => IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () async {
                    result = await showAppPopoverMenu<String>(
                        context: bc, items: items(), itemsBuilder: items);
                  },
                ),
              ),
            ]),
          )));
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Status-Filter'));
        await tester.pumpAndSettle();
        expect(find.text('Anwesend'), findsOneWidget);
        await tester.tap(find.text('Anwesend'));
        await tester.pumpAndSettle();
        // both popovers still open, parent entry updated
        expect(filter, {'Anwesend'});
        expect(find.text('Filter aktiv (1)'), findsOneWidget);
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox).first).value,
          isTrue,
        );
        // another parent entry closes the nested popover and returns its value
        await tester.tap(find.text('Legende'));
        await tester.pumpAndSettle();
        expect(result, 'legend');
        expect(find.text('Anwesend'), findsNothing);
      });
    }
  });

  test('detail page: Ionic group order + popover menu wiring (source)', () {
    final src = File('lib/features/attendance/presentation/pages/attendance_detail_page.dart').readAsStringSync();
    expect(src, contains('mainGroupId: mainGroupIdOf(groups)'));
    expect(src, contains('showAppPopoverMenu<String>('));
    expect(src, isNot(contains('PopupMenuButton<String>(')));
    expect(src, contains("highlight: _statusFilter.isNotEmpty, submenu: true"));
    expect(src, contains("context.l10n.attendanceView, submenu: true"));
    // PARITY_R3: nested popovers instead of bottom sheets
    expect(src, contains('submenuItems: _statusFilterSubItems'));
    expect(src, contains('submenuItems: _viewSubItems'));
  });
}
