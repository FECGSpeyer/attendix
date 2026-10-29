import 'dart:io';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/data/repositories/user_registration_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// AUTH package: server-side account flows (attendix-user Edge Function)
/// and Multi-Tenant Security source analysis.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// All supabase query chains (from `.from(` up to the terminating `;`).
  List<String> queries(String source, String table) => RegExp(
        "\\.from\\('$table'\\)[^;]*;",
        dotAll: true,
      ).allMatches(source).map((m) => m.group(0)!).toList();

  group('Multi-Tenant Security - UserRegistrationRepository', () {
    late String source;
    setUpAll(() {
      source = read('lib/data/repositories/user_registration_repository.dart');
    });

    test('extends BaseRepository with TenantAwareRepository', () {
      expect(
        source,
        matches(RegExp(r'extends BaseRepository\s+with TenantAwareRepository')),
      );
    });

    test('all tenantUsers UPDATE/DELETE operations filter by tenantId', () {
      final mutations = queries(source, 'tenantUsers')
          .where((q) => q.contains('.update(') || q.contains('.delete('))
          .toList();
      expect(mutations, isNotEmpty);
      for (final q in mutations) {
        expect(q, contains(".eq('tenantId',"), reason: q);
        expect(q, contains(".eq('userId',"), reason: q);
      }
    });

    test('tenantUsers INSERT always sets the tenantId', () {
      final inserts =
          queries(source, 'tenantUsers').where((q) => q.contains('.insert('));
      expect(inserts, isNotEmpty);
      for (final q in inserts) {
        expect(q, contains("'tenantId':"), reason: q);
      }
    });

    test('player appId update filters by id AND tenantId', () {
      final updates =
          queries(source, 'player').where((q) => q.contains('.update('));
      expect(updates, isNotEmpty);
      for (final q in updates) {
        expect(q, contains(".eq('id',"));
        expect(q, contains(".eq('tenantId', currentTenantId)"));
      }
    });

    test('linked person lookups are tenant scoped', () {
      final lookups = RegExp(r"\.from\(table\)[^;]*;", dotAll: true)
          .allMatches(source)
          .map((m) => m.group(0)!);
      expect(lookups, isNotEmpty);
      for (final q in lookups) {
        expect(q, contains(".eq('tenantId', tenantId)"));
      }
    });

    test('accounts are created by the attendix-user Edge Function', () {
      expect(source, contains("'attendix-user'"));
      expect(source, isNot(contains('auth.signUp(')));
    });
  });

  group('No client-side signUp for other people', () {
    for (final path in [
      'lib/data/services/auth_service.dart',
      'lib/features/people/presentation/pages/person_import_page.dart',
      'lib/features/settings/presentation/pages/settings_page.dart',
      'lib/features/people/presentation/pages/person_detail_page.dart',
      'lib/features/settings/presentation/pages/viewers_page.dart',
      'lib/features/settings/presentation/pages/parents_page.dart',
    ]) {
      test(path, () {
        final source = read(path);
        expect(source, isNot(contains('auth.signUp(')));
        expect(source, isNot(contains('createAccountForPerson')));
        expect(source, isNot(contains('appId: const Uuid().v4()')),
            reason: 'appId must be a real auth user id');
      });
    }
  });

  group('Edge Function payload (Ionic parity)', () {
    test('register body carries role label, roleId and tenantId', () {
      final body = UserRegistrationRepository.buildFunctionBody(
        action: 'register',
        email: 'a@b.de',
        name: 'Anna',
        role: Role.responsible,
        tenantId: 42,
      );
      expect(body, {
        'action': 'register',
        'email': 'a@b.de',
        'name': 'Anna',
        'role': 'Verantwortlicher',
        'roleId': 5,
        'tenantId': 42,
      });
    });

    test('reject body has no role', () {
      final body = UserRegistrationRepository.buildFunctionBody(
        action: 'reject',
        email: 'a@b.de',
        name: 'Anna',
        tenantId: 1,
      );
      expect(body.containsKey('role'), isFalse);
      expect(body.containsKey('roleId'), isFalse);
    });

    test('role texts match Ionic Utils.getRoleText', () {
      expect(UserRegistrationRepository.roleText(Role.admin), 'Admin');
      expect(UserRegistrationRepository.roleText(Role.player), 'Mitglied');
      expect(UserRegistrationRepository.roleText(Role.viewer), 'Beobachter');
      expect(UserRegistrationRepository.roleText(Role.parent), 'Elternteil');
      expect(UserRegistrationRepository.roleText(Role.voiceLeaderHelper),
          'Stimmführer & Helfer');
    });

    test('main group members get RESPONSIBLE, others PLAYER', () {
      expect(
        UserRegistrationRepository.accountRoleFor(instrumentId: 3, mainGroupId: 3),
        Role.responsible,
      );
      expect(
        UserRegistrationRepository.accountRoleFor(instrumentId: 4, mainGroupId: 3),
        Role.player,
      );
      expect(
        UserRegistrationRepository.accountRoleFor(instrumentId: null, mainGroupId: null),
        Role.player,
      );
    });
  });
}
