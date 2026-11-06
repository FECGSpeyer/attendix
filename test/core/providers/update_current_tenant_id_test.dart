import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/user_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../mocks/supabase_mocks.dart';

/// Ionic db.service setCurrentTenant / setWantInstanceSelection: updateUser
/// sends only the changed keys – GoTrue merges them, so a stale local
/// user_metadata copy must not be sent back (it would reset settings changed
/// on another device). The merged metadata the server returns must reach the
/// already loaded [userPreferencesProvider].
void main() {
  late MockGoTrueClient auth;
  late ProviderContainer container;

  User user(Map<String, dynamic> metadata) => User(
        id: 'user-a',
        appMetadata: const {},
        userMetadata: metadata,
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );

  /// Local copy before the write (stale: other device changed settings).
  const localMetadata = <String, dynamic>{
    'currentTenantId': 1,
    'showSongsTab_1': false,
    'dashboardCards_1': ['a'],
    'wantInstanceSelection': false,
  };

  /// Emulates GoTrue: merge the sent keys into the server metadata (null
  /// removes a key) and store the returned user as the local copy, like
  /// gotrue-dart does.
  void serverMerges(Map<String, dynamic> serverMetadata) {
    when(() => auth.updateUser(any())).thenAnswer((inv) async {
      final attrs = inv.positionalArguments.first as UserAttributes;
      final merged = {...serverMetadata};
      (attrs.data as Map<String, dynamic>).forEach((key, value) {
        if (value == null) {
          merged.remove(key);
        } else {
          merged[key] = value;
        }
      });
      when(() => auth.currentUser).thenReturn(user(merged));
      return UserResponse.fromJson(const {});
    });
  }

  setUpAll(() => registerFallbackValue(UserAttributes()));

  setUp(() {
    auth = MockGoTrueClient();
    when(() => auth.currentUser).thenReturn(user(localMetadata));
    serverMerges(localMetadata);
    container = ProviderContainer(overrides: [
      supabaseAuthProvider.overrideWithValue(auth),
      currentAuthUserIdProvider.overrideWithValue('user-a'),
    ]);
    addTearDown(container.dispose);
  });

  UserPreferencesNotifier notifier() =>
      container.read(userPreferencesNotifierProvider.notifier);

  Map<String, dynamic>? sentData() =>
      (verify(() => auth.updateUser(captureAny())).captured.single
              as UserAttributes)
          .data as Map<String, dynamic>?;

  group('updateCurrentTenantId', () {
    test('sends only currentTenantId, not the local metadata copy', () {
      notifier().updateCurrentTenantId(2);
      expect(sentData(), {'currentTenantId': 2});
    });

    test('no write when the tenant is unchanged', () {
      notifier().updateCurrentTenantId(1);
      verifyNever(() => auth.updateUser(any()));
    });

    test('loaded preferences show the metadata returned by the server',
        () async {
      // Another device enabled the instance selection meanwhile.
      serverMerges({...localMetadata, 'wantInstanceSelection': true});
      final before = container.read(userPreferencesProvider);
      expect(before.wantInstanceSelection, isFalse);
      expect(before.currentTenantId, 1);

      notifier().updateCurrentTenantId(2);
      await pumpEventQueue();

      final after = container.read(userPreferencesProvider);
      expect(after.currentTenantId, 2);
      expect(after.wantInstanceSelection, isTrue);
    });

    test('a failed write does not throw', () async {
      when(() => auth.updateUser(any()))
          .thenAnswer((_) async => throw Exception('offline'));
      notifier().updateCurrentTenantId(2);
      await pumpEventQueue();
      expect(container.read(userPreferencesProvider).currentTenantId, 1);
    });
  });

  group('clearCurrentTenantId', () {
    test('sends only the removal of currentTenantId', () {
      notifier().clearCurrentTenantId();
      expect(sentData(), {'currentTenantId': null});
    });

    test('loaded preferences show the cleared tenant', () async {
      expect(container.read(userPreferencesProvider).currentTenantId, 1);

      notifier().clearCurrentTenantId();
      await pumpEventQueue();

      expect(container.read(userPreferencesProvider).currentTenantId, isNull);
    });
  });

  group('updatePreferences', () {
    test('sends only the changed keys', () async {
      await notifier().updatePreferences(wantInstanceSelection: true);
      expect(sentData(), {'wantInstanceSelection': true});
    });

    test('loaded preferences show the metadata returned by the server',
        () async {
      // Another device switched the instance meanwhile.
      serverMerges({...localMetadata, 'currentTenantId': 3});
      expect(container.read(userPreferencesProvider).currentTenantId, 1);

      await notifier().updatePreferences(wantInstanceSelection: true);

      final after = container.read(userPreferencesProvider);
      expect(after.wantInstanceSelection, isTrue);
      expect(after.currentTenantId, 3);
    });
  });
}
