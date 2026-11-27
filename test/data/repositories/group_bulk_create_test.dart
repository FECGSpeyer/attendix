import 'dart:convert';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/utils/demo_guard.dart';
import 'package:attendix/data/repositories/group_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DemoGroupRepository extends GroupRepository {
  DemoGroupRepository(super.ref);
  @override
  void ensureNotDemo(String operation) => throw DemoModeException(operation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<http.Request> requests;
  late GroupRepository repo;
  late ProviderContainer container;

  setUp(() {
    requests = [];
    final client = SupabaseClient(
      'http://localhost:54321',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final rows =
            (jsonDecode(request.body) as List).cast<Map<String, dynamic>>();
        return http.Response(
          jsonEncode([
            for (var i = 0; i < rows.length; i++) {...rows[i], 'id': i + 1},
          ]),
          201,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    container = ProviderContainer(
      overrides: [supabaseClientProvider.overrideWithValue(client)],
    );
    repo = GroupRepository(container.read(Provider((ref) => ref)))
      ..bindTenantId(42);
    addTearDown(container.dispose);
    addTearDown(client.dispose);
  });

  test(
    'one insert binds every row to the tenant and preserves explicit metadata',
    () async {
      final input = [
        <String, dynamic>{
          'name': 'Viola',
          'tenantId': 999,
          'id': 123,
          'clefs': ['c'],
          'tuning': 'C',
          'unexpected': 'ignored',
        },
        <String, dynamic>{
          'name': 'Schlagwerk',
          'tuning': null,
          'clefs': <String>[],
          'maingroup': true,
        },
      ];
      final groups = await repo.createGroups(input);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, endsWith('/instruments'));
      final rows =
          (jsonDecode(requests.single.body) as List)
              .cast<Map<String, dynamic>>();
      expect(rows.map((r) => r['tenantId']), everyElement(42));
      expect(
        rows.every((r) => !r.containsKey('id') && !r.containsKey('unexpected')),
        isTrue,
      );
      expect(rows.map((r) => r['maingroup']), everyElement(false));
      expect(rows[1]['tuning'], isNull);
      expect(rows[1]['clefs'], isEmpty);
      expect(groups.map((g) => g.name), ['Viola', 'Schlagwerk']);
      expect(input[0]['tenantId'], 999);
      expect(input[0]['id'], 123);
    },
  );

  test('an empty selection makes no request', () async {
    expect(await repo.createGroups([]), isEmpty);
    expect(requests, isEmpty);
  });

  test(
    'rejects empty names before sending any part of the selection',
    () async {
      await expectLater(
        repo.createGroups([
          {'name': 'Violine'},
          {'name': '  '},
        ]),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    },
  );

  test('demo guard rejects the bulk operation', () async {
    final demo = DemoGroupRepository(container.read(Provider((ref) => ref)))
      ..bindTenantId(42);
    await expectLater(
      demo.createGroups([
        {'name': 'Bassflöte'},
      ]),
      throwsA(isA<DemoModeException>()),
    );
    expect(requests, isEmpty);
  });
}
