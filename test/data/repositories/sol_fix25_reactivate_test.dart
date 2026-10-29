import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SOL_FIX25 item 3: reactivating a person that kept its account link
/// (transferred to another tenant: archived here with `appId` and the
/// `tenantUsers` row) must not abort as a duplicate of itself before `left`
/// is reset.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// Body of a method: from its signature up to the next method doc comment.
  String body(String source, String name) {
    final start = source.indexOf(RegExp('(Future<[^>]*>+\\??|void|bool) _?$name\\('));
    expect(start, isNot(-1), reason: 'method $name not found');
    final next = source.indexOf('\n  ///', start + 1);
    return source.substring(start, next == -1 ? source.length : next);
  }

  group('Multi-Tenant Security - SOL_FIX25 reactivation', () {
    late String player;
    late String registration;
    setUpAll(() {
      player = read('lib/data/repositories/player_repository.dart');
      registration = read('lib/data/repositories/user_registration_repository.dart');
    });

    test('reactivatePlayer reuses an existing link before registering again', () {
      final b = body(player, 'reactivatePlayer');
      final link = b.indexOf('_existingAccountLink(player)');
      final register = b.indexOf('createPlayerAccount(');
      expect(link, isNot(-1));
      expect(register, greaterThan(link));
      expect(b, contains('if (linked == null)'),
          reason: 'registration only without a usable link');
      // `left` is still reset (tenant-scoped) afterwards.
      expect(b, contains("'left': null"));
      expect(b.indexOf("'left': null"), greaterThan(register));
      expect(b, contains(".eq('id', player.id!)"));
      expect(b, contains(".eq('tenantId', currentTenantId)"));
      expect(b, contains('addToUpcomingAttendances(person)'));
    });

    test('_existingAccountLink checks the access in the current tenant only', () {
      final b = body(player, 'existingAccountLink');
      expect(b, contains(".from('tenantUsers')"));
      expect(b, contains(".eq('tenantId', currentTenantId)"));
      expect(b, contains(".eq('userId', appId)"));
      expect(b, contains('appId.isEmpty) return null'));
    });

    test('createPlayerAccount passes the person to the duplicate check', () {
      final b = body(registration, 'createPlayerAccount');
      expect(b, contains('personId: person.id'));
      // Membership check stays before any registration side effect.
      expect(b.indexOf(".eq('tenantId', currentTenantId)"),
          lessThan(b.indexOf('await registerUser(')));
    });

    test('registerUser forwards personId to getAppIdByEmail', () {
      final b = body(registration, 'registerUser');
      expect(b, contains('personId: personId'));
    });

    test('getAppIdByEmail: the same person is reused, others stay duplicates', () {
      final b = body(registration, 'getAppIdByEmail');
      final same = b.indexOf("['id'] == personId");
      final reuse = b.indexOf('return (userId, true);', same);
      final duplicate = b.indexOf('dbUserAlreadyInTenantAs');
      expect(same, isNot(-1));
      expect(reuse, greaterThan(same));
      expect(duplicate, greaterThan(reuse),
          reason: 'the duplicate error only fires for another person');
      // The linked lookup stays tenant-scoped.
      expect(b, contains(".eq('tenantId', tenantId)"));
      expect(b, contains(".eq('appId', userId)"));
      expect(b, contains("'id, firstName, lastName'"));
    });
  });
}
