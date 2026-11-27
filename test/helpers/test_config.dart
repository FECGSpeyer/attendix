import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Test configuration for integration tests.
///
/// Provides environment-specific URLs and credentials for testing
/// against local Supabase or CI environments.
class TestConfig {
  TestConfig._();

  /// Environment types
  static const envLocal = 'local';
  static const envCi = 'ci';
  static const envMock = 'mock';

  /// Current test environment (from ENV variable or default to mock)
  static String get environment =>
      const String.fromEnvironment('ENV', defaultValue: envMock);

  /// Whether running in local Supabase mode
  static bool get isLocal => environment == envLocal;

  /// Whether running in CI mode
  static bool get isCi => environment == envCi;

  /// Whether running with mocks (no real backend)
  static bool get isMock => environment == envMock;

  /// Supabase URL for tests
  static String get supabaseUrl {
    if (isMock) return 'http://mock.supabase.local';

    // Try environment variable first
    final envUrl = const String.fromEnvironment('SUPABASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Fall back to dotenv
    return dotenv.env['SUPABASE_URL'] ?? 'http://127.0.0.1:54321';
  }

  /// Supabase anon key for tests
  static String get supabaseAnonKey {
    if (isMock) return 'mock-anon-key';

    // Try environment variable first
    final envKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
    if (envKey.isNotEmpty) return envKey;

    // Fall back to dotenv
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }

  /// Database URL for direct access (seeds, migrations)
  static String get databaseUrl {
    final envUrl = const String.fromEnvironment('DATABASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    return dotenv.env['DATABASE_URL'] ??
        'postgresql://postgres:postgres@127.0.0.1:54322/postgres';
  }

  /// Default test tenant ID
  static const defaultTestTenantId = 1;

  /// Cross-tenant test tenant ID
  static const crossTenantTestId = 2;

  /// Test timeouts
  static const defaultTimeout = Duration(seconds: 10);
  static const longTimeout = Duration(seconds: 30);

  /// Load environment-specific .env file
  static Future<void> loadEnv() async {
    if (isMock) return; // No .env needed for mock mode

    final envFile = isLocal ? '.env.local' : '.env.test';
    try {
      await dotenv.load(fileName: envFile);
    } catch (e) {
      // Ignore if file doesn't exist - will use defaults or env vars
    }
  }

  /// Print current configuration (for debugging)
  static void printConfig() {
    debugPrint('Test Configuration:');
    debugPrint('  Environment: $environment');
    debugPrint('  Supabase URL: $supabaseUrl');
    debugPrint('  Database URL: ${databaseUrl.replaceAll(RegExp(r':[^:@]+@'), ':***@')}');
    debugPrint('  Is Mock: $isMock');
  }
}

/// Test users (matching seed.sql)
class TestUsers {
  TestUsers._();

  static const conductor1 = TestUser(
    id: 'test-user-uuid-conductor-1',
    email: 'conductor@test.local',
    role: 2,
    tenantId: 1,
  );

  static const helper1 = TestUser(
    id: 'test-user-uuid-helper-1',
    email: 'helper@test.local',
    role: 1,
    tenantId: 1,
  );

  static const player1 = TestUser(
    id: 'test-user-uuid-player-1',
    email: 'player@test.local',
    role: 0,
    tenantId: 1,
  );

  static const conductor2 = TestUser(
    id: 'test-user-uuid-conductor-2',
    email: 'conductor2@test.local',
    role: 2,
    tenantId: 2,
  );
}

/// Test user data class
class TestUser {
  final String id;
  final String email;
  final int role;
  final int tenantId;

  const TestUser({
    required this.id,
    required this.email,
    required this.role,
    required this.tenantId,
  });

  bool get isConductor => role == 2;
  bool get isHelper => role == 1;
  bool get isPlayer => role == 0;
}
