import 'dart:io';

import 'package:attendix/core/utils/parent_registration.dart';
import 'package:attendix/features/registration/data/providers/registration_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Parent registration ("Mein Kind")', () {
    test('child row: child data, pending, parent account + marker, tenant set', () {
      final form = RegistrationFormData(firstName: 'Anna', lastName: 'Muster', phone: '0171 123')
        ..additionalFields['church'] = 'x';
      final child = ChildRegistrationData(
          firstName: 'Max', lastName: 'Muster', groupId: 7, birthDate: DateTime(2015, 3, 14));
      final row = buildChildRegistrationPlayerData(
        tenantId: 42,
        parentAppId: 'parent-uid',
        formData: form,
        child: child,
        parentEmail: 'anna@mail.de',
        hasBirthDate: true,
        todayIso: '2026-11-10T00:00:00.000Z',
      );

      expect(row['tenantId'], 42);
      expect(row['appId'], 'parent-uid');
      expect(row['pending'], true);
      expect(row['firstName'], 'Max');
      expect(row['instrument'], 7);
      expect(row['birthday'], '2015-03-14');
      final fields = row['additional_fields'] as Map<String, dynamic>;
      expect(fields['church'], 'x');
      final parent = ParentRegistration.fromAdditionalFields(fields)!;
      expect(parent.fullName, 'Anna Muster');
      expect(parent.email, 'anna@mail.de');
      // The shared form fields stay untouched for the next child.
      expect(form.additionalFields.containsKey(kParentRegistrationKey), isFalse);
      expect(withoutParentRegistration(fields).containsKey(kParentRegistrationKey), isFalse);
    });

    test('approval links the child with id AND tenantId filter', () {
      // Source check like the other repository security tests.
      final src = File('lib/data/repositories/player_repository.dart').readAsStringSync();
      final link = src.substring(src.indexOf('Future<void> linkChildToParent('));
      final body = link.substring(0, link.indexOf('\n  }\n'));
      expect(body, contains(".eq('id', playerId)"));
      expect(body, contains(".eq('tenantId', currentTenantId)"));
    });
  });
}
