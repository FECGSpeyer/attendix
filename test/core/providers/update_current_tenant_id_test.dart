import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/user_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../mocks/supabase_mocks.dart';

/// Ionic db.service setCurrentTenant: updateUser sends only the tenant key –
/// GoTrue merges it, so a stale local user_metadata copy must not be sent
/// back (it would reset settings changed on another device).
void main() {
  late MockGoTrueClient auth;

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
    when(() => auth.currentUser).thenReturn(user({
      'currentTenantId': 1,
      'showSongsTab_1': false,
      'dashboardCards_1': ['a'],
      'wantInstanceSelection': false,
    }));
    when(() => auth.updateUser(any()))
        .thenAnswer((_) async => UserResponse.fromJson(const {}));
  });

  UserPreferencesNotifier notifier() {
    final c = ProviderContainer(overrides: [
      supabaseAuthProvider.overrideWithValue(auth),
      currentAuthUserIdProvider.overrideWithValue('user-a'),
    ]);
    addTearDown(c.dispose);
    return c.read(userPreferencesNotifierProvider.notifier);
  }

  test('sends only currentTenantId, not the local metadata copy', () {
    notifier().updateCurrentTenantId(2);
    final attrs = verify(() => auth.updateUser(captureAny())).captured.single
        as UserAttributes;
    expect(attrs.data, {'currentTenantId': 2});
  });

  test('no write when the tenant is unchanged', () {
    notifier().updateCurrentTenantId(1);
    verifyNever(() => auth.updateUser(any()));
  });
}
