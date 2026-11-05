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

  test('no Ionic session -> null', () {
    expect(parseIonicStorage(null, supabaseUrl: url), isNull);
    expect(parseIonicStorage('{}', supabaseUrl: url), isNull);
    expect(
      parseIonicStorage(jsonEncode({'currentTenantId': '1'}), supabaseUrl: url),
      isNull,
    );
  });
}
