import 'dart:convert';

import 'package:timezone/timezone.dart' as tz;
// Deferred: the time zone database is only needed on iOS (Live Activity), so
// the web build never downloads it.
import 'package:timezone/data/latest_10y.dart' deferred as tzdata;

import '../../data/models/plan/plan.dart';
import 'plan_utils.dart';

// LIVE_ACTIVITY: schedule + live state of a running Ablaufplan.
//
// Port of Ionic `supabase/functions/_shared/live-plan-state.ts` (shared with
// the `live-activity-tick` Edge Function) and `src/app/utilities/live-plan.ts`.
// Keep the state keys in sync with PlanActivityAttributes.ContentState (iOS).

/// Minutes before the first item when the Live Activity appears.
const int liveLeadMinutes = 15;

/// Minutes after the last item the finished Live Activity stays visible.
const int liveTailMinutes = 15;

/// One item of a plan's schedule. Times are epoch milliseconds.
class LivePlanItem {
  const LivePlanItem({
    required this.name,
    required this.subtitle,
    required this.start,
    required this.end,
  });

  final String name;
  final String subtitle;
  final int start;
  final int end;
}

/// An upcoming item; [at] is epoch seconds.
class LiveNextItem {
  const LiveNextItem({required this.name, required this.at});

  final String name;
  final int at;

  Map<String, dynamic> toMap() => {'name': name, 'at': at};
}

/// What a Live Activity shows. Times are epoch seconds so Swift decodes them
/// without date-format guessing.
class LivePlanState {
  const LivePlanState({
    required this.phase,
    required this.index,
    required this.total,
    required this.title,
    required this.subtitle,
    required this.startsAt,
    required this.endsAt,
    required this.next,
    required this.planStart,
    required this.planEnd,
    this.bounds,
  });

  /// 'before' | 'running' | 'ended'
  final String phase;

  /// 1-based position of the current item.
  final int index;
  final int total;
  final String title;
  final String subtitle;
  final int startsAt;
  final int endsAt;
  final List<LiveNextItem> next;
  final int planStart;
  final int planEnd;

  /// Start of every item (epoch seconds), for the widget's timeline bar.
  final List<int>? bounds;

  LivePlanState copyWith({String? title, String? subtitle, List<LiveNextItem>? next}) {
    return LivePlanState(
      phase: phase,
      index: index,
      total: total,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      startsAt: startsAt,
      endsAt: endsAt,
      next: next ?? this.next,
      planStart: planStart,
      planEnd: planEnd,
      bounds: bounds,
    );
  }

  /// Same keys (and order) as Ionic `LivePlanState`.
  Map<String, dynamic> toMap() => {
        'phase': phase,
        'index': index,
        'total': total,
        'title': title,
        'subtitle': subtitle,
        'startsAt': startsAt,
        'endsAt': endsAt,
        'next': next.map((n) => n.toMap()).toList(),
        'planStart': planStart,
        'planEnd': planEnd,
        if (bounds != null) 'bounds': bounds,
      };
}

/// IANA time zones for the plan times (tenant.timezone).
class LiveTimezone {
  LiveTimezone._();

  static bool _ready = false;

  static bool get isReady => _ready;

  /// Loads the time zone database once. Safe to call repeatedly.
  static Future<void> ensureInitialized() async {
    if (_ready) return;
    try {
      await tzdata.loadLibrary();
      tzdata.initializeTimeZones();
      _ready = true;
    } catch (_) {
      // Falls back to the device time zone.
    }
  }

  static tz.Location? location(String name) {
    if (!_ready || name.isEmpty) return null;
    try {
      return tz.getLocation(name);
    } catch (_) {
      return null;
    }
  }
}

