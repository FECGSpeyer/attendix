import 'dart:convert';

import 'package:attendix/core/services/native/ionic_session_takeover.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const url = 'https://abcref.supabase.co';

  test('reads refresh token and tenant from the Ionic localStorage', () {
    final raw = jsonEncode({
      'sb-other-auth-token': jsonEncode({'refresh_token': 'wrong'}),
      'sb-abcref-auth-token': jsonEncode({
        'access_token': 'a',
        'refresh_token': 'r1',
        'user': {'id': 'u'},
      }),
      'currentTenantId': '42',
    });
    final session = parseIonicStorage(raw, supabaseUrl: url);
    expect(session?.refreshToken, 'r1');
    expect(session?.tenantId, 42);
  });

  test('maps the Ionic offline queue of the signed-in user', () {
    final raw = jsonEncode({
      'offline_writes_v1': jsonEncode([
        {
          'id': 'q1',
          'personAttendanceId': 'pa1',
          'payload': {'status': '4', 'notes': 'krank', 'person_id': 7, 'attendance_id': 9},
          'userId': 'u1',
          'createdAt': '2026-11-01T10:00:00Z',
        },
        {'id': 'q2', 'personAttendanceId': 'pa2', 'payload': {'status': 1}},
        {'id': 'q3', 'personAttendanceId': 'pa3', 'payload': {'status': 1}, 'userId': 'other'},
        {'id': 'q4', 'personAttendanceId': 'pa4', 'payload': {'status': 99}},
      ]),
    });
    final writes = parseIonicOfflineWrites(raw, userId: 'u1', tenantId: 42);
    expect(writes.map((w) => w.personAttendanceId), ['pa1', 'pa2']);
    expect(writes.first.payload, {'status': 4, 'notes': 'krank'});
    expect(writes.first.attendanceId, 9);
    expect(writes.every((w) => w.userId == 'u1' && w.tenantId == 42), isTrue);
    expect(parseIonicOfflineWrites('{}', userId: 'u1', tenantId: 42), isEmpty);
  });

  test('no Ionic session -> null', () {
    expect(parseIonicStorage(null, supabaseUrl: url), isNull);
    expect(parseIonicStorage('{}', supabaseUrl: url), isNull);
    expect(
      parseIonicStorage(jsonEncode({'currentTenantId': '1'}), supabaseUrl: url),
      isNull,
    );
  });
}
