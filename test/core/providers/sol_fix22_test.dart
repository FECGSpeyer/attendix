import 'dart:io';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/optional_tabs_providers.dart';
import 'package:attendix/core/router/route_access.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../factories/test_factories.dart';
import '../../helpers/test_helpers.dart';
import '../../mocks/supabase_mocks.dart';

/// SOL_FIX22: dashboard persons are paginated; the optional "Werke" tab and
/// its toggle follow the `/songs-tab` route guard.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('DashboardRepository.getAllPersons', () {
    late String fn;
    setUpAll(() {
      final src = File('lib/data/repositories/dashboard_repository.dart').readAsStringSync();
      fn = RegExp(r'Future<List<Person>> getAllPersons\(\) async \{[\s\S]+?\n  \}').firstMatch(src)!.group(0)!;
    });

    test('loads all pages with a stable order by id', () {
      expect(fn, contains('fetchAllPages'));
      expect(fn, contains(".order('id', ascending: true)"));
      expect(fn, contains('.range(from, to)'));
    });

    test('stays tenant scoped and skips pending persons (Ionic getPlayers(true))', () {
      expect(fn, contains(".eq('tenantId', currentTenantId)"));
      expect(fn, contains(".isFilter('pending', false)"));
      // Archived persons stay in: the member-changes card needs `left`.
      expect(fn, isNot(contains("'left'")));
    });
  });

  group('Werke tab follows the /songs-tab guard', () {
    late MockGoTrueClient auth;

    setUp(() {
      auth = MockGoTrueClient();
      when(() => auth.currentUser).thenReturn(User(
        id: 'user-a',
        appMetadata: const {},
        userMetadata: const {'showSongsTab_1': true},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      ));
    });

    ({bool allowed, bool shown}) tabFor(Role role, {String type = 'orchestra'}) {
      final c = createTestContainer(
        tenant: TestFactories.createTenant(id: 1, type: type),
        overrides: [
          supabaseAuthProvider.overrideWithValue(auth),
          currentAuthUserIdProvider.overrideWithValue('user-a'),
          effectiveRoleProvider.overrideWithValue(role),
        ],
      );
      addTearDown(c.dispose);
      return (allowed: c.read(songsTabAllowedProvider), shown: c.read(showSongsTabProvider));
    }

    test('parents neither see the tab nor the toggle', () {
      final r = tabFor(Role.parent);
      expect(r.allowed, isFalse);
      expect(r.shown, isFalse);
      expect(routeAccessRedirect('/songs-tab', Uri.parse('/songs-tab'), Role.parent, const RouteAccessTenant()),
          isNotNull);
    });

    test('for every role, tab visibility matches the route guard', () {
      for (final role in Role.values) {
        final guardAllows =
            routeAccessRedirect('/songs-tab', Uri.parse('/songs-tab'), role, const RouteAccessTenant()) == null;
        final r = tabFor(role);
        expect(r.allowed, guardAllows, reason: role.name);
        expect(r.shown, guardAllows, reason: role.name);
      }
    });

    test('general tenants never get the tab', () {
      final r = tabFor(Role.admin, type: 'general');
      expect(r.allowed, isFalse);
      expect(r.shown, isFalse);
    });

    test('songs list only offers the toggle when the tab is allowed', () {
      final src = File('lib/features/songs/presentation/pages/songs_list_page.dart').readAsStringSync();
      expect(src, contains('if (!data.isPublic && ref.watch(songsTabAllowedProvider))'));
    });
  });
}