/// Epoch ms of a wall-clock time in [timezone] (device time zone when unknown).
/// Day overflow (day + offset) is normalised like JS `Date.UTC`.
int zonedTimeToUtc(int year, int month, int day, int hour, int minute, String timezone) {
  final loc = LiveTimezone.location(timezone);
  if (loc == null) {
    return DateTime(year, month, day, hour, minute).millisecondsSinceEpoch;
  }
  return tz.TZDateTime(loc, year, month, day, hour, minute).millisecondsSinceEpoch;
}

final _dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _shortOffset = RegExp(r'([+-]\d{2})$');

/// Calendar day (y, m, d) of an instant in [timezone].
({int year, int month, int day})? _localDay(String value, String timezone) {
  if (_dateOnly.hasMatch(value)) {
    final p = value.split('-').map(int.parse).toList();
    return (year: p[0], month: p[1], day: p[2]);
  }
  // Postgres returns "2026-10-21 10:00:00+00"; make it ISO.
  final iso = value.replaceFirst(' ', 'T').replaceFirstMapped(_shortOffset, (m) => '${m[1]}:00');
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return null;
  final loc = LiveTimezone.location(timezone);
  if (loc == null) {
    final local = parsed.toLocal();
    return (year: local.year, month: local.month, day: local.day);
  }
  final zoned = tz.TZDateTime.from(parsed, loc);
  return (year: zoned.year, month: zoned.month, day: zoned.day);
}

final _clock = RegExp(r'(?:^|T|\s)(\d{1,2}):(\d{2})');

/// Clock time of plan.time ("HH:mm" or "YYYY-MM-DDTHH:mm[:ss]").
({int hour, int minute})? _clockTime(String value) {
  final m = _clock.firstMatch(value);
  if (m == null) return null;
  return (hour: int.parse(m[1]!), minute: int.parse(m[2]!));
}

final _leadingInt = RegExp(r'^\s*([+-]?\d+)');

/// JS `parseInt(String(x), 10) || 0`.
int _parseMinutes(String value) {
  final m = _leadingInt.firstMatch(value);
  return m == null ? 0 : int.parse(m[1]!);
}

/// "TOP n · Name" for agenda items, like the plan viewer.
List<String> _displayNames(List<PlanField> fields) {
  var top = 0;
  return fields.map((f) {
    final name = f.name.trim();
    if (f.agendaItemId != null && f.agendaItemId!.isNotEmpty) {
      top++;
      return 'TOP $top · $name';
    }
    return name;
  }).toList();
}

/// Start and end of every item of a plan, in order. Empty when the plan has
/// no usable start time.
List<LivePlanItem> buildSchedule({
  required String date,
  required String planTime,
  int dayOffset = 0,
  required List<PlanField> fields,
  required String timezone,
}) {
  final day = _localDay(date, timezone);
  final clock = _clockTime(planTime);
  if (day == null || clock == null) return const [];
  final items = fields.where((f) => f.id != PlanUtils.agendaPlaceholderId).toList();
  final names = _displayNames(items);
  var cursor = zonedTimeToUtc(day.year, day.month, day.day + dayOffset, clock.hour, clock.minute, timezone);
  final result = <LivePlanItem>[];
  for (var i = 0; i < items.length; i++) {
    final minutes = _parseMinutes(items[i].time);
    final item = LivePlanItem(
      name: names[i].isNotEmpty ? names[i] : 'Programmpunkt',
      subtitle: (items[i].conductor ?? '').trim(),
      start: cursor,
      end: cursor + minutes * 60000,
    );
    cursor = item.end;
    result.add(item);
  }
  return result;
}

/// Window in which a Live Activity for this schedule should exist (epoch ms).
({int from, int to})? liveWindow(List<LivePlanItem> schedule) {
  if (schedule.isEmpty) return null;
  return (
    from: schedule.first.start - liveLeadMinutes * 60000,
    to: schedule.last.end + liveTailMinutes * 60000,
  );
}

int _sec(int ms) => (ms / 1000).floor();

