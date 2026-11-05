import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../core/utils/plan_utils.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/models/plan/plan.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../attendance/presentation/attendance_song_history.dart';
import '../../../../attendance/presentation/widgets/songs_selection_sheet.dart' show SongHistoryEntry;
import '../../../../planning/presentation/attendance_plan_viewer.dart';
import '../rd_widgets.dart';

/// REDESIGN (concept "Termin-Bereich neu", Schritt 2): the Ablauf of a
/// Termin in the page itself: "Jetzt im Ablauf" while it runs, the
/// timeline in the Programm tab and the Programm summary in the Überblick.

/// The Ablaufplan of [attendance]; null without entries.
Plan? rdPlanOf(Attendance attendance) {
  if (!attendanceHasPlan(attendance)) return null;
  try {
    return Plan.fromJson(attendance.plan!);
  } catch (_) {
    return null;
  }
}

/// One timed row of the Ablauf (notes and block heads take no time).
typedef RdPlanSlot = ({int index, PlanField field, DateTime start, DateTime end});

/// Timed rows of [plan] on the Termin day; empty without a start time.
List<RdPlanSlot> rdPlanSlots(Attendance attendance, Plan plan) {
  final start = PlanUtils.planStart(EventListUtils.parse(attendance.date), plan.time);
  if (start == null) return const [];
  final slots = <RdPlanSlot>[];
  var t = start;
  for (var i = 0; i < plan.fields.length; i++) {
    final f = plan.fields[i];
    if (PlanUtils.isGroupHead(f) || PlanUtils.isAgendaPlaceholder(f)) continue;
    final minutes = PlanUtils.minutesOf(f);
    final end = t.add(Duration(minutes: minutes));
    if (!PlanUtils.isNote(f)) slots.add((index: i, field: f, start: t, end: end));
    t = end;
  }
  return slots;
}

/// "16:00–17:35" of [plan]; empty without a start time.
String rdPlanRange(Plan plan) {
  final start = PlanUtils.formatTime(plan.time);
  if (start.isEmpty) return '';
  final end = PlanUtils.computeEnd(plan.time, plan.fields);
  return end.isEmpty || end == start ? start : '$start–$end';
}

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Rebuilds once a minute (the current Ablauf row moves on).
mixin _MinuteTicker<T extends StatefulWidget> on State<T> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// "Jetzt im Ablauf · bis 20:05", the current row, "Danach: Gloria ·
/// 20:05". Nothing outside the Ablauf's time.
class RdPlanNow extends StatefulWidget {
  const RdPlanNow({super.key, required this.attendance, this.now});

  final Attendance attendance;

  /// For tests.
  final DateTime? now;

  @override
  State<RdPlanNow> createState() => _RdPlanNowState();
}

