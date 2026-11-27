import 'dart:async';

import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/router/app_routes.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/shared/widgets/components/components.dart';
import 'package:attendix/features/tenant_selection/presentation/pages/tenant_create_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'tenant_catalog_setup_test.dart'
    show launch, CreateRepo, GroupsRepo, account, created;

class RecordingCreate extends CreateRepo {
  String? savedName;
  String? savedShort;
  String? savedMain;
  String? savedType;
  @override
  Future<Tenant> createTenant({
    required String shortName,
    required String longName,
    required String type,
    required String mainGroupName,
    String? timezone,
  }) {
    savedName = longName;
    savedShort = shortName;
    savedMain = mainGroupName;
    savedType = type;
    return super.createTenant(
      shortName: shortName,
      longName: longName,
      type: type,
      mainGroupName: mainGroupName,
      timezone: timezone,
    );
  }
}

Future<void> next(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('rd-tenant-guide-next')));
  await tester.pumpAndSettle();
}

Future<void> back(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('rd-tenant-guide-back')));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String value) async {
  await Scrollable.ensureVisible(
    tester.element(find.byKey(Key('rd-tenant-type-$value'))),
    alignment: 0.5,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('rd-tenant-type-$value')));
  await tester.pumpAndSettle();
  await next(tester);
}

