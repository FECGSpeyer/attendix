import 'package:attendix/features/tenant_selection/tenant_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildNewTenantPayload', () {
    test('sets Ionic register defaults', () {
      final payload = buildNewTenantPayload(
        shortName: 'SO',
        longName: 'Stadtorchester',
        type: 'orchestra',
      );
      expect(payload['withExcuses'], isTrue);
      expect(payload['betaProgram'], isTrue);
      expect(payload['maintainTeachers'], isFalse);
      expect(payload['showHolidays'], isFalse);
      expect(payload['timezone'], 'Europe/Berlin');
      expect(payload['type'], 'orchestra');
    });
  });

  test('main group payload has no isSection flag', () {
    final payload = buildMainGroupPayload(tenantId: 7, name: 'Dirigenten');
    expect(payload['maingroup'], isTrue);
    expect(payload['tenantId'], 7);
    expect(payload.containsKey('isSection'), isFalse);
  });

  group('buildDefaultAttendanceTypes', () {
    test('orchestra gets Probe, Vortrag and Sonstiges', () {
      final types = buildDefaultAttendanceTypes(tenantId: 3, type: 'orchestra');
      expect(types.map((t) => t['name']), ['Probe', 'Vortrag', 'Sonstiges']);
      expect(types.every((t) => t['tenant_id'] == 3), isTrue);
      expect(types.every((t) => t['include_in_average'] == true), isTrue);
    });

    test('general gets Treffen and Sonstiges', () {
      final types = buildDefaultAttendanceTypes(tenantId: 3, type: 'general');
      expect(types.map((t) => t['name']), ['Treffen', 'Sonstiges']);
    });
  });
}
