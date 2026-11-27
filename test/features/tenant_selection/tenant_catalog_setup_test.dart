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
import 'package:attendix/shared/widgets/redesign/rd_widgets.dart';
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
  GroupsRepo groups, {
  Size screenSize = const Size(393, 1100),
  double textScale = 1,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('de'),
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = screenSize;
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
        debugShowCheckedModeBanner: false,
        theme: buildRdTheme(RdFarbwelt.petrol, brightness),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        locale: locale,
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

Future<void> beginGuide(WidgetTester tester, String type) async {
  final kind = {'Orchester': 'orchestra', 'Chor': 'choir'}[type] ?? 'general';
  final card = find.byKey(Key('rd-tenant-type-$kind'));
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('rd-tenant-guide-next')));
  await tester.pumpAndSettle();
}

Future<void> prepareCatalog(WidgetTester tester, String type) async {
  await beginGuide(tester, type);
  await tester.enterText(
    find.byKey(const Key('rd-tenant-new-name')),
    'Ensemble',
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('rd-tenant-guide-next')));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String type, String preset) async {
  await prepareCatalog(tester, type);
  await tester.ensureVisible(find.text(preset));
  await tester.pumpAndSettle();
  await tester.tap(find.text(preset));
  await tester.pumpAndSettle();
}

Finder selectionCount(String text) => find.descendant(
  of: find.byKey(const Key('rd-tenant-catalog')),
  matching: find.textContaining(text),
);

