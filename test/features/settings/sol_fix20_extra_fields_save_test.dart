// SOL_FIX20: extra fields multi-step save cleans up values with the stored
// definitions snapshot, skips synced song libraries, aborts before any write
// when song settings fail to load, and keeps legacy text default `false`.
import 'dart:async';

import 'package:attendix/core/providers/church_providers.dart';
import 'package:attendix/core/providers/files_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/repositories/extra_fields_repository.dart';
import 'package:attendix/data/repositories/song_repository.dart';
import 'package:attendix/features/settings/data/extra_fields_helpers.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../helpers/test_helpers.dart';

/// Repository whose saveFields waits for [gate] (delayed server reply).
class _DelayedExtraFieldsRepository extends ExtraFieldsRepository {
  _DelayedExtraFieldsRepository(super.ref) {
    bindTenantId(1);
  }

  final gate = Completer<void>();
  final log = <String>[];
  List<String>? savedPersonIds;
  List<ExtraField>? savedPersonFields;
  final sanitized = <String, List<String>>{};
  int? songTenantId;

  @override
  Future<void> saveFields({
    required List<ExtraField> personFields,
    required List<ExtraField> songFields,
  }) async {
    savedPersonIds = personFields.map((f) => f.id).toList();
    savedPersonFields = personFields;
    log.add('save');
    await gate.future;
  }

  @override
  Future<void> sanitizeValues({
    required String table,
    required List<ExtraField> definitions,
    List<Object>? churchIds,
    int? songTenantId,
    Set<String>? previousIds,
    Map<String, Map<String, String>>? renamedOptions,
  }) async {
    if (table == 'songs') this.songTenantId = songTenantId;
    sanitized[table] = definitions.map((f) => f.id).toList();
    log.add('sanitize:$table');
  }
}

/// Song settings of the saved tenant ([error]: loading fails).
class _FakeSongRepository extends SongRepository {
  _FakeSongRepository(super.ref, {this.settings = const SongTenantSettings(), this.error = false});

  final SongTenantSettings settings;
  final bool error;

  @override
  Future<SongTenantSettings> getSongTenantSettings() async {
    if (error) throw Exception('load failed');
    return settings;
  }
}

void main() {
  const a = ExtraField(id: 'a', name: 'A', type: 'text', defaultValue: '');
  const b = ExtraField(id: 'b', name: 'B', type: 'text', defaultValue: '');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saving cleans up with the saved snapshot and skips synced song library', () async {
    late _DelayedExtraFieldsRepository repo;
    final tenant = TestFactories.createTenant(id: 1).copyWith(
      additionalFields: const [a, b],
      songAdditionalFields: const [],
    );
    final container = createTestContainer(
      tenant: tenant,
      overrides: [
        churchesProvider.overrideWith((ref) async => []),
        // Song library of another tenant (song_source_tenant_id = 7).
        songRepositoryForTenantProvider.overrideWith((ref, key) =>
            _FakeSongRepository(ref, settings: const SongTenantSettings(songSourceTenantId: 7))),
        extraFieldsRepositoryWithTenantProvider
            .overrideWith((ref) => repo = _DelayedExtraFieldsRepository(ref)),
      ],
    );
    addTearDown(container.dispose);

    final saving = saveExtraFieldDefinitions(
      container.read,
      container.read(extraFieldsRepositoryWithTenantProvider),
      personFields: const [a, b],
      songFields: const [],
      churchIds: const [],
    );

    await Future<void>.delayed(Duration.zero);
    expect(repo.savedPersonIds, ['a', 'b']);

    repo.gate.complete();
    await saving;

    // Synced library of tenant 7: its songs belong to the source tenant and
    // are not cleaned with this tenant's song fields.
    expect(repo.log, ['save', 'sanitize:player']);
    expect(repo.sanitized['player'], ['a', 'b']);
    expect(repo.songTenantId, isNull);
    expect(
      container.read(currentTenantProvider)?.additionalFields?.map((f) => f.id),
      ['a', 'b'],
    );
  });

  // Closing the edit sheet (X) applies the edits; a legacy text default `false`
  // shows empty and is stored as `false`, not as the string 'false'.
  testWidgets('closing the edit sheet applies the changes', (tester) async {
    late _DelayedExtraFieldsRepository repo;
    const legacy = ExtraField(id: 'c', name: 'C', type: 'text', defaultValue: false);
    final tenant = TestFactories.createTenant(id: 1).copyWith(
      additionalFields: const [legacy],
      songAdditionalFields: const [],
    );
    final container = createTestContainer(
      tenant: tenant,
      overrides: [
        churchesProvider.overrideWith((ref) async => []),
        songRepositoryForTenantProvider.overrideWith((ref, key) => _FakeSongRepository(ref)),
        extraFieldsRepositoryWithTenantProvider
            .overrideWith((ref) => repo = _DelayedExtraFieldsRepository(ref)),
      ],
    );
    addTearDown(container.dispose);

    ExtraField? edited;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async {
                edited = await showExtraFieldSheet(
                  context,
                  ref,
                  target: ExtraFieldTarget.person,
                  fields: () => const [legacy],
                  existing: legacy,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('false'), findsNothing);
    expect(find.text('Übernehmen'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'C'), 'C2');
    await tester.tap(find.byIcon(AppIcons.close));
    await tester.pumpAndSettle();

    expect(edited, isNotNull);
    expect(edited!.name, 'C2');
    expect(edited!.defaultValue, false);

    final saving = saveExtraFieldDefinitions(
      container.read,
      repo,
      personFields: [edited!],
      songFields: const [],
      churchIds: const [],
    );
    repo.gate.complete();
    await saving;

    final saved = repo.savedPersonFields!.single;
    expect(saved.name, 'C2');
    expect(saved.defaultValue, false);
  });

  // Sol review PR #303: if the song settings (song_source_tenant_id) cannot
  // be loaded, the save aborts before any write instead of cleaning up the
  // own song library.
  test('song settings load error aborts before any write', () async {
    late _DelayedExtraFieldsRepository repo;
    final tenant = TestFactories.createTenant(id: 1).copyWith(
      additionalFields: const [a],
      songAdditionalFields: const [],
    );
    final container = createTestContainer(
      tenant: tenant,
      overrides: [
        churchesProvider.overrideWith((ref) async => []),
        songRepositoryForTenantProvider.overrideWith((ref, key) => _FakeSongRepository(ref, error: true)),
        extraFieldsRepositoryWithTenantProvider
            .overrideWith((ref) => repo = _DelayedExtraFieldsRepository(ref)),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      saveExtraFieldDefinitions(
        container.read,
        container.read(extraFieldsRepositoryWithTenantProvider),
        personFields: const [a],
        songFields: const [],
        churchIds: const [],
      ),
      throwsException,
    );

    expect(repo.log, isEmpty);
  });
}
