import 'dart:async';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/repositories/group_repository.dart';
import 'package:attendix/data/repositories/tenant_create_repository.dart';
import 'package:attendix/features/tenant_selection/presentation/pages/tenant_create_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show GoTrueClient, User;

const created = Tenant(
  id: 42,
  shortName: 'O',
  longName: 'Orchester',
  type: 'orchestra',
);
final account = StateProvider<String>((ref) => 'u1');

class Auth extends Fake implements GoTrueClient {
  @override
  User? get currentUser => null;
}

class CreateRepo extends Fake implements TenantCreateRepository {
  int calls = 0;
  Completer<Tenant>? pending;
  @override
  Future<Tenant> createTenant({
    required String shortName,
    required String longName,
    required String type,
    required String mainGroupName,
    String? timezone,
  }) async {
    calls++;
    return pending?.future ?? created.copyWith(type: type);
  }
}

class GroupsRepo extends Fake implements GroupRepository {
  int writes = 0;
  bool fail = false;
  @override
  Role get currentUserRole => Role.admin;
  @override
  void ensureNotDemo(String operation) {}
  @override
  Future<List<Group>> getGroups() async => [];
  @override
  Future<List<GroupCategory>> getGroupCategories() async => [];
  @override
  Future<GroupCategory> createGroupCategory({
    required String name,
    int? sortOrder,
  }) async => GroupCategory(id: 1, name: name);
  @override
  Future<List<Group>> createGroups(List<Map<String, dynamic>> rows) async {
    writes++;
    if (fail) throw StateError('connection lost');
    return [for (final row in rows) Group.fromJson(row)];
  }
}

class TenantState extends CurrentTenantNotifier {
  TenantState(super.ref);
  @override
  Future<void> setTenant(Tenant? tenant) async {
    state = tenant;
  }
}

Future<ProviderContainer> launch(
  WidgetTester tester,
  CreateRepo create,
  GroupsRepo groups,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(393, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/create',
    routes: [
      GoRoute(path: '/create', builder: (_, __) => const TenantCreatePage()),
      GoRoute(
        path: RedesignRoutes.today,
        builder: (_, __) => const Scaffold(body: Text('today destination')),
      ),
      GoRoute(
        path: RedesignRoutes.groups,
        builder: (_, __) => const Scaffold(body: Text('groups destination')),
      ),
      GoRoute(
        path: '/tenants',
        builder: (_, __) => const Scaffold(body: Text('tenants destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAuthProvider.overrideWithValue(Auth()),
        currentAuthUserIdProvider.overrideWith((ref) => ref.watch(account)),
        currentTenantProvider.overrideWith((ref) => TenantState(ref)),
        currentTenantUserProvider.overrideWith(
          (ref) async => const TenantUser(tenantId: 42, userId: 'u1', role: 0),
        ),
        tenantCreateRepositoryProvider.overrideWithValue(create),
        groupRepositoryForTenantProvider(42).overrideWithValue(groups),
        connectivityCheckProvider.overrideWithValue(() async => true),
        userTenantsProvider.overrideWith((ref) async => [created]),
      ],
      child: MaterialApp.router(
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(TenantCreatePage)),
  );
}

Future<void> choose(WidgetTester tester, String type, String preset) async {
  await tester.tap(find.text(type));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('rd-tenant-catalog')));
  await tester.tap(find.byKey(const Key('rd-tenant-catalog')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('catalog-presets')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(preset));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Übernehmen'));
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('rd-tenant-new-name')),
    'Orchester',
  );
  await tester.enterText(find.byKey(const Key('rd-tenant-new-short')), 'O');
  await tester.enterText(
    find.byKey(const Key('rd-tenant-new-main')),
    'Leitung',
  );
  await tester.tap(find.text('Gründen'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'general starts without catalog; type change clears the selection',
    (tester) async {
      await launch(tester, CreateRepo(), GroupsRepo());
      expect(find.byKey(const Key('rd-tenant-catalog')), findsNothing);
      await choose(tester, 'Orchester', 'Sinfonieorchester');
      expect(find.text('14 Einträge ausgewählt'), findsOneWidget);
      await tester.ensureVisible(find.text('Chor'));
      await tester.tap(find.text('Chor'));
      await tester.pumpAndSettle();
      expect(find.text('Keine Auswahl'), findsOneWidget);
    },
  );
  testWidgets('empty setup creates once and skips instrument writes', (
    tester,
  ) async {
    final create = CreateRepo();
    final groups = GroupsRepo();
    await launch(tester, create, groups);
    await submit(tester);
    expect(create.calls, 1);
    expect(groups.writes, 0);
    expect(find.text('today destination'), findsOneWidget);
  });
  testWidgets('choir preset is imported into the newly created tenant', (
    tester,
  ) async {
    final create = CreateRepo();
    final groups = GroupsRepo();
    await launch(tester, create, groups);
    await choose(tester, 'Chor', 'Gemischter Chor (SATB)');
    await submit(tester);
    expect(create.calls, 1);
    expect(groups.writes, 1);
    expect(find.text('today destination'), findsOneWidget);
  });
  testWidgets(
    'failed selection goes to instruments without offering tenant creation again',
    (tester) async {
      final create = CreateRepo();
      final groups = GroupsRepo()..fail = true;
      await launch(tester, create, groups);
      await choose(tester, 'Orchester', 'Sinfonieorchester');
      await submit(tester);
      expect(create.calls, 1);
      expect(groups.writes, 1);
      expect(find.text('groups destination'), findsOneWidget);
      expect(find.textContaining('Ensemble angelegt.'), findsOneWidget);
      expect(find.text('Gründen'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    },
  );
  testWidgets(
    'account switch during creation prevents tenant selection and import',
    (tester) async {
      final create = CreateRepo()..pending = Completer<Tenant>();
      final groups = GroupsRepo();
      final container = await launch(tester, create, groups);
      await tester.enterText(
        find.byKey(const Key('rd-tenant-new-name')),
        'Orchester',
      );
      await tester.enterText(find.byKey(const Key('rd-tenant-new-short')), 'O');
      await tester.enterText(
        find.byKey(const Key('rd-tenant-new-main')),
        'Leitung',
      );
      await tester.tap(find.text('Gründen'));
      await tester.pump();
      container.read(account.notifier).state = 'u2';
      create.pending!.complete(created);
      await tester.pumpAndSettle();
      expect(container.read(currentTenantProvider), isNull);
      expect(groups.writes, 0);
      expect(find.text('today destination'), findsNothing);
    },
  );
}