class _RdPlanNowState extends State<RdPlanNow> with _MinuteTicker {
  @override
  Widget build(BuildContext context) {
    final plan = rdPlanOf(widget.attendance);
    if (plan == null) return const SizedBox.shrink();
    final slots = rdPlanSlots(widget.attendance, plan);
    final now = widget.now ?? DateTime.now();
    final current = slots.indexWhere((s) => !now.isBefore(s.start) && now.isBefore(s.end));
    if (current < 0) return const SizedBox.shrink();
    final p = context.rd;
    final l10n = context.l10n;
    final slot = slots[current];
    final next = slots.skip(current + 1).take(2).toList();
    return Container(
      key: const Key('rd-plan-now'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.redesignEventNowInPlan(_hm(slot.end)).toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: p.text2),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (slot.field.songId != null) ...[
                Icon(Icons.music_note_outlined, size: 20, color: p.primary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  slot.field.name,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.text),
                ),
              ),
            ],
          ),
          if (next.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l10n.redesignEventNextInPlan([for (final n in next) '${_hm(n.start)} ${n.field.name}'].join(' · ')),
              style: RdType.meta(p, size: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// The Ablauf as a list (Reiter Programm): time, row, minutes; Programmblock
/// heads as small headings. On the Termin day the past rows are grey and
/// the current one is marked "jetzt".
class RdPlanTimeline extends StatefulWidget {
  const RdPlanTimeline({super.key, required this.attendance, required this.plan, this.now});

  final Attendance attendance;
  final Plan plan;

  /// For tests.
  final DateTime? now;

  @override
  State<RdPlanTimeline> createState() => _RdPlanTimelineState();
}

class _RdPlanTimelineState extends State<RdPlanTimeline> with _MinuteTicker {
  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final plan = widget.plan;
    final fields = plan.fields;
    final startMinutes = PlanUtils.parseTimeToMinutes(plan.time);
    final slots = {for (final s in rdPlanSlots(widget.attendance, plan)) s.index: s};
    final now = widget.now ?? DateTime.now();
    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i++) {
      final f = fields[i];
      if (PlanUtils.isAgendaPlaceholder(f)) continue;
      if (PlanUtils.isGroupHead(f)) {
        rows.add(Container(
          width: double.infinity,
          color: p.bg,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 7),
          child: Text(
            f.name.toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: p.softText),
          ),
        ));
        continue;
      }
      final note = PlanUtils.isNote(f);
      final slot = slots[i];
      final past = slot != null && !now.isBefore(slot.end);
      final current = slot != null && !past && !now.isBefore(slot.start);
      final minutes = PlanUtils.minutesOf(f);
      final time = startMinutes == null || note ? '' : PlanUtils.formatMinutes(PlanUtils.startMinutesAt(startMinutes, fields, i));
      final color = past ? p.text2 : p.text;
      rows.add(Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: current
            ? BoxDecoration(color: p.soft, border: Border(left: BorderSide(color: p.primary, width: 3)))
            : null,
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (f.songId != null) ...[
              Icon(Icons.music_note_outlined, size: 16, color: past ? p.text2 : p.primary),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                f.name,
                style: TextStyle(
                  fontSize: 15,
                  color: color,
                  fontStyle: note ? FontStyle.italic : null,
                  fontWeight: current ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (current)
              RdPill(l10n.redesignEventPlanNowPill, tone: RdTone.present)
            else if (!note && minutes > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  l10n.redesignEventPlanMinutes(minutes),
                  style: TextStyle(fontSize: 12, color: p.text2, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
          ],
        ),
      ));
    }
    return RdCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(p.cardRadius),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: p.line),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Überblick: "Programm" with "4 Werke · Ablauf 16:00–17:35" and the first
/// Werke; tap opens the Reiter Programm.
class RdProgramSummary extends ConsumerWidget {
  const RdProgramSummary({super.key, required this.attendance, required this.showWorks, required this.onTap});

  final Attendance attendance;
  final bool showWorks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final id = attendance.id;
    final works = showWorks && id != null
        ? ref.watch(attendanceSongEntriesProvider(id)).valueOrNull ?? const <SongHistoryEntry>[]
        : const <SongHistoryEntry>[];
    final plan = rdPlanOf(attendance);
    final range = plan == null ? '' : rdPlanRange(plan);
    final title = [
      if (works.isNotEmpty) l10n.redesignEventProgramWorks(works.length),
      if (plan != null) range.isEmpty ? l10n.redesignEventPlanSection : l10n.redesignEventProgramPlan(range),
    ].join(' · ');
    if (title.isEmpty) return const SizedBox.shrink();
    final names = works.map((w) => w.songName).toList();
    final shownNames = names.length > 2
        ? l10n.redesignEventProgramMore(names.take(2).join(', '), names.length - 2)
        : names.join(', ');
    final subtitle = [
      if (shownNames.isNotEmpty) shownNames,
      if (plan != null && attendance.sharePlan) l10n.redesignEventPlanShared,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        RdGroupLabel(l10n.redesignEventProgram),
        RdGroupedList(children: [
          RdListRow(
            key: const Key('rd-program-summary'),
            leading: const RdRowIcon(Icons.queue_music_outlined),
            title: title,
            subtitle: subtitle.isEmpty ? null : subtitle,
            onTap: onTap,
          ),
        ]),
      ],
    );
  }
}
