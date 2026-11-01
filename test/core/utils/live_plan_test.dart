import 'package:attendix/core/utils/live_plan.dart';
import 'package:attendix/data/models/plan/plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// LIVE_ACTIVITY: port of Ionic supabase/functions/_shared/live-plan-state.ts.
void main() {
  setUpAll(() async {
    await LiveTimezone.ensureInitialized();
  });

  // 2026-10-21 19:00 Europe/Berlin (CEST, UTC+2) = 17:00 UTC
  final start = DateTime.utc(2026, 10, 21, 17).millisecondsSinceEpoch;
  const min = 60000;

  List<LivePlanItem> schedule() => buildSchedule(
        date: '2026-10-21 10:00:00+00',
        planTime: '19:00',
        fields: const [
          PlanField(id: 'a', name: 'Einspielen', time: '15', conductor: ' Max '),
          PlanField(id: 'agenda-items-placeholder', name: 'x', time: '30'),
          PlanField(id: 'b', name: 'Probe', time: '45'),
          PlanField(id: 'c', name: 'Sitzung', time: '10', agendaItemId: 'ag1'),
        ],
        timezone: 'Europe/Berlin',
      );

  test('time zone database loads', () {
    expect(LiveTimezone.isReady, isTrue);
  });

  test('buildSchedule uses the tenant time zone, skips the agenda placeholder, numbers TOPs', () {
    final s = schedule();
    expect(s.length, 3);
    expect(s[0].start, start);
    expect(s[0].end, start + 15 * min);
    expect(s[0].subtitle, 'Max');
    expect(s[1].start, start + 15 * min);
    expect(s[2].name, 'TOP 1 · Sitzung');
    expect(s[2].end, start + 70 * min);
  });

  test('buildSchedule accepts date-only and ISO plan times and day offsets', () {
    final s = buildSchedule(
      date: '2026-10-21',
      planTime: '2026-01-01T19:00:00',
      dayOffset: 1,
      fields: const [PlanField(id: 'a', name: '', time: '10')],
      timezone: 'Europe/Berlin',
    );
    expect(s.single.start, start + 24 * 60 * min);
    expect(s.single.name, 'Programmpunkt');
  });

  test('buildSchedule is empty without a start time', () {
    expect(
      buildSchedule(date: '2026-10-21', planTime: '', fields: const [PlanField(id: 'a', name: 'x')], timezone: 'Europe/Berlin'),
      isEmpty,
    );
  });

  test('liveStateAt: window, before, running, ended', () {
    final s = schedule();
    expect(liveStateAt(s, start - 16 * min), isNull);

    final before = liveStateAt(s, start - 10 * min)!;
    expect(before.phase, 'before');
    expect(before.index, 1);
    expect(before.title, 'Einspielen');
    expect(before.next.map((n) => n.name), ['Probe', 'TOP 1 · Sitzung']);
    expect(before.bounds!.length, 3);

    final running = liveStateAt(s, start + 20 * min)!;
    expect(running.phase, 'running');
    expect(running.index, 2);
    expect(running.title, 'Probe');
    expect(running.startsAt, (start + 15 * min) ~/ 1000);
    expect(running.endsAt, (start + 60 * min) ~/ 1000);
    expect(running.next.single.name, 'TOP 1 · Sitzung');

    final ended = liveStateAt(s, start + 75 * min)!;
    expect(ended.phase, 'ended');
    expect(ended.title, 'Ablaufplan beendet');
    expect(ended.next, isEmpty);

    expect(liveStateAt(s, start + 85 * min), isNull);
  });

  test('iosLiveState moves the first item into the list before the start', () {
    final before = liveStateAt(schedule(), start - 5 * min)!;
    final ios = iosLiveState(before);
    expect(ios.title, 'Beginnt in');
    expect(ios.subtitle, '');
    expect(ios.next.first.name, 'Einspielen · Max');
    expect(ios.next.first.at, before.startsAt);
    expect(ios.next.length, 3);

    final running = liveStateAt(schedule(), start + 1 * min)!;
    expect(identical(iosLiveState(running), running), isTrue);
  });

  test('state map has the ContentState keys of the iOS widget', () {
    final map = liveStateAt(schedule(), start + 1 * min)!.toMap();
    expect(map.keys, [
      'phase', 'index', 'total', 'title', 'subtitle', 'startsAt', 'endsAt', 'next', 'planStart', 'planEnd', 'bounds',
    ]);
    expect((map['next'] as List).first, containsPair('at', isA<int>()));
    expect(liveStateKey(null), 'none');
    expect(liveStateKey(liveStateAt(schedule(), start + 1 * min)), liveStateKey(liveStateAt(schedule(), start + 2 * min)));
  });

  test('livePlanKey and liveTitle', () {
    expect(livePlanKey(null), 'main');
    expect(livePlanKey(const Plan()), 'main');
    expect(livePlanKey(const Plan(id: 'p2')), 'p2');

    const single = PlanAttendance(id: 1, date: '2026-10-21', plan: Plan(time: '19:00'));
    expect(liveTitle(single, 'Probe', 0), 'Probe');
    expect(liveTitle(single.copyWith(typeInfo: ' Konzert '), 'Probe', 0), 'Konzert');
    expect(liveTitle(single, '', 0), 'Termin');

    final multi = single.copyWith(extraPlans: const [Plan(id: 'x', label: 'Abend')]);
    expect(liveTitle(multi, 'Probe', 1), 'Probe · Abend');
    expect(liveTitle(multi, 'Probe', 0), 'Probe · Plan 1');
  });

  // Ionic 4.17.22 live-plan.spec.ts: 'gives the widget the colour of the Termin type'
  test('gives the widget the colour of the Termin type', () {
    expect(liveColor('rosa'), '#be72c0');
    expect(liveColor('#3880FF'), '#3880ff');
    expect(liveColor('unbekannt'), isNull);
    expect(liveColor(null), isNull);
    final s = buildSchedule(
      date: '2026-10-17',
      planTime: '10:00',
      fields: const [
        PlanField(id: 'b', name: 'Probe', time: '45'),
        PlanField(id: 'c', name: 'Pause', time: '10'),
      ],
      timezone: 'Europe/Berlin',
    );
    final state = liveStateAt(s, DateTime.utc(2026, 10, 17, 8, 5).millisecondsSinceEpoch);
    expect(state, isNotNull);
    final colored = withLiveColor(state, 'danger');
    expect(colored?.color, '#ff4961');
    expect(colored?.toMap()['color'], '#ff4961');
    expect(colored!.toMap().keys.last, 'color');
    expect(iosLiveState(colored).color, '#ff4961');
    expect(withLiveColor(state, ''), same(state));
    expect(withLiveColor(null, 'danger'), isNull);
    expect(state!.toMap().containsKey('color'), isFalse);
  });
}
