// Ionic db.getPlayers: "Fehler beim Laden der Personen" on the Statistik.
// A failure that is already stored when the page opens must be shown once,
// after the first frame – not while the page builds (that threw
// "setState() or markNeedsBuild() called during build").
import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/statistics_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/utils/global_toast.dart';
import 'package:attendix/core/utils/toast_helper.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/features/statistics/presentation/pages/statistics_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks/supabase_mocks.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => GlobalToast.contextResolver = null);

  testWidgets('already failed people load: exactly one toast, no exception',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = MockGoTrueClient();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());

    var peopleLoads = 0;
    final container = ProviderContainer(overrides: [
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      supabaseAuthProvider.overrideWithValue(auth),
      currentAuthUserIdProvider.overrideWithValue(null),
      currentRoleProvider.overrideWithValue(Role.admin),
      effectiveRoleProvider.overrideWithValue(Role.admin),
      playersProvider.overrideWith((ref) async {
        peopleLoads++;
        throw Exception('offline');
      }),
      activePlayersForStatsProvider.overrideWith((ref) async => <Person>[]),
    ]);
    addTearDown(container.dispose);

    // The failure is stored before the Statistik opens (other page).
    container.listen(playersProvider, (_, __) {});
    await expectLater(container.read(playersProvider.future), throwsException);
    expect(container.read(playersProvider).hasError, isTrue);
    await container.read(activePlayersForStatsProvider.future);

    final navigatorKey = GlobalKey<NavigatorState>();
    GlobalToast.contextResolver = () => navigatorKey.currentContext;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StatisticsPage(),
      ),
    ));
    expect(tester.takeException(), isNull);
    await tester.pump();
    expect(tester.takeException(), isNull);

    // The root navigator context sits above the overlay: the toast is the
    // root messenger's SnackBar (an Ionic md toast with an overlay above).
    Finder toasts() => find.byWidgetPredicate((w) => w is SnackBar || w is IonMdToast);
    expect(toasts(), findsOneWidget);
    expect(find.text(l10nWithoutContext.dbLoadPeopleFailed), findsOneWidget);

    // Further frames (rebuilds) do not repeat the toast.
    await tester.pump(const Duration(milliseconds: 500));
    expect(toasts(), findsOneWidget);
    expect(find.text(l10nWithoutContext.dbLoadPeopleFailed), findsOneWidget);
    expect(peopleLoads, 1);
    expect(tester.takeException(), isNull);

    // Let the toast time out.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
  });
}
