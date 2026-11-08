import 'dart:async';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/church_providers.dart';
import 'package:attendix/core/providers/connectivity_provider.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/files_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/router/redesign_routes.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/repositories/extra_fields_repository.dart';
import 'package:attendix/data/repositories/song_repository.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_extra_field_edit_page.dart';
import 'package:attendix/features/redesign/presentation/pages/rd_extra_fields_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../helpers/test_helpers.dart';

/// Records the saved definitions instead of calling Supabase.
class _FakeExtraFieldsRepo extends ExtraFieldsRepository {
  _FakeExtraFieldsRepo(super.ref) {
    bindTenantId(7);
  }

  final saves = <({List<ExtraField> persons, List<ExtraField> songs})>[];
  final sanitized = <String>[];

  /// The next save waits for it.
  Completer<void>? gate;

  /// The next save fails.
  bool failNext = false;

  @override
  Future<void> saveFields({required List<ExtraField> personFields, required List<ExtraField> songFields}) async {
    if (failNext) {
      failNext = false;
      throw StateError('offline');
    }
    saves.add((persons: personFields, songs: songFields));
    final g = gate;
    gate = null;
    if (g != null) await g.future;
  }

  @override
  Future<void> sanitizeValues({
    required String table,
    required List<ExtraField> definitions,
    List<Object>? churchIds,
    int? songTenantId,
  }) async {
    sanitized.add(table);
  }
}

class _FakeSongRepo extends SongRepository {
  _FakeSongRepo(super.ref);

  @override
  Future<SongTenantSettings> getSongTenantSettings() async => const SongTenantSettings();
}