Future<void> submit(WidgetTester tester) async {
  if (find.byKey(const Key('rd-tenant-type-general')).evaluate().isNotEmpty) {
    await beginGuide(tester, 'Allgemein');
  } else if (find.byKey(const Key('rd-tenant-new-name')).evaluate().isEmpty) {
    await tester.tap(find.byKey(const Key('rd-tenant-guide-back')));
    await tester.pumpAndSettle();
  }
  await tester.enterText(
    find.byKey(const Key('rd-tenant-new-name')),
    'Orchester',
  );
  await tester.enterText(find.byKey(const Key('rd-tenant-new-short')), 'O');
  await tester.pumpAndSettle();
  if (find.byKey(const Key('rd-tenant-guide-next')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('rd-tenant-guide-next')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('rd-tenant-guide-create')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'direct presets remain usable on a narrow screen with large text',
    (tester) async {
      await launch(
        tester,
        CreateRepo(),
        GroupsRepo(),
        screenSize: const Size(320, 760),
        textScale: 1.8,
      );
      await choose(tester, 'Orchester', 'Volksinstrumentenorchester');
      expect(tester.takeException(), isNull);
      final selection = find.byKey(const Key('rd-tenant-catalog'));
      await tester.ensureVisible(selection);
      await tester.pumpAndSettle();
      expect(selectionCount('9 Einträge ausgewählt'), findsOneWidget);
      await tester.tap(selection);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Auswahl übernehmen'), findsOneWidget);
      await tester.tap(find.byKey(const Key('catalog-apply')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(selectionCount('9 Einträge ausgewählt'), findsOneWidget);
    },
  );

  testWidgets('setup offers presets directly in the instrumentation step', (
    tester,
  ) async {
    final groups = GroupsRepo();
    await launch(tester, CreateRepo(), groups);
    await prepareCatalog(tester, 'Orchester');
    expect(find.text('Volksinstrumentenorchester'), findsOneWidget);
    expect(find.byKey(const Key('rd-tenant-preset-later')), findsOneWidget);
    expect(find.byKey(const Key('rd-tenant-new-name')), findsNothing);
    expect(find.text('Schritt 3 von 3'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('rd-tenant-preset-symphony_orchestra')),
    );
    await tester.pumpAndSettle();
    expect(selectionCount('14 Einträge ausgewählt'), findsOneWidget);
    expect(find.byKey(const Key('catalog-search')), findsNothing);
    expect(groups.writes, 0);
    await tester.tap(find.byKey(const Key('rd-tenant-catalog')));
    await tester.pumpAndSettle();
    expect(find.text('Auswahl übernehmen'), findsOneWidget);
    expect(find.text('Sinfonieorchester'), findsWidgets);
  });

  testWidgets(
    'same preset preserves custom additions; switching can merge, cancel, or replace',
    (tester) async {
      await launch(tester, CreateRepo(), GroupsRepo());
      await choose(tester, 'Orchester', 'Sinfonieorchester');
      await tester.tap(find.byKey(const Key('rd-tenant-catalog')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Eigene Begleitung');
      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-apply')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('rd-tenant-preset-symphony_orchestra')),
      );
      await tester.pumpAndSettle();
      expect(selectionCount('15 Einträge ausgewählt'), findsOneWidget);
      expect(find.text('Ersetzen'), findsNothing);
      await tester.tap(
        find.byKey(const Key('rd-tenant-preset-string_orchestra')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen').last);
      await tester.pumpAndSettle();
      expect(selectionCount('15 Einträge ausgewählt'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('rd-tenant-preset-string_orchestra')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ergänzen'));
      await tester.pumpAndSettle();
      expect(selectionCount('15 Einträge ausgewählt'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('rd-tenant-preset-folk_orchestra')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ersetzen'));
      await tester.pumpAndSettle();
      expect(selectionCount('9 Einträge ausgewählt'), findsOneWidget);
    },
  );

  testWidgets(
    'Later asks before clearing an existing draft and cancellation keeps it',
    (tester) async {
      await launch(tester, CreateRepo(), GroupsRepo());
      await choose(tester, 'Chor', 'Gemischter Chor (SATB)');
      await tester.tap(find.text('Später einrichten'));
      await tester.pumpAndSettle();
      expect(find.text('Auswahl verwerfen?'), findsOneWidget);
      await tester.tap(find.text('Abbrechen').last);
      await tester.pumpAndSettle();
      expect(selectionCount('4 Einträge ausgewählt'), findsOneWidget);
      await tester.tap(find.text('Später einrichten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auswahl verwerfen'));
      await tester.pumpAndSettle();
      expect(find.text('Keine Auswahl'), findsOneWidget);
    },
  );

  testWidgets(
    'custom instrument merged by setup remains selected and removable in the picker',
    (tester) async {
      await launch(tester, CreateRepo(), GroupsRepo());
      await prepareCatalog(tester, 'Orchester');
      await tester.tap(find.byKey(const Key('rd-tenant-catalog')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Querflöte');
      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-apply')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('rd-tenant-preset-symphony_orchestra')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ergänzen'));
      await tester.pumpAndSettle();
      expect(selectionCount('14 Einträge ausgewählt'), findsOneWidget);
      await tester.tap(find.byKey(const Key('rd-tenant-catalog')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('catalog-search')),
        'Querflöte',
      );
      await tester.pumpAndSettle();
      final row = find.ancestor(
        of: find.text('Querflöte'),
        matching: find.byType(RdListRow),
      );
      final checkbox = find.descendant(
        of: row,
        matching: find.byType(Checkbox),
      );
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);
      await tester.ensureVisible(checkbox);
      await tester.pumpAndSettle();
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(find.text('13 Einträge ausgewählt'), findsOneWidget);
      await tester.tap(find.byKey(const Key('catalog-apply')));
      await tester.pumpAndSettle();
      expect(selectionCount('13 Einträge ausgewählt'), findsOneWidget);
    },
  );

  testWidgets(
    'account change during a direct preset dialog discards its result',
    (tester) async {
      final container = await launch(tester, CreateRepo(), GroupsRepo());
      await choose(tester, 'Orchester', 'Sinfonieorchester');
      await tester.tap(
        find.byKey(const Key('rd-tenant-preset-folk_orchestra')),
      );
      await tester.pumpAndSettle();
      container.read(account.notifier).state = 'u2';
      await tester.tap(find.text('Ersetzen'));
      await tester.pumpAndSettle();
      expect(selectionCount('14 Einträge ausgewählt'), findsOneWidget);
      final chip = tester.widget<RdChoiceChip>(
        find.byKey(const Key('rd-tenant-preset-symphony_orchestra')),
      );
      expect(chip.selected, isTrue);
    },
  );

  for (final switchAccount in [true, false]) {
    testWidgets(
      'setup discards picker result after scope change (account: $switchAccount)',
      (tester) async {
        final container = await launch(tester, CreateRepo(), GroupsRepo());
        await prepareCatalog(tester, 'Orchester');
        await tester.ensureVisible(find.byKey(const Key('rd-tenant-catalog')));
        await tester.tap(find.byKey(const Key('rd-tenant-catalog')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('catalog-presets')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sinfonieorchester').last);
        await tester.pumpAndSettle();
        if (switchAccount) {
          container.read(account.notifier).state = 'u2';
        } else {
          await container
              .read(currentTenantProvider.notifier)
              .setTenant(created);
        }
        await tester.tap(find.byKey(const Key('catalog-apply')));
        await tester.pumpAndSettle();
        expect(selectionCount('14 Einträge ausgewählt'), findsNothing);
        expect(find.text('Keine Auswahl'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'general starts without catalog; choir has an independent selection',
    (tester) async {
      await launch(tester, CreateRepo(), GroupsRepo());
      expect(find.byKey(const Key('rd-tenant-catalog')), findsNothing);
      await choose(tester, 'Orchester', 'Sinfonieorchester');
      expect(selectionCount('14 Einträge ausgewählt'), findsOneWidget);
      await tester.tap(find.byKey(const Key('rd-tenant-guide-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rd-tenant-guide-back')));
      await tester.pumpAndSettle();
      await prepareCatalog(tester, 'Chor');
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
      expect(find.byKey(const Key('rd-tenant-guide-create')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    },
  );
  testWidgets(
    'account switch during creation prevents tenant selection and import',
    (tester) async {
      final create = CreateRepo()..pending = Completer<Tenant>();
      final groups = GroupsRepo();
      final container = await launch(tester, create, groups);
      await beginGuide(tester, 'Allgemein');
      await tester.enterText(
        find.byKey(const Key('rd-tenant-new-name')),
        'Orchester',
      );
      await tester.enterText(find.byKey(const Key('rd-tenant-new-short')), 'O');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rd-tenant-guide-create')));
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
