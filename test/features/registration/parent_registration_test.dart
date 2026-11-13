import 'package:attendix/core/constants/enums.dart';
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
      // Never the parent's own person (profile sync, login).
      expect(row.containsKey('appId') && row['appId'] == null, isTrue);
      expect(row['pending'], true);
      expect(row['firstName'], 'Max');
      expect(row['instrument'], 7);
      expect(row['birthday'], '2015-03-14');
      final fields = row['additional_fields'] as Map<String, dynamic>;
      expect(fields['church'], 'x');
      final parent = ParentRegistration.fromAdditionalFields(fields)!;
      expect(parent.fullName, 'Anna Muster');
      expect(parent.email, 'anna@mail.de');
      expect(parent.appId, 'parent-uid');
      // The shared form fields stay untouched for the next child.
      expect(form.additionalFields.containsKey(kParentRegistrationKey), isFalse);
      expect(withoutParentRegistration(fields).containsKey(kParentRegistrationKey), isFalse);
    });

    test('approval fields: parent_id set, account, e-mail and marker removed', () {
      final fields = {
        'church': 'x',
        kParentRegistrationKey: {'appId': 'p', 'email': 'a@b.de', 'firstName': 'A', 'lastName': 'B'},
      };
      final update = childApprovalFields(9, fields);
      expect(update['parent_id'], 9);
      expect(update.containsKey('appId') && update['appId'] == null, isTrue);
      expect(update['email'], isNull);
      expect(update['additional_fields'], {'church': 'x'});
    });

    test('Q3: an account with its own role registers no child, applicant/parent may', () {
      for (final r in [Role.player, Role.helper, Role.admin, Role.responsible, Role.viewer, Role.voiceLeader]) {
        expect(hasOwnMemberRole(r), isTrue, reason: r.name);
      }
      for (final r in [null, Role.none, Role.applicant, Role.parent]) {
        expect(hasOwnMemberRole(r), isFalse, reason: '$r');
      }
    });
  });
}
