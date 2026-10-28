// SOL_FIX11: the offline replay re-checks the auth session inside the
// repository AFTER the async validation and immediately before the
// mutation. An account switch A -> B during the validation must not run A's
// queued write as B; the entry stays queued for A.
import 'dart:convert';
import 'dart:io';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/connectivity_provider.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/data/repositories/attendance_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthClientOptions, SupabaseClient;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String? currentUser;
  late String? currentSession;
  late List<http.Request> requests;
  late void Function()? onValidation;

  Map<String, dynamic> validationRow(String id) => {
    'id': id,
    'duty_state': null,
    'attendance': {
      'tenantId': 42,
      'type_id': 1,
      'attType': {'duty_mode': false},
    },
  };

  SupabaseClient fakeSupabase() {
    final client = MockClient((request) async {
      requests.add(request);
      final id = (request.url.queryParameters['id'] ?? '').replaceFirst(
        'eq.',
        '',
      );
      if (request.method == 'GET') {
        // The repository's async validation of the person_attendance.
        onValidation?.call();
        return http.Response(
          jsonEncode([validationRow(id)]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'id': id,
          'attendance_id': 7,
          'person_id': 1,
          'status': body['status'],
          'changed_by': body['changed_by'],
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    return SupabaseClient(
      'http://localhost:54321',
      'anon-key',
      httpClient: client,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  ProviderContainer createContainer() {
    final supabase = fakeSupabase();
    final container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(supabase),
        connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
        connectivityCheckProvider.overrideWithValue(() async => true),
        currentTenantIdProvider.overrideWithValue(42),
        offlineQueueUserIdProvider.overrideWithValue(() => currentUser),
        offlineQueueSessionIdProvider.overrideWithValue(() => currentSession),
        offlineQueueAuthEventsProvider.overrideWithValue(
          const Stream<AuthChangeEvent>.empty(),
        ),
        // offlineFlushFnProvider is NOT overridden: the real repository path.
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  List<http.Request> mutations() => [
    for (final r in requests)
      if (r.method != 'GET') r,
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    currentUser = 'u1';
    currentSession = 's1';
    requests = [];
    onValidation = null;
  });

  test(
    'account switch during validation: no mutation, entry stays queued',
    () async {
      final container = createContainer();
      final notifier = container.read(offlineQueueNotifierProvider.notifier);
      await notifier.enqueue('pa1', {'status': 1}, tenantId: 42, userId: 'u1');
      await notifier.enqueue('pa2', {'status': 2}, tenantId: 42, userId: 'u1');
      onValidation = () {
        currentUser = 'u2';
        currentSession = 's2';
      };

      await notifier.flush();

      expect(
        requests.where((r) => r.method == 'GET'),
        hasLength(1),
        reason: 'only pa1 was validated, then the replay stopped',
      );
      expect(mutations(), isEmpty, reason: "u1's write must not run as u2");
      final left = await OfflineQueueStore().load();
      expect(
        left.map((e) => e.personAttendanceId),
        ['pa1', 'pa2'],
        reason: 'the aborted entry is kept, not dropped or counted as failed',
      );
      expect(left.every((e) => e.userId == 'u1'), isTrue);
      expect(
        container.read(offlinePendingCountProvider),
        0,
        reason: 'u2 has no pending writes',
      );
    },
  );

  test(
    'unchanged session: write runs with changed_by = queued author',
    () async {
      final container = createContainer();
      final notifier = container.read(offlineQueueNotifierProvider.notifier);
      await notifier.enqueue('pa1', {'status': 1}, tenantId: 42, userId: 'u1');

      await notifier.flush();

      final patch = mutations().single;
      expect(patch.method, 'PATCH');
      expect(patch.url.queryParameters['id'], 'eq.pa1');
      final body = jsonDecode(patch.body) as Map<String, dynamic>;
      expect(body['changed_by'], 'u1');
      expect(body['status'], 1);
      expect(await OfflineQueueStore().load(), isEmpty);
    },
  );

  test(
    'repository: guard false after validation throws and does not write',
    () async {
      final container = createContainer();
      final repo = AttendanceRepository(container.read(Provider((ref) => ref)))
        ..bindTenantId(42);
      var sessionCurrent = true;
      onValidation = () => sessionCurrent = false;

      await expectLater(
        repo.updatePersonAttendance(
          'pa1',
          {'status': 1},
          isSessionCurrent: () => sessionCurrent,
          actingUserId: 'u1',
        ),
        throwsA(isA<OfflineSessionChangedException>()),
      );
      expect(mutations(), isEmpty);
    },
  );

  test('source: guard is checked between validation and update', () {
    final s =
        File(
          'lib/data/repositories/attendance_repository.dart',
        ).readAsStringSync();
    final start = s.indexOf('Future<PersonAttendance> updatePersonAttendance(');
    final validation = s.indexOf(".from('person_attendances')", start);
    final guard = s.indexOf('!isSessionCurrent()', start);
    final update = s.indexOf('.update(updates)', start);
    expect(validation, greaterThan(start));
    expect(guard, greaterThan(validation));
    expect(update, greaterThan(guard));
    final mutation = s.lastIndexOf('await supabase', update);
    expect(mutation, greaterThan(guard));
    expect(
      s.substring(guard, mutation),
      isNot(contains('await ')),
      reason: 'no await between the session check and the mutation',
    );
    expect(
      s.substring(start, update),
      isNot(contains("updates['changed_by'] = supabase.auth.currentUser")),
    );
  });
}
