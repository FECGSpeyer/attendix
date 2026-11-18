import 'dart:convert';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/realtime_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_helpers.dart';

const memberFixturePerson = Person(
  id: 100,
  tenantId: 7,
  firstName: 'Ada',
  lastName: 'Beispiel',
  instrument: 1,
  joined: '2020-01-01',
  groupName: 'Violine',
);

const memberFixtureTenant = Tenant(
  id: 7,
  shortName: 'SO',
  longName: 'Stadtorchester',
  seasonStart: '2025-09-01T00:00:00Z',
);

const memberFixtureTypes = <AttendanceType>[
  AttendanceType(id: 'probe', tenantId: 7, name: 'Probe'),
  AttendanceType(id: 'dienst', tenantId: 7, name: 'Dienst', dutyMode: true),
  AttendanceType(id: 'konzert', tenantId: 7, name: 'Konzert'),
];

final memberFixtureRoleProvider = StateProvider<Role>((ref) => Role.viewer);

Map<String, dynamic> memberAttendanceRow({
  required int id,
  required String date,
  required AttendanceStatus status,
  String typeId = 'probe',
  String? dutyState,
  String? notes,
  bool archived = false,
  int personId = 100,
  int tenantId = 7,
}) => {
  'id': 'row-${id.toString().padLeft(6, '0')}',
  'person_id': personId,
  'attendance_id': id,
  'status': status.value,
  'notes': notes,
  'duty_state': dutyState,
  'attendance': <String, dynamic>{
    'id': id,
    'date': date,
    'tenantId': tenantId,
    'type': 0,
    'typeInfo': '',
    'type_id': typeId,
    'archived': archived,
  },
};

/// Real repositories/providers with only the external HTTP boundary replaced.
/// Models PostgREST's default 1000-row cap, filters and offset/limit pagination.
/// Every request stays inside MockClient; product writes are rejected.
class MemberAttendanceFixture {
  MemberAttendanceFixture({
    required this.rows,
    this.types = memberFixtureTypes,
    this.tenant = memberFixtureTenant,
    this.person = memberFixturePerson,
    this.role = Role.viewer,
    this.beta = true,
  }) {
    httpClient = MockClient(_handle);
    supabase = SupabaseClient(
      'http://127.0.0.1:9',
      'fixture-anon-key',
      httpClient: httpClient,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  List<Map<String, dynamic>> rows;
  List<AttendanceType> types;
  final Tenant tenant;
  final Person person;
  final Role role;
  final bool beta;
  late final MockClient httpClient;
  late final SupabaseClient supabase;
  final requests = <http.Request>[];

  ProviderContainer createContainer({List<Override> overrides = const []}) =>
      createTestContainer(
        tenant: tenant,
        overrides: [
          supabaseClientProvider.overrideWithValue(supabase),
          supabaseAuthProvider.overrideWithValue(supabase.auth),
          currentAuthUserIdProvider.overrideWithValue(null),
          memberFixtureRoleProvider.overrideWith((ref) => role),
          currentRoleProvider.overrideWith(
            (ref) => ref.watch(memberFixtureRoleProvider),
          ),
          redesignEnabledProvider.overrideWithValue(beta),
          // The counter is driven explicitly; no websocket leaves the test.
          attendanceRealtimeSubscriptionProvider.overrideWith((ref) {}),
          groupsMapProvider.overrideWith((ref) async => const {1: 'Violine'}),
          ...overrides,
        ],
      );

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    if (request.method != 'GET') {
      throw StateError(
        'Attendance fixture permits reads only: ${request.method}',
      );
    }
    final query = request.url.queryParameters;
    Object response;
    switch (request.url.pathSegments.last) {
      case 'person_attendances':
        var selected =
            rows
                .where((row) {
                  final attendance = row['attendance'] as Map<String, dynamic>;
                  if (!_equals(
                    query['attendance.tenantId'],
                    attendance['tenantId'],
                  ))
                    return false;
                  if (!_equals(query['person_id'], row['person_id']))
                    return false;
                  final date = DateTime.parse(attendance['date'] as String);
                  if (!_dateMatches(query['attendance.date'], date))
                    return false;
                  // A query can have both gte and lt under the same parameter.
                  for (final value
                      in request.url.queryParametersAll['attendance.date'] ??
                          const <String>[]) {
                    if (!_dateMatches(value, date)) return false;
                  }
                  return true;
                })
                .map((row) {
                  final attendance = row['attendance'] as Map<String, dynamic>;
                  final matching = types.where(
                    (type) => type.id == attendance['type_id'],
                  );
                  return <String, dynamic>{
                    ...row,
                    'attendance': <String, dynamic>{
                      ...attendance,
                      'attType':
                          matching.isEmpty ? null : matching.first.toJson(),
                    },
                  };
                })
                .toList();
        if (query['order'] == 'id.asc' ||
            query['order'] == 'id.asc.nullslast') {
          selected.sort(
            (a, b) => (a['id'] as String).compareTo(b['id'] as String),
          );
        }
        final offset = int.tryParse(query['offset'] ?? '') ?? 0;
        final limit = int.tryParse(query['limit'] ?? '') ?? 1000;
        response =
            selected.skip(offset).take(limit > 1000 ? 1000 : limit).toList();
      case 'player':
        response =
            _equals(query['id'], person.id) &&
                    _equals(query['tenantId'], person.tenantId)
                ? [person.toJson()]
                : <Object>[];
      case 'attendance_types':
        response =
            types
                .where((type) => _equals(query['tenant_id'], type.tenantId))
                .map((type) => type.toJson())
                .toList();
      default:
        throw StateError('Unexpected fixture request ${request.url}');
    }
    return http.Response(
      jsonEncode(response),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }

  bool _equals(String? filter, Object? value) =>
      filter == null || filter == 'eq.$value';

  bool _dateMatches(String? filter, DateTime date) {
    if (filter == null) return true;
    final separator = filter.indexOf('.');
    final operation = filter.substring(0, separator);
    final boundary = DateTime.parse(filter.substring(separator + 1));
    return switch (operation) {
      'gte' => !date.isBefore(boundary),
      'gt' => date.isAfter(boundary),
      'lte' => !date.isAfter(boundary),
      'lt' => date.isBefore(boundary),
      _ => throw StateError('Unexpected date filter $filter'),
    };
  }

  Future<void> dispose() async {
    await supabase.dispose();
    httpClient.close();
  }
}
