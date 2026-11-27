import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/tracking/tracking_event.dart';
import 'package:attendix/core/services/tracking/tracking_service.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/models/usage_event.dart';
import 'package:attendix/data/repositories/usage_events_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../factories/test_factories.dart';

class _MockUsageEventsRepository extends Mock
    implements UsageEventsRepository {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

/// Fake CurrentTenantNotifier that immediately sets the tenant without
/// touching SharedPreferences-backed initialization paths.
class _FakeCurrentTenantNotifier extends CurrentTenantNotifier {
  _FakeCurrentTenantNotifier(Tenant? initialTenant)
      : super(_FakeRef()) {
    state = initialTenant;
  }
}

/// Minimal fake Ref that returns mocks for the providers
/// `CurrentTenantNotifier._initializeTenant` reaches into.
class _FakeRef extends Fake implements Ref<Object?> {
  @override
  T read<T>(ProviderListenable<T> provider) {
    if (identical(provider, supabaseAuthProvider)) {
      return _MockGoTrueClient() as T;
    }
    if (identical(provider, supabaseClientProvider)) {
      return _MockSupabaseClient() as T;
    }
    throw UnimplementedError('Provider $provider not mocked');
  }

  @override
  T watch<T>(ProviderListenable<T> provider) => read(provider);

  @override
  void invalidate(ProviderOrFamily provider) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(const UsageEvent(
      eventName: 'fallback',
      deviceType: 'web',
    ));
  });

  group('TrackingService', () {
    late _MockUsageEventsRepository repo;

    setUp(() {
      repo = _MockUsageEventsRepository();
      when(() => repo.insert(any())).thenAnswer((_) async {});
    });

    ProviderContainer makeContainer({Tenant? tenant}) {
      return ProviderContainer(
        overrides: [
          usageEventsRepositoryProvider.overrideWithValue(repo),
          currentTenantProvider.overrideWith(
            (ref) => _FakeCurrentTenantNotifier(tenant),
          ),
          // Force web so test runs deterministically on any platform
          trackingDeviceTypeProvider.overrideWithValue('web'),
        ],
      );
    }

    test('track inserts a UsageEvent with current tenant id and device type',
        () async {
      final container =
          makeContainer(tenant: TestFactories.createTenant(id: 7));
      addTearDown(container.dispose);

      container
          .read(trackingServiceProvider)
          .track(TrackingEvent.login, properties: const {'foo': 'bar'});

      // fire-and-forget: give the unawaited future a tick to run
      await Future<void>.delayed(Duration.zero);

      final captured = verify(() => repo.insert(captureAny())).captured.single
          as UsageEvent;
      expect(captured.eventName, 'login');
      expect(captured.tenantId, 7);
      expect(captured.deviceType, 'web');
      expect(captured.properties, const {'foo': 'bar'});
    });

    test('track sends tenant_id null when no tenant is selected', () async {
      final container = makeContainer(tenant: null);
      addTearDown(container.dispose);

      container.read(trackingServiceProvider).track(TrackingEvent.pageView);
      await Future<void>.delayed(Duration.zero);

      final captured = verify(() => repo.insert(captureAny())).captured.single
          as UsageEvent;
      expect(captured.tenantId, isNull);
    });

    test('track swallows repository errors (fire-and-forget)', () async {
      when(() => repo.insert(any())).thenThrow(StateError('boom'));
      final container = makeContainer();
      addTearDown(container.dispose);

      // Must not throw synchronously and must not propagate the async error.
      expect(
        () =>
            container.read(trackingServiceProvider).track(TrackingEvent.login),
        returnsNormally,
      );
      await Future<void>.delayed(Duration.zero);
    });
  });
}
