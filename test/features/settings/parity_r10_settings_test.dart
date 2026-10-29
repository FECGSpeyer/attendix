import 'dart:io';

import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/features/settings/presentation/pages/general_settings_page.dart';
import 'package:attendix/features/settings/presentation/pages/link_persons_page.dart';
import 'package:attendix/features/voice_leader/data/providers/voice_leader_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// PARITY_R10: final parity sweep of the settings / auth lane.
void main() {
  group('general settings: registration fields (Ionic selectedRegisterFields)', () {
    test('stored fields are kept', () {
      expect(initialRegistrationFields(['firstName', 'lastName', 'group', 'phone']),
          ['firstName', 'lastName', 'group', 'phone']);
    });

    test('null or empty → only the required fields', () {
      expect(initialRegistrationFields(null), ['firstName', 'lastName', 'group']);
      expect(initialRegistrationFields(const []), ['firstName', 'lastName', 'group']);
    });

    test('result is modifiable', () {
      final fields = initialRegistrationFields(null)..add('phone');
      expect(fields, contains('phone'));
    });
  });

  group('link persons: ignore key (Ionic [a.id, b.id].sort())', () {
    test('ids are sorted as strings like JS Array.sort()', () {
      expect(linkGroupKey(9, 10), '10-9');
      expect(linkGroupKey(10, 9), '10-9');
      expect(linkGroupKey(3, 2), '2-3');
    });
  });

  group('voice leader (Ionic voice-leader.page)', () {
    test('absence title: typeInfo, else type name unless hidden', () {
      expect(
        voiceLeaderAbsenceTitle({
          'typeInfo': 'Konzert',
          'attType': {'name': 'Probe', 'hide_name': false},
        }),
        'Konzert',
      );
      expect(
        voiceLeaderAbsenceTitle({
          'typeInfo': '',
          'attType': {'name': 'Probe', 'hide_name': false},
        }),
        'Probe',
      );
      expect(
        voiceLeaderAbsenceTitle({
          'typeInfo': null,
          'attType': {'name': 'Probe', 'hide_name': true},
        }),
        '',
      );
      expect(voiceLeaderAbsenceTitle({}), '');
    });

    test('members sorted by last name, then first name (leaders not first)', () {
      VoiceGroupMember m(String first, String last, {bool leader = false}) =>
          VoiceGroupMember(
            person: Person(firstName: first, lastName: last, isLeader: leader),
            upcomingAbsences: const [],
          );
      final list = [
        m('Zoe', 'Bauer', leader: true),
        m('Anna', 'Bauer'),
        m('Max', 'adler'),
      ]..sort(compareVoiceGroupMembers);
      expect(list.map((e) => e.person.firstName), ['Max', 'Anna', 'Zoe']);
    });

    test('query joins the attendance type for the title, tenant-filtered', () {
      final source = File('lib/data/repositories/attendance_repository.dart').readAsStringSync();
      final start = source.indexOf('getUpcomingAbsencesForPersons(');
      final body = source.substring(start, source.indexOf('handleError', start));
      expect(body, contains('attType:type_id(name, hide_name)'));
      expect(body, contains(".eq('attendance.tenantId', currentTenantId)"));
    });
  });

  group('instances sheet: delete instance (Ionic db.deleteInstance)', () {
    final source = File(
      'lib/features/tenant_selection/presentation/pages/tenant_selection_page.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _deleteInstance(');
    final body = source.substring(start, source.indexOf('Future<void> _logout(', start));

    test('closes the sheet and opens the next instance after deleting the current one', () {
      expect(body, contains('sheetNavigator?.pop()'));
      expect(body, contains("if (wasCurrent) router.go('/tenants')"));
    });

    test('uses the Ionic toasts', () {
      expect(body, contains('dbInstanceDeleted'));
      expect(body, contains('dbDeleteInstanceFailed'));
    });
  });
}
