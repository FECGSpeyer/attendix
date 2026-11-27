import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/connectivity_provider.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/core/theme/app_palette.dart';
import 'package:attendix/core/theme/design_theme.dart';
import 'package:attendix/data/models/instrument/instrument.dart';
import 'package:attendix/data/repositories/group_repository.dart';
import 'package:attendix/features/instruments/presentation/pages/group_edit_page.dart';
import 'package:attendix/shared/widgets/components/components.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../factories/test_factories.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, type: 'orchestra');
  }
}

/// Records the writes instead of calling Supabase.
class _FakeGroupRepo extends GroupRepository {
  _FakeGroupRepo(super.ref) {
    setTenantId(7);
  }

  final updates = <Map<String, dynamic>>[];

  @override
  Future<Group> updateGroup(int id, Map<String, dynamic> updates) async {
    this.updates.add(Map.of(updates));
    return _violin;
  }
}

const _violin = Group(
  id: 5,
  name: 'Violine',
  categoryId: 10,
  tuning: 'C',
  clefs: ['g'],
);
const _main = Group(id: 6, name: 'Dirigenten', maingroup: true);

Widget _app(
  void Function(_FakeGroupRepo) onRepo, {
  int groupId = 5,
  int members = 2,
  Group instrument = _violin,
  Locale locale = const Locale('de'),
  double textScale = 1,
}) {
  final router = GoRouter(
    initialLocation: '/ich/verwaltung/gruppen/$groupId',
    routes: [
      GoRoute(
        path: '/ich/verwaltung/gruppen',
        builder: (_, __) => const Scaffold(body: Text('page groups')),
        routes: [
          GoRoute(
            path: ':id',
            builder:
                (_, s) => RdGroupEditPage(
                  groupId: int.parse(s.pathParameters['id']!),
                ),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      effectiveRoleProvider.overrideWithValue(Role.admin),
      currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
      currentTenantIdProvider.overrideWithValue(7),
      offlineQueueUserIdProvider.overrideWithValue(() => 'u1'),
      connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
      offlineQueueSessionIdProvider.overrideWithValue(() => 's1'),
      groupRepositoryWithTenantProvider.overrideWith((ref) {
        final repo = _FakeGroupRepo(ref);
        onRepo(repo);
        return repo;
      }),
      groupsProvider.overrideWith((ref) async => [instrument, _main]),
      groupCategoriesProvider.overrideWith(
        (ref) async => const [GroupCategory(id: 10, name: 'Streicher')],
      ),
      rdGroupMemberCountProvider(groupId).overrideWith((ref) async => members),
    ],
    child: MaterialApp.router(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      routerConfig: router,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('RdGroupEditPage', () {
    testWidgets('every field of the old page, saved right away', (
      tester,
    ) async {
      _phone(tester);
      late _FakeGroupRepo repo;
      await tester.pumpWidget(_app((r) => repo = r));
      await _settle(tester);

      expect(find.text('Instrument bearbeiten'), findsOneWidget);
      expect(find.text('Streicher'), findsOneWidget); // Kategorie
      expect(find.text('STIMMUNG'), findsOneWidget);
      expect(find.text('Tonumfang'), findsOneWidget);
      expect(find.text('SYNONYME'), findsOneWidget);
      expect(find.text('Synonyme generieren'), findsOneWidget);

      await tester.tap(find.text('B'));
      await tester.tap(find.text('Bassschlüssel (F)'));
      await tester.enterText(
        find.byKey(const Key('rd-group-edit-name')),
        'Violine 1',
      );
      await tester.tap(find.byKey(const Key('rd-group-edit-done')));
      await _settle(tester);

      expect(repo.updates, [
        {'tuning': 'B'},
        {
          'clefs': ['g', 'f'],
        },
        {'name': 'Violine 1'},
      ]);
      expect(find.text('page groups'), findsOneWidget);
    });

    testWidgets('says why a group with members cannot be deleted', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app((_) {}));
      await _settle(tester);
      await tester.ensureVisible(find.byKey(const Key('rd-group-edit-delete')));
      await _settle(tester);
      expect(
        find.textContaining(
          'Verschiebe sie zuerst zu einem anderen Instrument.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the main group hides the music fields and cannot be deleted', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app((_) {}, groupId: 6, members: 0));
      await _settle(tester);
      expect(find.textContaining('Das ist die Hauptgruppe'), findsOneWidget);
      expect(find.text('STIMMUNG'), findsNothing);
      expect(find.text('SYNONYME'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('rd-group-edit-delete')));
      await _settle(tester);
      expect(
        find.text('Die Hauptgruppe lässt sich nicht löschen.'),
        findsOneWidget,
      );
    });

    for (final clefs in <List<String>?>[null, const []]) {
      testWidgets('unset metadata stays visible without writing ($clefs)', (
        tester,
      ) async {
        _phone(tester);
        late _FakeGroupRepo repo;
        await tester.pumpWidget(
          _app(
            (r) => repo = r,
            instrument: Group(id: 5, name: 'Schlagwerk', clefs: clefs),
          ),
        );
        await _settle(tester);

        expect(
          tester
              .widget<RdChoiceChip>(
                find.byKey(const Key('rd-group-edit-tuning-unset')),
              )
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<RdChoiceChip>(
                find.byKey(const Key('rd-group-edit-tuning-C')),
              )
              .selected,
          isFalse,
        );
        expect(
          tester
              .widget<RdChoiceChip>(
                find.byKey(const Key('rd-group-edit-clef-G')),
              )
              .selected,
          isFalse,
        );
        expect(
          tester
              .widget<RdChoiceChip>(
                find.byKey(const Key('rd-group-edit-clefs-unset')),
              )
              .selected,
          isTrue,
        );
        await tester.tap(find.byKey(const Key('rd-group-edit-done')));
        await _settle(tester);
        expect(repo.updates, isEmpty);
      });
    }

    testWidgets(
      'chooses music metadata from an unset instrument without an invented clef',
      (tester) async {
        _phone(tester);
        late _FakeGroupRepo repo;
        await tester.pumpWidget(
          _app(
            (r) => repo = r,
            instrument: const Group(id: 5, name: 'Schlagwerk', clefs: []),
          ),
        );
        await _settle(tester);

        await tester.tap(find.text('C'));
        await tester.tap(find.text('Bassschlüssel (F)'));
        await _settle(tester);
        expect(repo.updates, [
          {'tuning': 'C'},
          {
            'clefs': ['f'],
          },
        ]);
      },
    );

    testWidgets('clears tuning and the final clef explicitly', (tester) async {
      _phone(tester);
      late _FakeGroupRepo repo;
      await tester.pumpWidget(_app((r) => repo = r));
      await _settle(tester);

      await tester.tap(find.byKey(const Key('rd-group-edit-tuning-unset')));
      await tester.tap(find.text('Violinschlüssel (G)'));
      await _settle(tester);
      expect(repo.updates, [
        {'tuning': null},
        {'clefs': <String>[]},
      ]);
      expect(
        tester
            .widget<RdChoiceChip>(
              find.byKey(const Key('rd-group-edit-clefs-unset')),
            )
            .selected,
        isTrue,
      );
    });

    testWidgets('clears multiple clefs through the unset choice', (
      tester,
    ) async {
      _phone(tester);
      late _FakeGroupRepo repo;
      await tester.pumpWidget(
        _app(
          (r) => repo = r,
          instrument: const Group(
            id: 5,
            name: 'Viola',
            tuning: 'C',
            clefs: ['g', 'c'],
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(find.byKey(const Key('rd-group-edit-clefs-unset')));
      await _settle(tester);
      expect(repo.updates, [
        {'clefs': <String>[]},
      ]);
      expect(
        tester
            .widget<RdChoiceChip>(find.byKey(const Key('rd-group-edit-clef-G')))
            .selected,
        isFalse,
      );
      expect(
        tester
            .widget<RdChoiceChip>(find.byKey(const Key('rd-group-edit-clef-C')))
            .selected,
        isFalse,
      );
    });

    testWidgets('unset choices remain accessible with enlarged text', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          (_) {},
          instrument: const Group(id: 5, name: 'Percussion', clefs: []),
          locale: const Locale('en'),
          textScale: 2,
        ),
      );
      await _settle(tester);
      expect(find.text('Not set'), findsNWidgets(2));
      await tester.ensureVisible(
        find.byKey(const Key('rd-group-edit-clefs-unset')),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
