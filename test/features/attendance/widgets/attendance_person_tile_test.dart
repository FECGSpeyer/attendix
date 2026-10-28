import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/attendance_person_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../factories/test_factories.dart';
import '../../../helpers/widget_test_helpers.dart';

void main() {
  widgetTestGroup('AttendancePersonTile', () {
    final person = TestFactories.createPerson(
      id: 1,
      firstName: 'Max',
      lastName: 'Mustermann',
    );

    Widget buildTile({
      AttendanceStatus status = AttendanceStatus.present,
      String? notes,
    }) {
      return Scaffold(
        body: AttendancePersonTile(
          person: person,
          status: status,
          notes: notes,
          availableStatuses: AttendanceStatus.values,
          onStatusChanged: (_) {},
          onNoteChanged: (_) {},
          onShowModifierInfo: () {},
          onRemoveFromAttendance: () {},
        ),
      );
    }

    group('notes display', () {
      widgetTest('shows note text when notes are present', (tester) async {
        await tester.pumpApp(
          buildTile(
            status: AttendanceStatus.late,
            notes: 'kommt erst um 19:30',
          ),
        );

        // The note text should be visible directly in the tile
        expect(find.text('kommt erst um 19:30'), findsOneWidget);
      });

      widgetTest('shows no note line when notes are null', (tester) async {
        await tester.pumpApp(
          buildTile(
            status: AttendanceStatus.present,
            notes: null,
          ),
        );

        final column = tester.widget<Column>(find.byType(Column).first);
        expect(column.children.whereType<Text>().length, 1);
      });

      widgetTest('shows no note line when notes are empty', (tester) async {
        await tester.pumpApp(
          buildTile(
            status: AttendanceStatus.present,
            notes: '',
          ),
        );

        final column = tester.widget<Column>(find.byType(Column).first);
        expect(column.children.whereType<Text>().length, 1);
      });
    });

    // UX_ATT: Ionic status badge + tap cycles the status
    group('status badge (Ionic)', () {
      widgetTest('shows the Ionic status letter', (tester) async {
        await tester.pumpApp(buildTile(status: AttendanceStatus.excused));
        expect(find.text('E'), findsOneWidget);
      });

      widgetTest('tap cycles present -> excused', (tester) async {
        AttendanceStatus? changed;
        await tester.pumpApp(
          Scaffold(
            body: AttendancePersonTile(
              person: person,
              status: AttendanceStatus.present,
              notes: null,
              availableStatuses: AttendanceStatus.values,
              onStatusChanged: (s) => changed = s,
              onNoteChanged: (_) {},
              onShowModifierInfo: () {},
              onRemoveFromAttendance: () {},
            ),
          ),
        );
        await tester.tap(find.text('Max Mustermann'));
        await tester.pump();
        expect(changed, AttendanceStatus.excused);
      });
    });

    group('basic rendering', () {
      widgetTest('shows person name', (tester) async {
        await tester.pumpApp(buildTile());

        expect(find.text('Max Mustermann'), findsOneWidget);
      });

      widgetTest('does not show group name', (tester) async {
        final personWithGroup = TestFactories.createPerson(
          id: 1,
          firstName: 'Max',
          lastName: 'Mustermann',
        );
        // Person model has groupName but tile should not display it
        await tester.pumpApp(
          Scaffold(
            body: AttendancePersonTile(
              person: personWithGroup,
              status: AttendanceStatus.present,
              notes: null,
              availableStatuses: AttendanceStatus.values,
              onStatusChanged: (_) {},
              onNoteChanged: (_) {},
              onShowModifierInfo: () {},
              onRemoveFromAttendance: () {},
            ),
          ),
        );

        // Only name should be shown, no subtitle when no notes
        expect(find.text('Max Mustermann'), findsOneWidget);
        // No second text line at all
        final column = tester.widget<Column>(find.byType(Column).first);
        final textChildren = column.children.whereType<Text>().toList();
        expect(textChildren.length, 1); // Only the name
      });
    });
  });
}