const _size = ExtraField(id: 'groesse', name: 'Größe', type: 'select', options: ['S', 'M'], defaultValue: 'S');
const _member = ExtraField(id: 'mitglied', name: 'Mitglied', type: 'boolean', visibleToPlayers: true);
const _publisher = ExtraField(id: 'verlag', name: 'Verlag', type: 'text', displayMode: 'underneath');

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    rdResetExtraFieldWrites();
  });

  group('Zusatzfelder', () {
    test('two sections with the lines of the old page as subtitle', () {
      final l10n = lookupAppLocalizations(const Locale('de'));
      final sections = rdExtraFieldSections(l10n, persons: const [_size, _member], songs: const [_publisher]);
      expect(sections.map((s) => s.title), ['Für Personen', 'Für Werke']);
      expect(sections.first.items.map((i) => i.title), ['Größe', 'Mitglied']);
      expect(sections.first.items.first.subtitle, 'Typ: Auswahl · Anzeige: Als Chip');
      expect(sections.first.items.last.subtitle, contains('Für Mitglieder sichtbar'));
      expect(sections.last.items.single.subtitle, contains('Unter dem Namen'));
    });

    test('lists and the field page are for leads only', () {
      final edit = RedesignRoutes.extraFieldEdit(song: false, id: 'groesse');
      expect(edit, '/ich/verwaltung/zusatzfelder/personen/groesse');
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.extraFields, Role.viewer), RedesignRoutes.me);
      expect(RedesignRoutes.roleRedirect(edit, Role.helper), RedesignRoutes.me);
      expect(RedesignRoutes.roleRedirect(edit, Role.responsible), isNull);
      expect(RedesignRoutes.roleRedirect(RedesignRoutes.extraFields, Role.admin), isNull);
    });

    testWidgets('edit page: every change of the old sheet is saved right away', (tester) async {
      final container = await _pumpEditPage(
        tester,
        location: RedesignRoutes.extraFieldEdit(song: false, id: 'groesse'),
      );
      final repo = container.read(extraFieldsRepositoryWithTenantProvider) as _FakeExtraFieldsRepo;

      expect(find.text('Zusatzfeld bearbeiten'), findsOneWidget);
      expect(find.text('Auswahl'), findsOneWidget); // Typ (read only)
      expect(find.text('Für Mitglieder sichtbar'), findsOneWidget);
      expect(find.text('Alle Werte auf Standard zurücksetzen'), findsOneWidget);

      // Darstellung, then a new first option.
      await tester.tap(find.text('Unter dem Namen'));
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('rd-extra-field-edit-option-0')), 'XS');
      await tester.tap(find.byKey(const Key('rd-extra-field-edit-done')));
      await _settle(tester);

      expect(find.text('page fields'), findsOneWidget);
      expect(repo.saves, hasLength(2));
      expect(repo.saves.first.persons.first.displayMode, 'underneath');
      final last = repo.saves.last;
      expect(last.persons.first.options, ['XS', 'M']);
      expect(last.persons.first.defaultValue, 'XS'); // first option = default (old page)
      expect(last.persons.last, _member); // the other fields stay as they are
      expect(last.songs, [_publisher]);
      expect(repo.sanitized, containsAll(['player', 'songs']));
      // The local tenant shows what was saved.
      final tenant = container.read(currentTenantProvider)!;
      expect(tenant.additionalFields!.first.options, ['XS', 'M']);
    });

    testWidgets('edit page: default A → B saving, back to A and closed: A is stored', (tester) async {
      final container = await _pumpEditPage(
        tester,
        location: RedesignRoutes.extraFieldEdit(song: true, id: 'verlag'),
        songs: const [ExtraField(id: 'verlag', name: 'Verlag', type: 'text', defaultValue: 'A')],
      );
      final repo = container.read(extraFieldsRepositoryWithTenantProvider) as _FakeExtraFieldsRepo;
      final gate = repo.gate = Completer<void>();

      await tester.enterText(find.byKey(const Key('rd-extra-field-edit-default')), 'B');
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester);
      expect(repo.saves.single.songs.single.defaultValue, 'B'); // still running

      await tester.enterText(find.byKey(const Key('rd-extra-field-edit-default')), 'A');
      await tester.tap(find.byKey(const Key('rd-extra-field-edit-done')));
      await _settle(tester);
      expect(find.text('page fields'), findsOneWidget);

      gate.complete();
      await _settle(tester);
      expect(repo.saves.map((s) => s.songs.single.defaultValue), ['B', 'A']);
      expect(container.read(currentTenantProvider)!.songAdditionalFields!.single.defaultValue, 'A');
    });

    testWidgets('edit page: a failed name save shows the stored name again', (tester) async {
      final container = await _pumpEditPage(tester, location: RedesignRoutes.extraFieldEdit(song: true, id: 'verlag'));
      final repo = container.read(extraFieldsRepositoryWithTenantProvider) as _FakeExtraFieldsRepo;
      repo.failNext = true;

      await tester.enterText(find.byKey(const Key('rd-extra-field-edit-name')), 'Herausgeber');
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester);

      expect(repo.saves, isEmpty);
      expect(find.text('Fehler beim Speichern'), findsOneWidget);
      final name = tester.widget<TextField>(find.byKey(const Key('rd-extra-field-edit-name')));
      expect(name.controller!.text, 'Verlag');
      await tester.pump(const Duration(seconds: 5)); // toast gone
    });
  });
}

/// "Zusatzfeld bearbeiten" at [location] for tenant 7 with a fake repository.
Future<ProviderContainer> _pumpEditPage(
  WidgetTester tester, {
  required String location,
  List<ExtraField> persons = const [_size, _member],
  List<ExtraField> songs = const [_publisher],
}) async {
  _phone(tester);
  final container = createTestContainer(
    tenant: TestFactories.createTenant(id: 7).copyWith(additionalFields: persons, songAdditionalFields: songs),
    overrides: [
      effectiveRoleProvider.overrideWithValue(Role.admin),
      currentTenantIdProvider.overrideWithValue(7),
      offlineQueueUserIdProvider.overrideWithValue(() => 'u1'),
      connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
      offlineQueueSessionIdProvider.overrideWithValue(() => 's1'),
      churchesProvider.overrideWith((ref) async => []),
      songRepositoryForTenantProvider.overrideWith((ref, key) => _FakeSongRepo(ref)),
      extraFieldsRepositoryWithTenantProvider.overrideWith((ref) => _FakeExtraFieldsRepo(ref)),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: RedesignRoutes.extraFields,
        builder: (_, __) => const Scaffold(body: Text('page fields')),
        routes: [
          GoRoute(
            path: ':list/:id',
            builder:
                (_, s) =>
                    RdExtraFieldEditPage(song: s.pathParameters['list'] == 'werke', fieldId: s.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        routerConfig: router,
      ),
    ),
  );
  await _settle(tester);
  return container;
}
