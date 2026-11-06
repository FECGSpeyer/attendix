import 'dart:async';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/files_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/data/models/storage/storage_entry.dart';
import 'package:attendix/data/repositories/files_repository.dart';
import 'package:attendix/features/settings/presentation/pages/files_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../mocks/supabase_mocks.dart';

final _auth = () {
  final auth = MockGoTrueClient();
  when(() => auth.currentUser).thenReturn(null);
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  return auth;
}();

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'SO');
  }

  void switchTo(int id) => state = TestFactories.createTenant(id: id, shortName: 'G$id');
}

/// Group 7 answers at once; group 8's listing waits for [_slowB] (a late
/// result after a switch back must not show up).
Completer<void> _slowB = Completer<void>();

class _FakeFilesRepo extends FilesRepository {
  _FakeFilesRepo(super.ref, this.tenant) {
    bindTenantId(tenant);
  }

  final int tenant;

  @override
  Future<List<StorageEntry>> listEntries([String relativePath = '']) async {
    if (tenant == 8) await _slowB.future;
    return [
      StorageEntry(name: 'Ordner $tenant', path: 'Ordner $tenant', isFolder: true),
      StorageEntry(
        name: 'Datei-$tenant.pdf',
        path: 'Datei-$tenant.pdf',
        isFolder: false,
        size: 240000,
        updatedAt: DateTime(2026, 9, 12),
      ),
    ];
  }

  @override
  Future<int> getUsedBytes() async => 1200000;
}

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAuthProvider.overrideWithValue(_auth),
        currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
        redesignEnabledProvider.overrideWithValue(true),
        canAccessFilesProvider.overrideWithValue(true),
        canEditFilesProvider.overrideWithValue(true),
        isRoleLoadingProvider.overrideWithValue(false),
        filesRepositoryWithTenantProvider.overrideWith(
          (ref) => _FakeFilesRepo(ref, ref.watch(currentTenantIdProvider) ?? 0),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.light),
        home: const FilesPage(),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return ProviderScope.containerOf(tester.element(find.byType(FilesPage)));
}

/// REDESIGN: Dateiablage in the Beta (same page, Beta look).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _slowB = Completer<void>();
  });

  testWidgets('Beta: Ordner als Großtitel, Liste, ••• mit Sortieren, + für Hochladen', (tester) async {
    await _pump(tester);

    expect(find.text('Dateien'), findsOneWidget);
    expect(find.text('Ordner 7'), findsOneWidget);
    expect(find.text('Datei-7.pdf'), findsOneWidget);
    expect(find.byKey(const Key('rd-files-add')), findsOneWidget);
    expect(find.byKey(const Key('rd-files-search')), findsOneWidget);

    await tester.tap(find.byKey(const Key('rd-files-more')));
    await tester.pumpAndSettle();
    expect(find.text('Sortierung'), findsWidgets);
  });

  testWidgets('Gruppenwechsel: alte Einträge verschwinden, späte Antwort von B nach Rückwechsel wird verworfen', (
    tester,
  ) async {
    final container = await _pump(tester);
    final tenant = container.read(currentTenantProvider.notifier) as _TenantNotifier;

    tenant.switchTo(8);
    await tester.pump();
    await tester.pump();
    expect(find.text('Datei-7.pdf'), findsNothing);

    tenant.switchTo(7);
    await tester.pump();
    await tester.pump();
    _slowB.complete();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Datei-7.pdf'), findsOneWidget);
    expect(find.text('Datei-8.pdf'), findsNothing);
  });
}