void main() {
  for (final queuedAction in ['none', 'cancel', 'create']) {
    testWidgets(
      'cancel from a pushed guide returns once and blocks a queued $queuedAction',
      (tester) async {
        final create = CreateRepo();
        await launch(tester, create, GroupsRepo());
        final router = GoRouter.of(
          tester.element(find.byType(TenantCreatePage)),
        );
        router.go('/tenants');
        await tester.pumpAndSettle();
        router.push(RedesignRoutes.groups);
        await tester.pumpAndSettle();
        router.push('/create');
        await tester.pumpAndSettle();
        await type(tester, 'general');
        await tester.enterText(
          find.byKey(const Key('rd-tenant-new-name')),
          'Testgruppe',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Abbrechen'));
        if (queuedAction == 'cancel') {
          await tester.tap(find.text('Abbrechen'));
        } else if (queuedAction == 'create') {
          await tester.tap(find.byKey(const Key('rd-tenant-guide-create')));
        }
        await tester.pumpAndSettle();
        expect(find.text('groups destination'), findsOneWidget);
        expect(create.calls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'system back preserves identity and cancel exits from a later step',
    (tester) async {
      await launch(tester, CreateRepo(), GroupsRepo());
      await type(tester, 'orchestra');
      await tester.enterText(
        find.byKey(const Key('rd-tenant-new-name')),
        'Unser Orchester',
      );
      await next(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Wie heißt dein Orchester?'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('rd-tenant-new-name')))
            .controller!
            .text,
        'Unser Orchester',
      );
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(find.text('tenants destination'), findsOneWidget);
    },
  );

  testWidgets('pending final creation blocks duplicate clicks and back', (
    tester,
  ) async {
    final create = RecordingCreate()..pending = Completer<Tenant>();
    await launch(tester, create, GroupsRepo());
    await type(tester, 'general');
    await tester.enterText(find.byKey(const Key('rd-tenant-new-name')), 'Team');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rd-tenant-guide-create')));
    await tester.tap(find.byKey(const Key('rd-tenant-guide-create')));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(create.calls, 1);
    expect(find.text('Wie heißt deine Gruppe?'), findsOneWidget);
    create.pending!.complete(created.copyWith(type: 'general'));
    await tester.pumpAndSettle();
    expect(find.text('today destination'), findsOneWidget);
  });

  testWidgets(
    'narrow guide starts each question at the top and keeps keyboard actions reachable',
    (tester) async {
      await launch(
        tester,
        CreateRepo(),
        GroupsRepo(),
        screenSize: const Size(320, 760),
        textScale: 1.8,
      );
      await type(tester, 'general');
      final question = find.text('Wie heißt deine Gruppe?');
      expect(tester.getTopLeft(question).dy, greaterThan(50));
      expect(tester.getTopLeft(question).dy, lessThan(240));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('rd-tenant-new-name')),
        'Gruppe',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final action = tester.getRect(
        find.byKey(const Key('rd-tenant-guide-create')),
      );
      expect(action.bottom, lessThanOrEqualTo(460));
      expect(action.top, greaterThan(0));
    },
  );

  testWidgets(
    'guide asks for a type and writes only after final confirmation',
    (tester) async {
      final create = RecordingCreate();
      final groups = GroupsRepo();
      await launch(tester, create, groups);
      expect(
        find.text('Welche Art von Gruppe möchtest du erstellen?'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('rd-tenant-new-name')), findsNothing);
      await next(tester);
      expect(
        find.text('Welche Art von Gruppe möchtest du erstellen?'),
        findsOneWidget,
      );
      await type(tester, 'orchestra');
      expect(find.text('Wie heißt dein Orchester?'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('rd-tenant-new-name')),
        'Stadtorchester Musterstadt',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('rd-tenant-new-short')))
            .controller!
            .text,
        'SM',
      );
      await next(tester);
      expect(
        find.text('Mit welcher Besetzung möchtest du starten?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Volksinstrumentenorchester'));
      await tester.pumpAndSettle();
      expect(create.calls, 0);
      expect(groups.writes, 0);
      await tester.tap(find.byKey(const Key('rd-tenant-guide-create')));
      await tester.pumpAndSettle();
      expect(create.calls, 1);
      expect(create.savedMain, 'Leitung');
      expect(create.savedType, 'orchestra');
      expect(groups.writes, 1);
      expect(find.text('today destination'), findsOneWidget);
    },
  );

  testWidgets(
    'manual abbreviation and identity survive back and type changes',
    (tester) async {
      final create = RecordingCreate();
      await launch(tester, create, GroupsRepo());
      await type(tester, 'orchestra');
      await tester.enterText(
        find.byKey(const Key('rd-tenant-new-name')),
        'Überall Musik',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('rd-tenant-new-short')))
            .controller!
            .text,
        'ÜM',
      );
      await tester.enterText(
        find.byKey(const Key('rd-tenant-new-short')),
        'UMX',
      );
      await tester.enterText(
        find.byKey(const Key('rd-tenant-new-name')),
        'Neuer Name',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('rd-tenant-new-short')))
            .controller!
            .text,
        'UMX',
      );
      await back(tester);
      await type(tester, 'general');
      expect(find.text('Schritt 2 von 2'), findsOneWidget);
      expect(find.text('Wie heißt deine Gruppe?'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('rd-tenant-new-name')))
            .controller!
            .text,
        'Neuer Name',
      );
      await tester.tap(find.byKey(const Key('rd-tenant-guide-create')));
      await tester.pumpAndSettle();
      expect(create.savedShort, 'UMX');
      expect(create.savedName, 'Neuer Name');
    },
  );

  testWidgets(
    'type switching restores presets and custom entries; general imports none',
    (tester) async {
      final create = RecordingCreate();
      final groups = GroupsRepo();
      await launch(tester, create, groups);
      await type(tester, 'orchestra');
      await tester.enterText(
        find.byKey(const Key('rd-tenant-new-name')),
        'Orchester',
      );
      await next(tester);
      await tester.tap(find.text('Volksinstrumentenorchester'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rd-tenant-catalog')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Eigene Begleitung');
      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-apply')));
      await tester.pumpAndSettle();
      await back(tester);
      await back(tester);
      await type(tester, 'choir');
      await next(tester);
      await tester.tap(find.text('Gemischter Chor (SATB)'));
      await tester.pumpAndSettle();
      await back(tester);
      await back(tester);
      await type(tester, 'orchestra');
      await next(tester);
      expect(find.textContaining('10 Einträge ausgewählt'), findsWidgets);
      await tester.tap(find.byKey(const Key('rd-tenant-catalog')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ausgewählt'));
      await tester.pumpAndSettle();
      expect(find.text('Eigene Begleitung'), findsOneWidget);
      final restoredCustom = find.ancestor(
        of: find.text('Eigene Begleitung'),
        matching: find.byType(RdListRow),
      );
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(
                of: restoredCustom,
                matching: find.byType(Checkbox),
              ),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('catalog-apply')));
      await tester.pumpAndSettle();
      await back(tester);
      await back(tester);
      await type(tester, 'general');
      await tester.tap(find.byKey(const Key('rd-tenant-guide-create')));
      await tester.pumpAndSettle();
      expect(create.savedType, 'general');
      expect(create.savedShort, 'ORC');
      expect(groups.writes, 0);
    },
  );

  testWidgets('leadership name can be changed in the final summary', (
    tester,
  ) async {
    final create = RecordingCreate();
    await launch(tester, create, GroupsRepo());
    await type(tester, 'general');
    await tester.enterText(find.byKey(const Key('rd-tenant-new-name')), 'Team');
    await tester.ensureVisible(
      find.byKey(const Key('rd-tenant-guide-leadership')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rd-tenant-guide-leadership')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Vorstand');
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rd-tenant-guide-create')));
    await tester.pumpAndSettle();
    expect(create.savedMain, 'Vorstand');
  });

  for (final switchAccount in [true, false]) {
    testWidgets(
      'leadership edit ignores a stale scope (account: $switchAccount)',
      (tester) async {
        final container = await launch(tester, CreateRepo(), GroupsRepo());
        await type(tester, 'general');
        await tester.enterText(
          find.byKey(const Key('rd-tenant-new-name')),
          'Team',
        );
        final leadership = find.byKey(const Key('rd-tenant-guide-leadership'));
        await tester.ensureVisible(leadership);
        await tester.pumpAndSettle();
        await tester.tap(leadership);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Vorstand');
        if (switchAccount) {
          container.read(account.notifier).state = 'u2';
        } else {
          await container
              .read(currentTenantProvider.notifier)
              .setTenant(created);
        }
        await tester.tap(find.text('Fertig'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: leadership, matching: find.text('Leitung')),
          findsOneWidget,
        );
        expect(find.text('Vorstand'), findsNothing);
      },
    );
  }

  testWidgets('English guide uses contextual copy and default Leadership', (
    tester,
  ) async {
    final create = RecordingCreate();
    await launch(tester, create, GroupsRepo(), locale: const Locale('en'));
    await type(tester, 'choir');
    expect(find.text('What is your choir called?'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('rd-tenant-new-name')),
      'Chamber Choir',
    );
    await next(tester);
    expect(find.text('Step 3 of 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rd-tenant-guide-create')));
    await tester.pumpAndSettle();
    expect(create.savedMain, 'Leadership');
    expect(create.savedShort, 'CC');
    expect(create.savedType, 'choir');
  });

  testWidgets('empty and whitespace identity cannot advance', (tester) async {
    final create = RecordingCreate();
    await launch(tester, create, GroupsRepo());
    await type(tester, 'choir');
    await tester.enterText(find.byKey(const Key('rd-tenant-new-name')), '   ');
    await next(tester);
    expect(find.text('Wie heißt dein Chor?'), findsOneWidget);
    expect(create.calls, 0);
  });
}
