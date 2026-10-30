// U2: the sections of the full Termin page ("Alle Details") as cards of
// the new design while the Beta is on; Ionic accordion without it.
import 'dart:io';

import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/features/attendance/presentation/widgets/attendance_detail/attendance_accordion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(ThemeData theme) => MaterialApp(
      theme: theme,
      home: const Scaffold(
        body: AttendanceAccordion(title: Text('Checkliste'), children: [Text('Noten kopieren')]),
      ),
    );

void main() {
  testWidgets('Beta: a card of the new design that opens and closes', (tester) async {
    await tester.pumpWidget(_app(buildRdTheme(RdFarbwelt.petrol, Brightness.light)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Card), findsNothing);
    final card = tester.widget<Container>(
      find.ancestor(of: find.byType(ExpansionTile), matching: find.byType(Container)).first,
    );
    final deco = card.decoration! as BoxDecoration;
    expect(deco.borderRadius, isNotNull);
    expect(find.text('Noten kopieren'), findsNothing);
    await tester.tap(find.text('Checkliste'));
    await tester.pumpAndSettle();
    expect(find.text('Noten kopieren'), findsOneWidget);
  });

  testWidgets('without the Beta the Ionic accordion (Card) stays', (tester) async {
    await tester.pumpWidget(_app(AppTheme.forPlatform(Brightness.light, TargetPlatform.iOS, web: false)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Card), findsOneWidget);
  });

  test('old Termine list and Beta Überblick share the Ablauf viewer', () {
    final list = File('lib/features/attendance/presentation/pages/attendance_list_page.dart').readAsStringSync();
    final beta = File('lib/features/redesign/presentation/pages/rd_event_page.dart').readAsStringSync();
    expect(list, contains('openAttendancePlanViewer(context, att)'));
    expect(beta, contains('openAttendancePlanViewer(context, attendance)'));
    // Delete is bound to the tenant repository before the dialog.
    expect(beta, contains('final repo = ref.read(attendanceRepositoryWithTenantProvider);'));
  });
}
