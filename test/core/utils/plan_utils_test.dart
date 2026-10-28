import 'package:attendix/core/providers/plan_providers.dart';
import 'package:attendix/core/utils/plan_utils.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:flutter_test/flutter_test.dart';

PlanField f(String id, String time, {String? groupId, bool isGroup = false}) =>
    PlanField(id: id, name: id, time: time, groupId: groupId, isGroup: isGroup);

List<String> ids(List<PlanField> fields) => fields.map((e) => e.id).toList();

void main() {
  group('PlanField / Plan json (Ionic format)', () {
    test('reads numeric times and keeps block keys', () {
      final plan = Plan.fromJson({
        'time': '2026-10-28T10:00',
        'end': '2026-10-28T11:00',
        'title': 'Gottesdienst',
        'fields': [
          {'id': 'grpFld-1', 'name': 'Block', 'time': 0, 'isGroup': true},
          {'id': 'a', 'name': 'A', 'time': '15', 'groupId': 'grpFld-1', 'info': 'Lied'},
          {'id': 'noteFld x', 'name': 'Notiz', 'time': '0'},
        ],
      });
      expect(plan.fields.first.time, '0');
      expect(plan.fields.first.isGroup, isTrue);
      expect(plan.fields[1].groupId, 'grpFld-1');
      expect(plan.fields[1].info, 'Lied');
      expect(PlanUtils.isNote(plan.fields[2]), isTrue);

      final json = plan.fields[1].toJson();
      expect(json['groupId'], 'grpFld-1');
      expect(json.containsKey('isNote'), isFalse);
    });
  });

  group('Programmblöcke', () {
    test('normalizeGroups drops dangling groupIds and zeroes heads', () {
      final fields = [
        f('h', '10', isGroup: true),
        f('a', '5', groupId: 'h'),
        f('x', '5'),
        f('b', '5', groupId: 'h'),
      ];
      final result = PlanUtils.normalizeGroups(fields);
      expect(result.first.time, '0');
      expect(result[1].groupId, 'h');
      expect(result[3].groupId, isNull);
    });

    test('group duration, dissolve and delete', () {
      final fields = [f('h', '0', isGroup: true), f('a', '5', groupId: 'h'), f('b', '7', groupId: 'h'), f('c', '3')];
      expect(PlanUtils.groupDuration(fields, 'h'), 12);
      expect(PlanUtils.displayMinutes(fields.first, fields), 12);
      expect(ids(PlanUtils.dissolveGroup(fields, 'h')), ['a', 'b', 'c']);
      expect(PlanUtils.dissolveGroup(fields, 'h').every((e) => e.groupId == null), isTrue);
      expect(ids(PlanUtils.deleteGroup(fields, 'h')), ['c']);
    });

    test('addSubItem appends at the end of the block', () {
      final fields = [f('h', '0', isGroup: true), f('a', '5', groupId: 'h'), f('c', '3')];
      final result = PlanUtils.addSubItem(fields, 'h', f('n', '4'));
      expect(ids(result), ['h', 'a', 'n', 'c']);
      expect(result[2].groupId, 'h');
    });

    test('toggleIndent moves an Unterpunkt out below its block', () {
      final fields = [f('h', '0', isGroup: true), f('a', '5', groupId: 'h'), f('b', '5', groupId: 'h'), f('c', '3')];
      expect(PlanUtils.canIndent(fields, 3), isTrue);
      final out = PlanUtils.toggleIndent(fields, 1);
      expect(ids(out), ['h', 'b', 'a', 'c']);
      expect(out[2].groupId, isNull);
      final back = PlanUtils.toggleIndent(out, 2);
      expect(back[2].groupId, 'h');
      expect(PlanUtils.canIndent(out, 3), isFalse);
    });

    test('moveField moves a head together with its Unterpunkte', () {
      final fields = [f('x', '5'), f('h', '0', isGroup: true), f('a', '5', groupId: 'h'), f('y', '5')];
      final result = PlanUtils.moveField(fields, 1, 0);
      expect(ids(result), ['h', 'a', 'x', 'y']);
      expect(result[1].groupId, 'h');
    });

    test('moveField joins a block when dropped below its head', () {
      final fields = [f('h', '0', isGroup: true), f('a', '5', groupId: 'h'), f('y', '5')];
      final result = PlanUtils.moveField(fields, 2, 1);
      expect(ids(result), ['h', 'y', 'a']);
      expect(result[1].groupId, 'h');
    });

    test('moveField with override leaves the block', () {
      final fields = [f('h', '0', isGroup: true), f('a', '5', groupId: 'h'), f('b', '5', groupId: 'h')];
      final result = PlanUtils.moveField(fields, 1, 2, overrideGroup: true, joinGroup: null);
      expect(result[2].groupId, isNull);
    });

    test('cloneBlock creates fresh ids and keeps song ids', () {
      final fields = [
        f('h', '0', isGroup: true),
        const PlanField(id: '12', name: 'Werk', time: '5', groupId: 'h', songId: 12),
        f('a', '5', groupId: 'h'),
      ];
      final clone = PlanUtils.cloneBlock(fields);
      expect(clone.first.id, isNot('h'));
      expect(clone[1].id, '12');
      expect(clone[2].id, isNot('a'));
      expect(clone.skip(1).every((e) => e.groupId == clone.first.id), isTrue);
      final tpl = PlanBlockTemplate(id: 't', name: 'T', fields: clone);
      expect(PlanUtils.templateMinutes(tpl), 10);
    });
  });

  group('Times', () {
    test('parses HH:mm and ISO strings', () {
      expect(PlanUtils.parseTimeToMinutes('17:50'), 17 * 60 + 50);
      expect(PlanUtils.parseTimeToMinutes('2026-10-28T09:35'), 9 * 60 + 35);
      expect(PlanUtils.parseTimeToMinutes(''), isNull);
      expect(PlanUtils.formatTime('2026-10-28T09:35:00'), '09:35');
    });

    test('computes start times and end (heads count 0 min)', () {
      final fields = [f('a', '20'), f('h', '0', isGroup: true), f('b', '15', groupId: 'h'), f('c', '10')];
      expect(PlanUtils.computeEnd('10:00', fields), '10:45');
      expect(PlanUtils.formatMinutes(PlanUtils.startMinutesAt(600, fields, 3)), '10:35');
      expect(PlanUtils.groupRange(600, fields, 1), '10:20 – 10:35');
    });
  });

  group('Several plans per Termin', () {
    const att = PlanAttendance(
      id: 1,
      date: '2026-10-24',
      durationDays: 3,
      plan: Plan(time: '10:00', fields: [PlanField(id: 'a', name: 'A', time: '10')]),
      extraPlans: [Plan(time: '09:00', day: 2, fields: [PlanField(id: 'b', name: 'B', time: '10')])],
    );

    test('labels, dates and today index', () {
      final plans = PlanUtils.allPlans(att);
      expect(plans, hasLength(2));
      expect(PlanUtils.planLabel(att, 0, plans), 'Sa 24.10.');
      expect(PlanUtils.planLabel(att, 1, plans), 'Mo 26.10.');
      expect(PlanUtils.planDate(att, 1, plans), DateTime(2026, 10, 26));
      expect(PlanUtils.todayPlanIndex(att, DateTime(2026, 10, 26, 12)), 1);
      expect(PlanUtils.todayPlanIndex(att, DateTime(2026, 10, 25, 12)), 0);
      expect(PlanUtils.nextFreeDay(att, plans), 1);
    });

    test('splitPlans writes plan + extra_plans', () {
      final split = PlanUtils.splitPlans(PlanUtils.withDays(att, PlanUtils.allPlans(att)));
      expect((split['plan'] as Map)['day'], 0);
      expect(split['extra_plans'], hasLength(1));
      expect(PlanUtils.splitPlans([const Plan()])['extra_plans'], isNull);
    });

    test('custom label wins', () {
      const single = PlanAttendance(id: 2, date: '2026-10-24', plan: Plan(label: 'Probe'));
      expect(PlanUtils.planLabel(single, 0), 'Probe');
      expect(PlanUtils.planLabel(single.copyWith(plan: const Plan()), 0), 'Plan 1');
    });
  });

  group('Live mode', () {
    final date = DateTime(2026, 10, 28);
    final fields = [f('h', '0', isGroup: true), f('a', '10', groupId: 'h'), f('b', '20')];

    test('is live from 5 min before start until 15 min after end', () {
      expect(PlanUtils.isLiveNow(date, '10:00', fields, DateTime(2026, 10, 28, 9, 54)), isFalse);
      expect(PlanUtils.isLiveNow(date, '10:00', fields, DateTime(2026, 10, 28, 9, 56)), isTrue);
      expect(PlanUtils.isLiveNow(date, '10:00', fields, DateTime(2026, 10, 28, 10, 44)), isTrue);
      expect(PlanUtils.isLiveNow(date, '10:00', fields, DateTime(2026, 10, 28, 10, 46)), isFalse);
    });

    test('active field skips block heads, countdown counts down', () {
      final now = DateTime(2026, 10, 28, 10, 5, 30);
      final active = PlanUtils.activeIndex(date, '10:00', fields, now);
      expect(active, 1);
      expect(PlanUtils.activeCountdown(date, '10:00', fields, active, now), '04:30');
      expect(PlanUtils.activeIndex(date, '10:00', fields, DateTime(2026, 10, 28, 10, 15)), 2);
      expect(PlanUtils.activeIndex(date, '10:00', fields, DateTime(2026, 10, 28, 9, 59)), -1);
    });

    test('start countdown', () {
      expect(PlanUtils.startCountdown(date, '10:00', DateTime(2026, 10, 28, 9, 56)), 'beginnt in 4 Min.');
      expect(PlanUtils.startCountdown(date, '10:00', DateTime(2026, 10, 28, 9, 59, 30)), 'beginnt gleich');
      expect(PlanUtils.startCountdown(date, '10:00', DateTime(2026, 10, 28, 10, 1)), '');
      expect(PlanUtils.formatDuration(3725), '1:02:05');
    });
  });

  group('Org plan entries', () {
    test('split into upcoming (ascending) and past (descending)', () {
      final entries = [
        const OrgPlanEntry.attendance(PlanAttendance(id: 1, date: '2026-10-30', plan: Plan())),
        const OrgPlanEntry.adHoc(SharedPlan(id: 'k1', editKey: 'e', date: '2026-10-20', planTitle: 'Ad-hoc')),
        const OrgPlanEntry.attendance(PlanAttendance(id: 2, date: '2026-10-28', plan: Plan())),
        const OrgPlanEntry.adHoc(SharedPlan(id: 'k2', editKey: 'e', date: '2026-10-10')),
      ];
      final split = splitOrgPlanEntries(entries, DateTime(2026, 10, 28, 12));
      expect(split.upcoming.map((e) => e.key), ['att-2', 'att-1']);
      expect(split.past.map((e) => e.key), ['adhoc-k1', 'adhoc-k2']);
      expect(split.past.first.title, 'Ad-hoc');
      expect(split.past.first.tenantLabel, 'Org-Plan');
      expect(split.past.last.title, 'Plan');
    });
  });
}
