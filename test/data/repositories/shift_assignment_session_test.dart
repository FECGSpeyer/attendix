// #232: updateShiftAssignmentsForAttendance hands the write session captured
// when the user acted to every updatePersonAttendance. An account or tenant
// switch after the first write stops all further writes.
import 'dart:convert';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/data/repositories/attendance_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late void Function()? onPatch;

  http.Response json(Object body, http.Request request) => http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );

  SupabaseClient fakeSupabase() {
    final client = MockClient((request) async {
      requests.add(request);
      final table = request.url.pathSegments.last;
      final select = request.url.queryParameters['select'] ?? '';
      if (request.method != 'GET') {
        onPatch?.call();
        final id = (request.url.queryParameters['id'] ?? '').replaceFirst('eq.', '');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return json({
          'id': id,
          'attendance_id': 7,
          'person_id': 1,
          'status': body['status'],
          'changed_by': body['changed_by'],
        }, request);
      }
      switch (table) {
        case 'attendance':
          return json([
            {
              'id': 7,
              'date': '2099-01-02',
              'start_time': '19:00',
              'end_time': '21:00',
              'attType': {
                'start_time': '19:00',
                'end_time': '21:00',
                'all_day': false,
                'default_status': 0,
              },
            }
          ], request);
        case 'person_attendances':
          if (select.contains('duty_state')) {
            // updatePersonAttendance's tenant validation.
            final id = (request.url.queryParameters['id'] ?? '').replaceFirst('eq.', '');
            return json([
              {
                'id': id,
                'duty_state': null,
                'attendance': {
                  'tenantId': 42,
                  'type_id': 1,
                  'attType': {'duty_mode': false},
                },
              }
            ], request);
          }
          // Two rows still shift-excused although the persons have no shift
          // anymore: both are reset to the default status.
          return json([
            {'id': 'pa1', 'person_id': 1, 'status': 2, 'notes': 'Schichtbedingt'},
            {'id': 'pa2', 'person_id': 2, 'status': 2, 'notes': 'Schichtbedingt'},
          ], request);
        case 'player':
          return json([
            {'id': 1, 'shift_id': null, 'shift_start': null, 'shift_name': null},
            {'id': 2, 'shift_id': null, 'shift_start': null, 'shift_name': null},
          ], request);
        default:
          return json(<Object>[], request);
      }
    });
    return SupabaseClient(
      'http://localhost:54321',
      'anon-key',
      httpClient: client,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  AttendanceRepository createRepo() {
    final container = ProviderContainer(
      overrides: [supabaseClientProvider.overrideWithValue(fakeSupabase())],
    );
    addTearDown(container.dispose);
    return AttendanceRepository(container.read(Provider((ref) => ref)))..bindTenantId(42);
  }

  List<http.Request> patches() => [
        for (final r in requests)
          if (r.method == 'PATCH') r,
      ];

  setUp(() {
    requests = [];
    onPatch = null;
  });

  test('session ends after the first write: no further write', () async {
    final repo = createRepo();
    var sessionCurrent = true;
    onPatch = () => sessionCurrent = false;

    await expectLater(
      repo.updateShiftAssignmentsForAttendance(
        7,
        isSessionCurrent: () => sessionCurrent,
        actingUserId: 'u1',
      ),
      throwsA(isA<OfflineSessionChangedException>()),
    );

    expect(patches(), hasLength(1));
    expect(patches().single.url.queryParameters['id'], 'eq.pa1');
  });

  test('unchanged session: every write runs with changed_by = acting user', () async {
    final repo = createRepo();

    await repo.updateShiftAssignmentsForAttendance(
      7,
      isSessionCurrent: () => true,
      actingUserId: 'u1',
    );

    expect(patches().map((r) => r.url.queryParameters['id']), ['eq.pa1', 'eq.pa2']);
    for (final patch in patches()) {
      final body = jsonDecode(patch.body) as Map<String, dynamic>;
      expect(body['changed_by'], 'u1');
      expect(body['status'], 0);
    }
  });
}
