/// Ionic types.page `openTypeModal()` + type.page `isNew`: the "+" opens the
/// type page as modal; nothing is written before the "+" FAB creates it.
library;

import 'package:attendix/core/theme/app_icons.dart';
import 'dart:async';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/attendance_type_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/organisation_providers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/repositories/attendance_type_repository.dart';
import 'package:attendix/features/settings/presentation/pages/attendance_type_edit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_helpers.dart';

class _RecordingTypeRepository extends AttendanceTypeRepository {
  _RecordingTypeRepository(super.ref, this.inserts) {
    bindTenantId(1);
  }

  final List<Map<String, dynamic>> inserts;

  @override
  Future<AttendanceType> createTypeFromData(Map<String, dynamic> data) async {
    inserts.add(data);
    return AttendanceType(id: 'new-id', name: data['name'] as String);
  }

  @override
  Future<List<AttendanceType>> getTypes() async => const [];
}

class _SlowTypeRepository extends _RecordingTypeRepository {
  _SlowTypeRepository(super.ref, super.inserts, this.gate);

  final Completer<void> gate;

  @override
  Future<AttendanceType> createTypeFromData(Map<String, dynamic> data) async {
    await gate.future;
    return super.createTypeFromData(data);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('new type: closing is blocked while the insert is running',
      (tester) async {
    final inserts = <Map<String, dynamic>>[];
    final gate = Completer<void>();
    final container = createTestContainer(
      tenantId: 1,
      overrides: [
        attendanceTypeRepositoryWithTenantProvider.overrideWith(
            (ref) => _SlowTypeRepository(ref, inserts, gate)),
        groupsProvider.overrideWith((ref) async => []),
        currentOrganisationProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);

    bool? result;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await showAttendanceTypeCreateModal(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Probe');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    // ✕ is disabled, system back is swallowed: the page stays open.
    final closeButton =
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, AppIcons.close));
    expect(closeButton.onPressed, isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceTypeEditPage), findsOneWidget);
    expect(find.text('Änderungen verwerfen?'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(inserts, hasLength(1));
    expect(result, isTrue);
    expect(find.byType(AttendanceTypeEditPage), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('new type: validated, inserted with Ionic defaults, modal closes',
      (tester) async {
    final inserts = <Map<String, dynamic>>[];
    final container = createTestContainer(
      tenantId: 1,
      overrides: [
        attendanceTypeRepositoryWithTenantProvider
            .overrideWith((ref) => _RecordingTypeRepository(ref, inserts)),
        groupsProvider.overrideWith((ref) async => []),
        currentOrganisationProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);

    bool? result;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await showAttendanceTypeCreateModal(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Neu-Modus: ✕ instead of back arrow / trash.
    expect(find.byIcon(AppIcons.close), findsOneWidget);
    expect(find.byIcon(AppIcons.deleteOutline), findsNothing);
    expect(find.byIcon(AppIcons.arrowBack), findsNothing);

    // Empty name → toast, no insert.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(find.text('Bitte einen Namen für den Anwesenheitstyp eingeben.'),
        findsOneWidget);
    expect(inserts, isEmpty);
    await tester.pump(const Duration(seconds: 5));

    await tester.enterText(find.byType(TextFormField).first, '  Probe ');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(inserts, hasLength(1));
    final data = inserts.single;
    expect(data['name'], 'Probe');
    expect(data['index'], 999);
    expect(data['default_status'], AttendanceStatus.present.value);
    expect(data['available_statuses'], [
      for (final s in [
        AttendanceStatus.neutral,
        AttendanceStatus.present,
        AttendanceStatus.absent,
        AttendanceStatus.excused,
        AttendanceStatus.late,
      ])
        s.value,
    ]);
    expect(data['start_time'], '19:00');
    expect(data['end_time'], '20:30');
    expect(data['relevant_groups'], isEmpty);
    expect(data['reminders'], isEmpty);
    expect(data['default_plan'], {'time': '', 'end': '', 'fields': []});
    expect(data.containsKey('tenant_id'), isFalse,
        reason: 'the repository sets the tenant');

    expect(result, isTrue);
    expect(find.byType(AttendanceTypeEditPage), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });
}
