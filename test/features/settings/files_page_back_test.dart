import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/files_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/data/models/storage/storage_entry.dart';
import 'package:attendix/data/repositories/files_repository.dart';
import 'package:attendix/features/settings/presentation/pages/files_page.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
}

class _TreeFilesRepo extends FilesRepository {
  _TreeFilesRepo(super.ref) {
    bindTenantId(7);
  }

  @override
  Future<List<StorageEntry>> listEntries([String relativePath = '']) async {
    return switch (relativePath) {
      '' => const [
          StorageEntry(name: 'Ordner A', path: 'Ordner A', isFolder: true),
          StorageEntry(name: 'Root.pdf', path: 'Root.pdf', isFolder: false),
        ],
      'Ordner A' => const [
          StorageEntry(name: 'Unterordner B', path: 'Ordner A/Unterordner B', isFolder: true),
          StorageEntry(name: 'DateiA.pdf', path: 'Ordner A/DateiA.pdf', isFolder: false),
        ],
      'Ordner A/Unterordner B' => const [
          StorageEntry(name: 'DateiB.pdf', path: 'Ordner A/Unterordner B/DateiB.pdf', isFolder: false),
        ],
      _ => const [],
    };
  }

  @override
  Future<int> getUsedBytes() async => 1024;
}

Future<GoRouter> _pumpClassicFiles(
  WidgetTester tester, {
  required TargetPlatform platform,
  bool canAccess = true,
  String? initialPath,
}) async {
  SharedPreferences.setMockInitialValues({});
  final previousIcons = AppIcons.ionic;
  AppIcons.ionic = true;
  addTearDown(() => AppIcons.ionic = previousIcons);

  final router = GoRouter(
    initialLocation: '/settings/files',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('SETTINGS_ROUTE')),
        routes: [
          GoRoute(
            path: 'files',
            builder: (_, __) => FilesPage(initialPath: initialPath),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAuthProvider.overrideWithValue(_auth),
        currentTenantProvider.overrideWith((ref) => _TenantNotifier(ref)),
        redesignEnabledProvider.overrideWithValue(false),
        canAccessFilesProvider.overrideWithValue(canAccess),
        canEditFilesProvider.overrideWithValue(canAccess),
        isRoleLoadingProvider.overrideWithValue(false),
        filesRepositoryWithTenantProvider.overrideWith((ref) => _TreeFilesRepo(ref)),
      ],
      child: MaterialApp.router(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.forPlatform(Brightness.light, platform),
        routerConfig: router,
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return router;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

PopScope<dynamic> _popScope(WidgetTester tester) => tester.widget<PopScope<dynamic>>(
  find.descendant(
    of: find.byType(FilesPage),
    matching: find.byWidgetPredicate((w) => w is PopScope),
  ),
);

void main() {
  for (final platform in const [TargetPlatform.iOS, TargetPlatform.android]) {
    group('FilesPage classic back (${platform.name})', () {
      testWidgets('back in subfolder walks up one level before leaving to /settings', (tester) async {
        await _pumpClassicFiles(tester, platform: platform);

        expect(find.text('Ordner A'), findsOneWidget);
        expect(_popScope(tester).canPop, isTrue);

        await tester.tap(find.text('Ordner A'));
        await _settle(tester);
        expect(find.text('Unterordner B'), findsOneWidget);
        expect(_popScope(tester).canPop, isFalse);

        await tester.tap(find.text('Unterordner B'));
        await _settle(tester);
        expect(find.text('DateiB.pdf'), findsOneWidget);
        expect(_popScope(tester).canPop, isFalse);

        // First back: Unterordner B -> Ordner A
        await tester.tap(find.byIcon(AppIcons.arrowBack));
        await _settle(tester);
        expect(find.text('Unterordner B'), findsOneWidget);
        expect(find.text('SETTINGS_ROUTE'), findsNothing);
        expect(_popScope(tester).canPop, isFalse);

        // Second back: Ordner A -> Root
        await tester.tap(find.byIcon(AppIcons.arrowBack));
        await _settle(tester);
        expect(find.text('Ordner A'), findsOneWidget);
        expect(find.text('SETTINGS_ROUTE'), findsNothing);
        expect(_popScope(tester).canPop, isTrue);

        // Third back (in root): leaves page to /settings
        await tester.tap(find.byIcon(AppIcons.arrowBack));
        await _settle(tester);
        expect(find.text('SETTINGS_ROUTE'), findsOneWidget);
      });

      testWidgets('system back exits selection mode first without leaving folder', (tester) async {
        await _pumpClassicFiles(tester, platform: platform);

        await tester.tap(find.text('Ordner A'));
        await _settle(tester);

        // Start selection mode via toolbar checkmark icon.
        await tester.tap(find.byIcon(AppIcons.checkCircleOutline));
        await _settle(tester);
        expect(find.byType(Checkbox), findsWidgets);
        expect(_popScope(tester).canPop, isFalse);

        // Simulate system back (PopScope.onPopInvokedWithResult when didPop is false).
        final popScope = _popScope(tester);
        popScope.onPopInvokedWithResult?.call(false, null);
        await _settle(tester);

        // Exited selection mode, still inside Ordner A.
        expect(find.byType(Checkbox), findsNothing);
        expect(find.text('Unterordner B'), findsOneWidget);
        expect(find.text('SETTINGS_ROUTE'), findsNothing);
      });

      testWidgets('deep link without access pops directly to /settings', (tester) async {
        await _pumpClassicFiles(
          tester,
          platform: platform,
          canAccess: false,
          initialPath: 'Ordner A/Unterordner B',
        );

        expect(_popScope(tester).canPop, isTrue);

        await tester.tap(find.byIcon(AppIcons.arrowBack));
        await _settle(tester);
        expect(find.text('SETTINGS_ROUTE'), findsOneWidget);
      });
    });
  }
}
