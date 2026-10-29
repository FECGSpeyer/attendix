import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/role_permission_providers.dart';
import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:flutter_test/flutter_test.dart';

/// ASTRA_FILES: Ionic OverviewPage.hasFilesFolder → db.canAccessFiles(att.tenantId)
/// and openFilesFolder → /open-file (switch instance first, then open folder).
void main() {
  Tenant tenant(int id, Role? role, {bool filesShared = false}) => Tenant(
        id: id,
        shortName: 'T$id',
        longName: 'Tenant $id',
        role: role?.value,
        filesShared: filesShared,
      );

  group('canAccessFilesInTenant (Ionic canAccessFiles(tenantId))', () {
    test('current tenant uses the current-tenant permission', () {
      final others = [tenant(1, Role.player)];
      expect(
        canAccessFilesInTenant(
            tenantId: 1, currentTenantId: 1, currentTenantAccess: true, userTenants: others),
        isTrue,
      );
      expect(
        canAccessFilesInTenant(
            tenantId: 1, currentTenantId: 1, currentTenantAccess: false, userTenants: others),
        isFalse,
      );
    });

    test('other tenant without files_shared: admin/responsible/helper/voice leader helper', () {
      for (final role in Role.values) {
        final expected = role == Role.admin ||
            role == Role.responsible ||
            role == Role.helper ||
            role == Role.voiceLeaderHelper;
        expect(
          canAccessFilesInTenant(
            tenantId: 2,
            currentTenantId: 1,
            currentTenantAccess: false,
            userTenants: [tenant(2, role)],
          ),
          expected,
          reason: role.name,
        );
      }
    });

    test('other tenant with files_shared: everyone except applicant and none', () {
      for (final role in Role.values) {
        final expected = role != Role.applicant && role != Role.none;
        expect(
          canAccessFilesInTenant(
            tenantId: 2,
            currentTenantId: 1,
            currentTenantAccess: true,
            userTenants: [tenant(2, role, filesShared: true)],
          ),
          expected,
          reason: role.name,
        );
      }
    });

    test('no tenantUsers row or no role → no access', () {
      expect(
        canAccessFilesInTenant(
            tenantId: 3, currentTenantId: 1, currentTenantAccess: true, userTenants: [tenant(2, Role.admin)]),
        isFalse,
      );
      expect(
        canAccessFilesInTenant(
            tenantId: 2, currentTenantId: 1, currentTenantAccess: true, userTenants: [tenant(2, null)]),
        isFalse,
      );
    });
  });

  group('source: overview opens other-tenant files via the tenant switch', () {
    final overview = File(
            'lib/features/self_service/presentation/pages/self_service_overview_page.dart')
        .readAsStringSync();
    final actions = File(
            'lib/features/self_service/presentation/widgets/self_service_event_actions.dart')
        .readAsStringSync();
    final openFile =
        File('lib/features/public_links/presentation/pages/open_file_page.dart').readAsStringSync();

    test('overview checks the permission in the Termin tenant', () {
      expect(overview, contains('canAccessFilesInTenant('));
      expect(overview, contains('tenantId: att.tenantId'));
      expect(overview, contains('currentTenantId: currentTenantId'));
      expect(overview, isNot(contains('canAccessFiles && att.tenantId == currentTenantId')));
      expect(overview, contains('actions.openFilesFolder(context, att)'));
    });

    test('other tenant goes through /open-file (switch), own tenant pushes files', () {
      expect(actions, contains("Uri(path: '/open-file'"));
      expect(actions, contains("'folder': '1'"));
      expect(actions, contains('switchToTenantId: otherTenant ? att.tenantId : null'));
      // All actions use the guarded helper, never the raw route with filesFolder.
      expect(actions, isNot(contains('openFilesFolderRoute(context, att.filesFolder!)')));
    });

    test('/open-file switches the tenant before navigating to the files', () {
      final switchAt = openFile.indexOf('currentTenantProvider.notifier).setTenant(target)');
      final accessAt = openFile.indexOf('ref.read(canAccessFilesProvider)');
      final navAt = openFile.indexOf("context.go('/settings/files?");
      expect(switchAt, greaterThan(0));
      expect(accessAt, greaterThan(switchAt));
      expect(navAt, greaterThan(accessAt));
      expect(openFile, contains('context.l10n.filesNoAccess'));
      expect(openFile, contains('context.l10n.openFileNoTenantAccess'));
    });
  });
}
