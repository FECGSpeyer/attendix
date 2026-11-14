import 'package:attendix/features/redesign/data/rd_create_logic.dart';
import 'package:attendix/features/redesign/presentation/widgets/event/rd_event_now.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a later Beginn moves the Ende along with the former duration', () {
    expect(rdPickedTimes(start: '19:00', end: '21:00', pickedStart: true, value: '22:00'),
        (start: '22:00', end: '23:59'));
    expect(rdPickedTimes(start: '19:00', end: '21:00', pickedStart: true, value: '20:30'),
        (start: '20:30', end: '21:00'));
    expect(rdPickedTimes(start: '10:00', end: '11:30', pickedStart: true, value: '12:00'),
        (start: '12:00', end: '13:30'));
    // Already broken (22:00–21:00): one hour.
    expect(rdPickedTimes(start: '22:00', end: '21:00', pickedStart: true, value: '21:30'),
        (start: '21:30', end: '22:30'));
  });

  test('an Ende before the Beginn is refused', () {
    expect(rdPickedTimes(start: '19:00', end: '21:00', pickedStart: false, value: '18:00'), isNull);
    expect(rdPickedTimes(start: '19:00', end: '21:00', pickedStart: false, value: '19:00'),
        (start: '19:00', end: '19:00'));
    expect(rdPickedTimes(start: null, end: null, pickedStart: false, value: '08:00'), (start: null, end: '08:00'));
    expect(rdEndBeforeStart('22:00', '21:00'), isTrue);
  });
  test('rdEndAfter keeps a valid span, else one hour, capped at 23:59', () {
    expect(rdEndAfter('20:00', from: '17:00', to: '19:00'), '22:00');
    expect(rdEndAfter('20:00', from: '17:00', to: null), '21:00');
    expect(rdEndAfter('23:30', from: '10:00', to: '12:00'), '23:59');
  });

  test('an Ablauf that began at the old Beginn moves along, any other stays', () {
    final plan = {
      'time': '19:00',
      'end': '2026-11-30T19:40',
      'title': 'Probe',
      'fields': [
        {'id': 'a', 'name': 'Einsingen', 'time': '20'},
        {'id': 'b', 'name': 'Runde 1', 'time': '20'},
      ],
    };
    final moved = rdPlanMovedWithStart(plan, oldStart: '19:00:00', newStart: '22:00');
    expect(moved!['time'], '22:00');
    expect((moved['end'] as String).endsWith('T22:40'), isTrue);
    expect(moved['title'], 'Probe');
    expect(moved['fields'], plan['fields']);
    // Set on purpose before the Termin: stays.
    expect(rdPlanMovedWithStart({...plan, 'time': '18:30'}, oldStart: '19:00', newStart: '22:00'), isNull);
    // Nothing to move.
    expect(rdPlanMovedWithStart(plan, oldStart: '19:00', newStart: '19:00'), isNull);
    expect(rdPlanMovedWithStart(plan, oldStart: null, newStart: '22:00'), isNull);
    expect(rdPlanMovedWithStart(null, oldStart: '19:00', newStart: '22:00'), isNull);
    expect(rdPlanMovedWithStart({'time': '19:00', 'fields': []}, oldStart: '19:00', newStart: '22:00'), isNull);
  });
}
