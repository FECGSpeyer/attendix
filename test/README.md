# Attendix Test Suite

This directory contains the test infrastructure for the Attendix Flutter app.

## Quick Start

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/data/repositories/player_repository_test.dart

# Run tests matching a pattern
flutter test --name "tenantId"

# Run security tests only
flutter test --name "Multi-Tenant Security"
```

## Test Structure

```
test/
├── core/                            # Mirrors lib/core/ (providers, redesign, router, services, theme, utils)
├── data/                            # Mirrors lib/data/ (models, repositories security tests)
├── features/                        # Mirrors lib/features/ 1:1 (today, attendance, people, songs, settings, ...)
├── shared/                          # Mirrors lib/shared/ (shell, widgets)
├── factories/                       # Test data factories (test_factories.dart)
├── fixtures/                        # Static test fixtures
├── golden/                          # Golden image tests
├── helpers/                         # Test utilities (source_reader.dart, test_helpers.dart)
└── mocks/                           # Mock classes (supabase_mocks.dart, repository_mocks.dart)
```

## Security Tests

The repository tests use **source code analysis** to verify multi-tenant security. This approach:

1. Is more robust than mocking the complex Supabase builder chain
2. Directly validates the code patterns we care about
3. Catches issues even if methods are refactored

### What's Tested

- **INSERT operations**: Must set `tenantId` in the data object
- **SELECT operations**: Must include `.eq('tenantId', currentTenantId)`
- **UPDATE operations**: Must include `.eq('tenantId', currentTenantId)` AND `.eq('id', ...)`
- **DELETE operations**: Must include `.eq('tenantId', currentTenantId)` AND `.eq('id', ...)`

### Example Security Test

```dart
test('all UPDATE operations include tenantId filter', () {
  final updateQueries = RegExp(
    r"supabase[^;]*\.from\('player'\)[^;]*\.update\([^;]+",
    multiLine: true,
  ).allMatches(playerRepoSource);

  for (final match in updateQueries) {
    final query = match.group(0)!;
    expect(
      query,
      contains(".eq('tenantId', currentTenantId)"),
      reason: 'UPDATE query missing tenantId filter',
    );
  }
});
```

## Test Factories

Use factories to create consistent test data:

```dart
import 'package:attendix/test/factories/test_factories.dart';

// Create a single person
final person = TestFactories.createPerson(
  id: 1,
  firstName: 'Alice',
  tenantId: 42,
);

// Create a list
final persons = TestFactories.createPersonList(10, tenantId: 42);

// Specialized variants
final conductor = TestFactories.createConductor(mainGroupId: 1);
final archived = TestFactories.createArchivedPerson();
final paused = TestFactories.createPausedPerson(pausedUntil: '2024-12-31');
```

## Repository Mocks

For provider tests that need mock repositories:

```dart
import 'package:attendix/test/mocks/repository_mocks.dart';

setUpAll(() {
  registerFallbackValues(); // Required for mocktail
});

test('example', () async {
  final mockRepo = MockPlayerRepository();
  setupMockPlayerRepository(mockRepo, tenantId: 42);
  mockGetPlayers(mockRepo, testPlayers);

  // Test provider behavior...
});
```

## Writing New Tests

### For Repositories

1. Use source code analysis for security tests
2. Verify `tenantId` filtering for all operations
3. Check both `id` and `tenantId` filters for mutations

### For Providers

1. Test the tenant guard pattern (`if (!repo.hasTenantId) return ...`)
2. Verify cache invalidation
3. Test error handling

### For Features

1. Use `createTestContainer()` with appropriate overrides
2. Mock external dependencies (Supabase, SharedPreferences)
3. Test both success and error paths

## CI Integration

Tests run automatically on:
- Push to `master` or `develop`
- Pull requests to `master`
- Before deployment to Cloudflare Pages

See `.github/workflows/ci.yml` for the workflow configuration.

## Coverage

Generate coverage report:

```bash
flutter test --coverage
# View in browser (macOS)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Troubleshooting

### Tests timeout
```bash
flutter test --timeout 60s
```

### Tests fail with "no .env file"
Tests should not require .env - mock Supabase configuration instead.

### "Not a mock" errors
Ensure `registerFallbackValues()` is called in `setUpAll()`.
