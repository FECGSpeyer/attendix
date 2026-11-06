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

import '../../factories/test_factories.dart';

class _TenantNotifier extends CurrentTenantNotifier {
  _TenantNotifier(super.ref) {
    state = TestFactories.createTenant(id: 7, shortName: 'SO');
  }
}

class _FakeFilesRepo extends FilesRepository {
  _FakeFilesRepo(super.ref) {
    bindTenantId(7);
  }

  @override
  Future<List<StorageEntry>> listEntries([String relativePath = '']) async => [
    const StorageEntry(name: 'Protokolle', path: 'Protokolle', isFolder: true),
    StorageEntry(
      name: 'Satzung.pdf',
      path: 'Satzung.pdf',
      isFolder: false,
      size: 240000,
      updatedAt: DateTime(2026, 9, 12),
    ),
  ];

  @override
  Future<int> getUsedBytes() async => 1200000;
}

/// REDESIGN: Dateiablage in the Beta (same page, Beta look).
void main() {
  testWidgets('Beta: Ordner als Großtitel, Liste, ••• mit Sortieren, + für Hochladen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
          redesignEnabledProvider.overrideWithValue(true),
          canAccessFilesProvider.overrideWithValue(true),
          canEditFilesProvider.overrideWithValue(true),
          isRoleLoadingProvider.overrideWithValue(false),
          filesRepositoryWithTenantProvider.overrideWith((ref) => _FakeFilesRepo(ref)),
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

    expect(find.text('Dateien'), findsOneWidget);
    expect(find.text('Protokolle'), findsOneWidget);
    expect(find.text('Satzung.pdf'), findsOneWidget);
    expect(find.byKey(const Key('rd-files-add')), findsOneWidget);
    expect(find.byKey(const Key('rd-files-search')), findsOneWidget);

    await tester.tap(find.byKey(const Key('rd-files-more')));
    await tester.pumpAndSettle();
    expect(find.text('Sortierung'), findsWidgets);
  });
}
