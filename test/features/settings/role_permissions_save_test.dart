import 'dart:async';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/debug_providers.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/data/models/role_permission/tenant_role_permission.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/data/repositories/role_permission_repository.dart';
import 'package:attendix/features/settings/presentation/pages/role_permissions_page.dart';
import 'package:attendix/features/settings/presentation/widgets/settings_list.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const auditTenant = Tenant(
  id: 42,
  shortName: 'AUD',
  longName: 'Audit',
  type: 'general',
);

class AuditTenantNotifier extends CurrentTenantNotifier {
  AuditTenantNotifier(super.ref) {
    state = auditTenant;
  }
}

class DelayedPermissions extends RolePermissionRepository {
  DelayedPermissions(super.ref) {
    bindTenantId(42);
  }
  final gate = Completer<void>();
  final sent = <TenantRolePermission>[];
  final filesSharedWrites = <bool>[];
  TenantRolePermission stored = const TenantRolePermission(
    id: 7,
    tenantId: 42,
    role: 4,
  );

  @override
  Future<void> updateFilesShared(bool value) async {
    filesSharedWrites.add(value);
  }

  @override
  Future<List<TenantRolePermission>> getPermissions() async => [stored];

  @override
  Future<TenantRolePermission> updatePermission(
    TenantRolePermission permission,
  ) async {
    sent.add(permission);
    await gate.future;
    stored = permission;
    return stored;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The real stateful page and real notifier are exercised; only its repository is delayed.
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'edits during save stay unsaved and are persisted by the next save ($platform)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(850, 1150));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final auth = GoTrueClient(autoRefreshToken: false);
        addTearDown(auth.dispose);
        late DelayedPermissions repo;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              supabaseAuthProvider.overrideWithValue(auth),
              currentAuthUserIdProvider.overrideWithValue('audit-user-a'),
              currentTenantProvider.overrideWith(
                (ref) => AuditTenantNotifier(ref),
              ),
              effectiveRoleProvider.overrideWithValue(Role.admin),
              rolePermissionRepositoryWithTenantProvider.overrideWith(
                (ref) => repo = DelayedPermissions(ref),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('de'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.forPlatform(
                Brightness.light,
                platform,
              ).copyWith(splashFactory: NoSplash.splashFactory),
              home: const RolePermissionsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = tester.element(find.byType(RolePermissionsPage)).l10n;
        await tester.tap(find.text(l10n.rolesHelper));
        await tester.pumpAndSettle();
        Finder toggle(String title) => find.byWidgetPredicate(
          (w) => w is IonToggleItem && w.title == title,
        );
        await tester.tap(find.text(l10n.rolePermCreateAttendance));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<IonToggleItem>(toggle(l10n.rolePermCreateAttendance))
              .value,
          false,
        );
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        expect(repo.sent, hasLength(1));
        expect(repo.sent.single.checklistView, false);
        expect(repo.gate.isCompleted, false);
        // This is a real tap on an enabled switch while the actual save is pending.
        await tester.tap(find.text(l10n.rolePermSeeChecklist));
        await tester.pump();
        expect(
          tester.widget<IonToggleItem>(toggle(l10n.rolePermSeeChecklist)).value,
          true,
        );
        await tester.tap(find.text(l10n.rolePermFilesForAll));
        await tester.pump();
        expect(
          tester.widget<IonToggleItem>(toggle(l10n.rolePermFilesForAll)).value,
          true,
        );
        repo.gate.complete();
        await tester.pumpAndSettle();
        expect(
          repo.stored.checklistView,
          false,
          reason: 'the wire snapshot omitted the second edit',
        );
        expect(
          tester.widget<IonToggleItem>(toggle(l10n.rolePermSeeChecklist)).value,
          true,
        );
        final pagePop = tester.widget<PopScope>(
          find.byWidgetPredicate((w) => w is PopScope).first,
        );
        expect(
          pagePop.canPop,
          false,
          reason: 'an edit made after the submitted snapshot remains unsaved',
        );
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(repo.sent, hasLength(2));
        expect(repo.stored.checklistView, true);
        expect(repo.filesSharedWrites, [true]);
        expect(
          tester
              .widget<PopScope>(
                find.byWidgetPredicate((w) => w is PopScope).first,
              )
              .canPop,
          true,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
