import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mock SupabaseClient for testing
class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Mock GoTrueClient for auth
class MockGoTrueClient extends Mock implements GoTrueClient {}

/// Tracks method calls for query builder verification
class QueryCallTracker {
  final List<QueryCall> calls = [];

  void recordCall(String method, List<dynamic> args) {
    calls.add(QueryCall(method, args));
  }

  /// Check if a specific filter was called
  bool hasFilter(String column, dynamic value) {
    return calls.any((call) =>
        call.method == 'eq' &&
        call.args.length >= 2 &&
        call.args[0] == column &&
        call.args[1] == value);
  }

  /// Check if tenantId filter was applied
  bool hasTenantIdFilter(int tenantId) {
    return hasFilter('tenantId', tenantId);
  }

  /// Check if select was called
  bool hasSelect([String? columns]) {
    if (columns == null) {
      return calls.any((call) => call.method == 'select');
    }
    return calls.any((call) =>
        call.method == 'select' &&
        call.args.isNotEmpty &&
        call.args[0] == columns);
  }

  /// Check if insert was called and return the data
  Map<String, dynamic>? getInsertData() {
    final insertCall = calls.cast<QueryCall?>().firstWhere(
          (call) => call?.method == 'insert',
          orElse: () => null,
        );
    if (insertCall != null && insertCall.args.isNotEmpty) {
      return insertCall.args[0] as Map<String, dynamic>?;
    }
    return null;
  }

  void clear() => calls.clear();
}

/// Represents a single query method call
class QueryCall {
  final String method;
  final List<dynamic> args;

  QueryCall(this.method, this.args);

  @override
  String toString() => '$method(${args.join(', ')})';
}

/// Helper to create a configured mock Supabase client
MockSupabaseClient createMockSupabaseClient({
  MockGoTrueClient? auth,
}) {
  final mockClient = MockSupabaseClient();
  final mockAuth = auth ?? MockGoTrueClient();

  when(() => mockClient.auth).thenReturn(mockAuth);

  return mockClient;
}

/// Helper to set up a mock user for auth
void setupMockUser(
  MockGoTrueClient mockAuth, {
  String userId = 'test-user-id',
  String? email,
}) {
  final mockUser = User(
    id: userId,
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
    email: email,
  );
  when(() => mockAuth.currentUser).thenReturn(mockUser);
}
