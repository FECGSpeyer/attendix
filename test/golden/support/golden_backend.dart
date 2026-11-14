// A Supabase client that never leaves the test: every table is empty unless
// the test fills it. A page then shows empty lists for everything its test
// does not care about, instead of errors.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const goldenUserId = '00000000-0000-4000-8000-000000000001';
const goldenUserEmail = 'anna@example.org';

/// [tables] maps a table name to its rows. Filters of a query are ignored:
/// the rows come back as they are.
Future<SupabaseClient> goldenBackend({Map<String, List<Map<String, dynamic>>> tables = const {}}) async {
  final client = SupabaseClient(
    'http://localhost:54321',
    'golden',
    httpClient: MockClient((request) async => _answer(request, tables)),
    authOptions: const AuthClientOptions(autoRefreshToken: false, authFlowType: AuthFlowType.implicit),
  );
  await client.auth.recoverSession(jsonEncode(_session()));
  // Realtime thinks it already has a socket, so it never opens a real one
  // (a real connection attempt leaves timers behind that fail the test on
  // machines where localhost has two addresses, like the CI runners).
  client.realtime.conn = _NoSocket();
  return client;
}

/// Stands in for the realtime socket. Nothing may use it: subscriptions
/// stay "joining" forever, which is what an offline page looks like.
class _NoSocket implements WebSocketChannel {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('The golden backend has no realtime socket (${invocation.memberName}).');
}

http.Response _answer(http.Request request, Map<String, List<Map<String, dynamic>>> tables) {
  const json = {'content-type': 'application/json; charset=utf-8'};
  final segments = request.url.pathSegments;
  if (segments.length >= 3 && segments[0] == 'rest' && segments[2] != 'rpc') {
    final rows = tables[segments[2]] ?? const [];
    final single = (request.headers['Accept'] ?? request.headers['accept'] ?? '').contains('vnd.pgrst.object');
    if (!single) {
      // The content range answers count queries.
      final range = rows.isEmpty ? '*/0' : '0-${rows.length - 1}/${rows.length}';
      return http.Response(
        jsonEncode(rows),
        200,
        headers: {...json, 'content-range': range},
        request: request,
      );
    }
    if (rows.isEmpty) {
      return http.Response(
        jsonEncode({'code': 'PGRST116', 'message': 'no rows', 'details': 'The result contains 0 rows'}),
        406,
        headers: json,
        request: request,
      );
    }
    return http.Response(jsonEncode(rows.first), 200, headers: json, request: request);
  }
  return http.Response('[]', 200, headers: json, request: request);
}

Map<String, dynamic> _session() {
  String part(Map<String, dynamic> value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  // Year 2099: the session never runs out during a test.
  const expiresAt = 4070908800;
  final token = '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': goldenUserId, 'exp': expiresAt, 'role': 'authenticated', 'email': goldenUserEmail})}.golden';
  return {
    'access_token': token,
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': expiresAt,
    'refresh_token': 'golden',
    'user': {
      'id': goldenUserId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': goldenUserEmail,
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2020-01-01T00:00:00Z',
    },
  };
}
