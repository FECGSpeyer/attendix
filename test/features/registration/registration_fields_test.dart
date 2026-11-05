import 'package:attendix/data/models/tenant/tenant.dart';
import 'package:attendix/features/registration/data/providers/registration_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Ionic tenant-register: fields in registration_fields order, each with its
  // defaultValue (church none), stored in additional_fields even untouched.
  test('registration fields keep Ionic order and defaults', () {
    const fields = [
      ExtraField(id: 'a', name: 'A', type: 'select', defaultValue: 'x', options: ['x', 'y']),
      ExtraField(id: 'b', name: 'B', type: 'boolean', defaultValue: false),
      ExtraField(id: 'bfecg_church', name: 'Gemeinde', type: 'bfecg_church', defaultValue: 'c'),
      ExtraField(id: 'd', name: 'D', type: 'text'),
    ];
    const order = ['d', 'bfecg_church', 'a', 'missing', 'b'];

    expect(orderedRegistrationFields(order, fields).map((f) => f.id), [
      'd',
      'bfecg_church',
      'a',
      'b',
    ]);
    expect(registrationFieldDefaults(order, fields), {'a': 'x', 'b': false});
  });
}