/// What the Live Activity shows at [now] (epoch ms); null outside the live window.
LivePlanState? liveStateAt(List<LivePlanItem> schedule, int now) {
  final window = liveWindow(schedule);
  if (window == null || now < window.from || now >= window.to) return null;
  final planStart = schedule.first.start;
  final planEnd = schedule.last.end;
  final total = schedule.length;
  List<LiveNextItem> nextFrom(int i) => schedule
      .skip(i)
      .take(2)
      .map((item) => LiveNextItem(name: item.name, at: _sec(item.start)))
      .toList();
  final bounds = schedule.map((item) => _sec(item.start)).toList();

  if (now < planStart) {
    final first = schedule.first;
    return LivePlanState(
      phase: 'before',
      index: 1,
      total: total,
      title: first.name,
      subtitle: first.subtitle,
      startsAt: _sec(first.start),
      endsAt: _sec(first.end),
      next: nextFrom(1),
      planStart: _sec(planStart),
      planEnd: _sec(planEnd),
      bounds: bounds,
    );
  }
  if (now >= planEnd) {
    return LivePlanState(
      phase: 'ended',
      index: total,
      total: total,
      title: 'Ablaufplan beendet',
      subtitle: '',
      startsAt: _sec(planStart),
      endsAt: _sec(planEnd),
      next: const [],
      planStart: _sec(planStart),
      planEnd: _sec(planEnd),
      bounds: bounds,
    );
  }
  // Zero-length items are skipped; the item whose end lies after now is current.
  final idx = schedule.indexWhere((item) => now < item.end);
  final current = schedule[idx];
  return LivePlanState(
    phase: 'running',
    index: idx + 1,
    total: total,
    title: current.name,
    subtitle: current.subtitle,
    startsAt: _sec(current.start),
    endsAt: _sec(current.end),
    next: nextFrom(idx + 1),
    planStart: _sec(planStart),
    planEnd: _sec(planEnd),
    bounds: bounds,
  );
}

/// State as the iOS widget gets it: before the start the title becomes
/// "Beginnt in" and the first item moves into the list (Ionic `iosLiveState`).
LivePlanState iosLiveState(LivePlanState state) {
  if (state.phase != 'before') return state;
  final first = state.subtitle.isNotEmpty ? '${state.title} · ${state.subtitle}' : state.title;
  return state.copyWith(
    title: 'Beginnt in',
    subtitle: '',
    next: [LiveNextItem(name: first, at: state.startsAt), ...state.next],
  );
}

/// Stable fingerprint of a state, to send an update only when something visible changed.
String liveStateKey(LivePlanState? state) => state == null ? 'none' : jsonEncode(state.toMap());

/// Key of a plan within its Termin; plan 1 has no id. Must match the Edge Function.
String livePlanKey(Plan? plan) {
  final id = plan?.id;
  return id == null || id.isEmpty ? 'main' : id;
}

/// Header of the Live Activity: Termin name, plus the plan's label when the
/// Termin has several plans.
String liveTitle(PlanAttendance att, String typeName, int index, [List<Plan>? plans]) {
  final list = plans ?? PlanUtils.allPlans(att);
  final info = att.typeInfo?.trim() ?? '';
  final name = info.isNotEmpty ? info : (typeName.isNotEmpty ? typeName : 'Termin');
  return list.length > 1 ? '$name · ${PlanUtils.planLabel(att, index, list)}' : name;
}

/// Schedule of one plan of a Termin.
List<LivePlanItem> liveSchedule(PlanAttendance att, int index, String timezone, [List<Plan>? plans]) {
  final list = plans ?? PlanUtils.allPlans(att);
  if (index >= list.length) return const [];
  final plan = list[index];
  if (att.date.isEmpty || plan.time.isEmpty || plan.fields.isEmpty) return const [];
  return buildSchedule(
    date: att.date,
    planTime: plan.time,
    dayOffset: PlanUtils.planDay(att, list, index) ?? 0,
    fields: plan.fields,
    timezone: timezone,
  );
}
