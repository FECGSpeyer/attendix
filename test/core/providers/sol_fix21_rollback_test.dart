import 'dart:async';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/dashboard_providers.dart';
import 'package:attendix/core/providers/optional_tabs_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../mocks/supabase_mocks.dart';

/// SOL_FIX21: a save that fails after a tenant switch (or a newer edit) must
/// not roll the new state back to the previous tenant's settings.
void main() {
  late MockGoTrueClient auth;
  late Completer<UserResponse> pending;
  final tenant = StateProvider<int?>((ref) => 1);

  User user(Map<String, dynamic> metadata) => User(
        id: 'user-a',
        appMetadata: const {},
        userMetadata: metadata,
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );

  setUpAll(() => registerFallbackValue(UserAttributes()));

  setUp(() {
    auth = MockGoTrueClient();
    pending = Completer<UserResponse>();
    when(() => auth.currentUser).thenReturn(user({
      'showDashboardTab_2': true,
      'showSongsTab_2': true,
    }));
    when(() => auth.updateUser(any())).thenAnswer((_) => pending.future);
  });

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      supabaseAuthProvider.overrideWithValue(auth),
      currentAuthUserIdProvider.overrideWithValue('user-a'),
      currentTenantIdProvider.overrideWith((ref) => ref.watch(tenant)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('dashboard: failed save after a tenant switch keeps the new tenant',
      () async {
    final c = container();
    final notifier = c.read(dashboardSettingsNotifierProvider.notifier);
    expect(c.read(dashboardSettingsNotifierProvider).showTab, isFalse);

    final save = notifier.setShowTab(true);
    c.read(tenant.notifier).state = 2;
    final tenant2 = c.read(dashboardSettingsNotifierProvider);
    expect(tenant2.showTab, isTrue);

    pending.completeError(Exception('offline'));
    await expectLater(save, throwsException);
    expect(c.read(dashboardSettingsNotifierProvider), same(tenant2));
  });

  test('dashboard: failed save without a switch rolls back', () async {
    final c = container();
    final notifier = c.read(dashboardSettingsNotifierProvider.notifier);
    final save = notifier.setShowTab(true);
    expect(c.read(dashboardSettingsNotifierProvider).showTab, isTrue);
    pending.completeError(Exception('offline'));
    await expectLater(save, throwsException);
    expect(c.read(dashboardSettingsNotifierProvider).showTab, isFalse);
  });

  test('optional tabs: failed save after a tenant switch keeps the new tenant',
      () async {
    final c = container();
    final notifier = c.read(optionalTabsNotifierProvider.notifier);
    final save = notifier.setShowSongsTab(true);
    c.read(tenant.notifier).state = 2;
    final tenant2 = c.read(optionalTabsNotifierProvider);
    expect(tenant2.songs, isTrue);

    pending.completeError(Exception('offline'));
    await expectLater(save, throwsException);
    expect(c.read(optionalTabsNotifierProvider), same(tenant2));
  });
}
