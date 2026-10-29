// SOL_FIX12: enqueueIfOffline captures author/tenant/session before the
// connectivity await; a switch during that await neither queues the write
// under the new account nor falls back to a direct write.
import 'dart:async';

import 'package:attendix/core/providers/connectivity_provider.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/data/repositories/attendance_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String? currentUser;
  late String? currentSession;
  late Completer<bool> connectivity;

  ProviderContainer createContainer() {
    final authEvents = StreamController<AuthChangeEvent>.broadcast();
    addTearDown(authEvents.close);
    final container = ProviderContainer(overrides: [
      connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
      connectivityCheckProvider.overrideWithValue(() => connectivity.future),
      currentTenantIdProvider.overrideWithValue(42),
      offlineQueueUserIdProvider.overrideWithValue(() => currentUser),
      offlineQueueSessionIdProvider.overrideWithValue(() => currentSession),
      offlineQueueAuthEventsProvider.overrideWithValue(authEvents.stream),
      offlineFlushFnProvider.overrideWithValue((entry, _) async {}),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    currentUser = 'u1';
    currentSession = 's1';
    connectivity = Completer<bool>();
  });

  for (final online in [false, true]) {
    test('account switch during the connectivity check aborts (online: $online)',
        () async {
      final notifier =
          createContainer().read(offlineQueueNotifierProvider.notifier);
      final result = notifier.enqueueIfOffline('pa1', {'status': 1});
      currentUser = 'u2';
      currentSession = 's2';
      connectivity.complete(online);

      await expectLater(result, throwsA(isA<OfflineSessionChangedException>()));
      expect(await OfflineQueueStore().load(), isEmpty);
    });
  }

  test('without a switch the write is queued for the captured user', () async {
    final notifier =
        createContainer().read(offlineQueueNotifierProvider.notifier);
    final result = notifier.enqueueIfOffline('pa1', {'status': 1});
    connectivity.complete(false);

    expect(await result, isTrue);
    final queued = await OfflineQueueStore().load();
    expect(queued.single.userId, 'u1');
    expect(queued.single.tenantId, 42);
  });
}
