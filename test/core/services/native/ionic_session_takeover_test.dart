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

  group('custom domain https://api.attendix.de', () {
    const customUrl = 'https://api.attendix.de';

    test('prefers sb-api-auth-token when both custom and legacy tokens exist', () {
      final raw = jsonEncode({
        'sb-ultyjzgwejpehfjuyenr-auth-token': jsonEncode({
          'refresh_token': 'legacy-token',
        }),
        'sb-api-auth-token': jsonEncode({
          'access_token': 'a',
          'refresh_token': 'custom-token',
        }),
        'currentTenantId': '7',
      });
      final session = parseIonicStorage(raw, supabaseUrl: customUrl);
      expect(session?.refreshToken, 'custom-token');
      expect(session?.tenantId, 7);
    });

    test('falls back to legacy sb-ultyjzgwejpehfjuyenr-auth-token on upgrade', () {
      final raw = jsonEncode({
        'sb-ultyjzgwejpehfjuyenr-auth-token': jsonEncode({
          'access_token': 'a',
          'refresh_token': 'legacy-token',
        }),
        'currentTenantId': '12',
      });
      final session = parseIonicStorage(raw, supabaseUrl: customUrl);
      expect(session?.refreshToken, 'legacy-token');
      expect(session?.tenantId, 12);
    });
  });
}
