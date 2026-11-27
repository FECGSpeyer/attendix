import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../factories/test_factories.dart';
import '../mocks/supabase_mocks.dart';

/// Create a test ProviderContainer with common overrides
///
/// [overrides] - Additional provider overrides
/// [tenantId] - If provided, sets up a current tenant with this ID
/// [mockSupabase] - Custom mock Supabase client to use
///
/// Example:
/// ```dart
/// final container = createTestContainer(tenantId: 42);
/// final players = await container.read(playersProvider.future);
/// ```
ProviderContainer createTestContainer({
  List<Override>? overrides,
  int? tenantId,
  Tenant? tenant,
  MockSupabaseClient? mockSupabase,
}) {
  final effectiveOverrides = <Override>[
    // Override Supabase client
    if (mockSupabase != null)
      supabaseClientProvider.overrideWithValue(mockSupabase),

    // Override current tenant if provided
    if (tenant != null)
      currentTenantProvider.overrideWith(
        (ref) => _FakeCurrentTenantNotifier(tenant),
      ),
    if (tenantId != null && tenant == null)
      currentTenantProvider.overrideWith(
        (ref) => _FakeCurrentTenantNotifier(
          TestFactories.createTenant(id: tenantId),
        ),
      ),

    // Add any custom overrides
    ...?overrides,
  ];

  return ProviderContainer(overrides: effectiveOverrides);
}

/// Fake CurrentTenantNotifier that immediately sets the tenant
class _FakeCurrentTenantNotifier extends CurrentTenantNotifier {
  _FakeCurrentTenantNotifier(Tenant? initialTenant)
      : super(_FakeRef()) {
    state = initialTenant;
  }
}

/// Minimal fake Ref for testing
class _FakeRef extends Fake implements Ref<Object?> {
  @override
  T read<T>(ProviderListenable<T> provider) {
    // Return mock for supabaseAuthProvider
    if (identical(provider, supabaseAuthProvider)) {
      return MockGoTrueClient() as T;
    }
    if (identical(provider, supabaseClientProvider)) {
      return MockSupabaseClient() as T;
    }
    throw UnimplementedError('Provider $provider not mocked');
  }

  @override
  T watch<T>(ProviderListenable<T> provider) => read(provider);

  @override
  void invalidate(ProviderOrFamily provider) {}
}

/// Custom matcher to verify tenantId filter was applied
///
/// Usage:
/// ```dart
/// final tracker = QueryCallTracker();
/// // ... execute test ...
/// expect(tracker, hasTenantIdFilter(42));
/// ```
Matcher hasTenantIdFilter(int expectedTenantId) {
  return _HasTenantIdFilterMatcher(expectedTenantId);
}

class _HasTenantIdFilterMatcher extends Matcher {
  final int expectedTenantId;

  _HasTenantIdFilterMatcher(this.expectedTenantId);

  @override
  Description describe(Description description) {
    return description.add('has tenantId filter with value $expectedTenantId');
  }

  @override
  bool matches(item, Map matchState) {
    if (item is QueryCallTracker) {
      return item.hasTenantIdFilter(expectedTenantId);
    }
    return false;
  }

  @override
  Description describeMismatch(
    item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is QueryCallTracker) {
      final eqCalls = item.calls.where((c) => c.method == 'eq').toList();
      if (eqCalls.isEmpty) {
        return mismatchDescription.add('no eq() filters were applied');
      }
      return mismatchDescription
          .add('found filters: ')
          .add(eqCalls.map((c) => c.toString()).join(', '));
    }
    return mismatchDescription.add('expected QueryCallTracker but got ${item.runtimeType}');
  }
}

/// Matcher to verify a specific column filter was applied
Matcher hasFilter(String column, dynamic value) {
  return _HasFilterMatcher(column, value);
}

class _HasFilterMatcher extends Matcher {
  final String column;
  final dynamic value;

  _HasFilterMatcher(this.column, this.value);

  @override
  Description describe(Description description) {
    return description.add('has filter eq("$column", $value)');
  }

  @override
  bool matches(item, Map matchState) {
    if (item is QueryCallTracker) {
      return item.hasFilter(column, value);
    }
    return false;
  }

  @override
  Description describeMismatch(
    item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is QueryCallTracker) {
      final eqCalls = item.calls.where((c) => c.method == 'eq').toList();
      if (eqCalls.isEmpty) {
        return mismatchDescription.add('no eq() filters were applied');
      }
      return mismatchDescription
          .add('found filters: ')
          .add(eqCalls.map((c) => c.toString()).join(', '));
    }
    return mismatchDescription.add('expected QueryCallTracker');
  }
}

/// Matcher to verify select was called
Matcher hasSelectCalled([String? columns]) {
  return _HasSelectMatcher(columns);
}

class _HasSelectMatcher extends Matcher {
  final String? columns;

  _HasSelectMatcher(this.columns);

  @override
  Description describe(Description description) {
    if (columns != null) {
      return description.add('has select("$columns") call');
    }
    return description.add('has select() call');
  }

  @override
  bool matches(item, Map matchState) {
    if (item is QueryCallTracker) {
      return item.hasSelect(columns);
    }
    return false;
  }
}

/// Helper to set up a mock user for auth
void setupMockUser(
  MockGoTrueClient mockAuth, {
  String userId = 'test-user-id',
  String? email,
}) {
  final mockUser = _createMockUser(userId: userId, email: email);
  when(() => mockAuth.currentUser).thenReturn(mockUser);
}

User _createMockUser({
  required String userId,
  String? email,
}) {
  return User(
    id: userId,
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
    email: email,
  );
}

/// Async helper to wait for all providers to settle
Future<void> waitForProviders(ProviderContainer container) async {
  await Future.delayed(Duration.zero);
}

/// Helper to verify a repository method includes tenantId filter
///
/// Usage:
/// ```dart
/// await verifyTenantIdFilter(
///   tracker,
///   () => repository.getPlayers(),
///   expectedTenantId: 42,
/// );
/// ```
Future<void> verifyTenantIdFilter(
  QueryCallTracker tracker,
  Future<void> Function() action, {
  required int expectedTenantId,
}) async {
  tracker.clear();
  await action();
  expect(tracker, hasTenantIdFilter(expectedTenantId));
}

/// Group helper for security tests
void securityTestGroup(
  String description,
  void Function() body,
) {
  group('Security: $description', body);
}

/// Test helper for tenantId verification tests
void tenantIdTest(
  String description,
  Future<void> Function() body,
) {
  test('applies tenantId filter: $description', body);
}
