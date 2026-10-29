// SOL_FIX20: Sol review of 8270c82 – the Zusatzfelder page stayed editable
// while its multi-step save ran, and the value cleanup used the lists as
// changed meanwhile instead of the definitions actually stored.
import 'dart:async';

import 'package:attendix/core/providers/church_providers.dart';
import 'package:attendix/core/providers/files_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/repositories/extra_fields_repository.dart';
import 'package:attendix/features/settings/presentation/pages/extra_fields_page.dart';
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
  final sanitized = <String, List<String>>{};

  @override
  Future<void> saveFields({
    required List<ExtraField> personFields,
    required List<ExtraField> songFields,
  }) async {
    savedPersonIds = personFields.map((f) => f.id).toList();
    log.add('save');
    await gate.future;
  }

  @override
  Future<void> sanitizeValues({
    required String table,
    required List<ExtraField> definitions,
    List<Object>? churchIds,
  }) async {
    sanitized[table] = definitions.map((f) => f.id).toList();
    log.add('sanitize:$table');
  }
}

void main() {
  const a = ExtraField(id: 'a', name: 'A', type: 'text', defaultValue: '');
  const b = ExtraField(id: 'b', name: 'B', type: 'text', defaultValue: '');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('saving blocks edits and cleans up with the saved snapshot', (tester) async {
    late _DelayedExtraFieldsRepository repo;
    final tenant = TestFactories.createTenant(id: 1).copyWith(
      additionalFields: const [a, b],
      songAdditionalFields: const [],
    );
    final container = createTestContainer(
      tenant: tenant,
      overrides: [
        churchesProvider.overrideWith((ref) async => []),
        extraFieldsRepositoryWithTenantProvider
            .overrideWith((ref) => repo = _DelayedExtraFieldsRepository(ref)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ExtraFieldsPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();

    // Ionic loading overlay "Felder werden gespeichert..."
    expect(find.byKey(const ValueKey('extra-fields-saving')), findsOneWidget);
    expect(find.text('Felder werden gespeichert...'), findsOneWidget);
    expect(repo.savedPersonIds, ['a', 'b']);

    // Try to delete field A while the save is running: blocked, no dialog.
    await tester.tap(find.byIcon(Icons.delete_outline).first, warnIfMissed: false);
    // The spinner keeps animating – no pumpAndSettle while saving.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Löschen'), findsNothing);
    expect(find.text('A'), findsOneWidget);

    repo.gate.complete();
    await tester.pumpAndSettle();

    expect(repo.log, ['save', 'sanitize:player', 'sanitize:songs']);
    // The cleanup keeps exactly the definitions that were stored.
    expect(repo.sanitized['player'], ['a', 'b']);
    expect(find.byKey(const ValueKey('extra-fields-saving')), findsNothing);
    expect(
      container.read(currentTenantProvider)?.additionalFields?.map((f) => f.id),
      ['a', 'b'],
    );
  });
}
