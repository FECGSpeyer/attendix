import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/providers/duty_providers.dart';
import '../../../../../core/providers/signout_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../data/repositories/sign_in_out_repository.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../core/constants/enums.dart' show AttendanceStatus;
import '../../../../../data/repositories/player_absence_repository.dart' show PlayerAbsenceRepository;
import '../../../../people/presentation/widgets/person_detail/upcoming_appointments_accordion.dart'
    show upcomingAttendancesProvider;
import '../../../../people/presentation/widgets/planned_absences.dart' show AbsenceInput;
import '../../../../self_service/presentation/widgets/self_service_absences.dart';
import '../rd_widgets.dart';
import '../../../data/rd_dates.dart';

/// Own upcoming Termine of the current group between [from] and [until]
/// (both days included); what an absence in that period will excuse.
List<CrossTenantPersonAttendance> rdTermineInRange(
  List<CrossTenantPersonAttendance> upcoming,
  DateTime from,
  DateTime until, {
  int? tenantId,
}) {
  final first = DateTime(from.year, from.month, from.day);
  final last = DateTime(until.year, until.month, until.day);
  return upcoming.where((a) {
    if (a.id == null) return false;
    if (tenantId != null && a.tenantId != tenantId) return false;
    final d = EventListUtils.parse(a.date);
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(first) && !day.isAfter(last);
  }).toList();
}

/// Next range after tapping [day] (first tap: start, second: end; a day
/// before the start becomes the new start; a third tap starts again).
({DateTime? from, DateTime? until}) rdNextRange(DateTime? from, DateTime? until, DateTime day) {
  if (from == null || until != null) return (from: day, until: null);
  if (day.isBefore(from)) return (from: day, until: from);
  return (from: from, until: day);
}

/// REDESIGN: "Abwesenheit" (canvas S5): pick the period in a month view,
/// a reason, and see which Termine it excuses. Saves through
/// [saveSelfServiceAbsence] (same write and messages as "Meine Termine");
/// "Pausieren" opens the existing pause flow.
Future<void> showRdAbsenceSheet(
  BuildContext context,
  WidgetRef ref,
  Person player, {
  required bool canSelfPause,
}) async {
  final result = await showModalBottomSheet<Object>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: context.rd.bg,
    builder: (_) => _AbsenceSheet(canSelfPause: canSelfPause),
  );
  if (!context.mounted) return;
  if (result is AbsenceInput) {
    await saveSelfServiceAbsence(context, ref, player, result);
  } else if (result == _pause) {
    await selfServicePause(context, ref, player);
  }
}

/// REDESIGN: the same sheet when the leadership enters an absence for
/// someone else ("Abwesenheit für Lea", `addPlannedAbsenceFlow`). Returns
/// the input or null; the caller saves it for [personId] as before.
/// "Betrifft N Termine" counts the person's coming Termine in the period
/// that are not excused yet (what the save changes).
Future<AbsenceInput?> showRdAbsenceInputSheet(
  BuildContext context, {
  required int personId,
  required String title,
  String? hint,
}) {
  return showModalBottomSheet<AbsenceInput>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: context.rd.bg,
    builder: (_) => _AbsenceSheet(canSelfPause: false, personId: personId, title: title, hint: hint),
  );
}

/// Coming Termine of [upcoming] (rows of `upcomingAttendancesProvider`)
/// that an absence from [from] to [until] excuses: in the period, not ended
/// and not excused yet (`excuseUpcomingAttendances`).
List<Map<String, dynamic>> rdOtherTermineInRange(
  List<Map<String, dynamic>> upcoming,
  DateTime from,
  DateTime until, {
  DateTime? now,
}) {
  final fromIso = DateFormat('yyyy-MM-dd').format(from);
  final untilIso = DateFormat('yyyy-MM-dd').format(until);
  return upcoming.where((a) {
    if (a['status'] == AttendanceStatus.excused.value) return false;
    return PlayerAbsenceRepository.isUpcomingInAbsenceRange(
      a['date']?.toString() ?? '',
      null,
      fromIso,
      untilIso,
      now: now,
    );
  }).toList();
}

const _pause = 'pause';

class _AbsenceSheet extends ConsumerStatefulWidget {
  const _AbsenceSheet({required this.canSelfPause, this.personId, this.title, this.hint});

  final bool canSelfPause;

  /// Someone else (leadership): their Termine, [title] and [hint].
  final int? personId;
  final String? title;
  final String? hint;

  @override
  ConsumerState<_AbsenceSheet> createState() => _AbsenceSheetState();
}

class _AbsenceSheetState extends ConsumerState<_AbsenceSheet> {
  bool _pauseTab = false;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _from;
  DateTime? _until;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  static String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  bool get _valid => _from != null && _until != null && _reason.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    final reasons = EventListUtils.absenceReasonsOf(tenant?.absenceReasons);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(widget.title ?? l10n.redesignAbsenceTitle, style: RdType.cardTitle(p)),
            ),
            if (widget.canSelfPause) ...[
              const SizedBox(height: 14),
              RdSegmented<bool>(
                values: const [false, true],
                selected: _pauseTab,
                labelOf: (pause) => pause ? l10n.redesignAbsencePause : l10n.redesignAbsenceRange,
                onChanged: (v) => setState(() => _pauseTab = v),
              ),
            ],
            const SizedBox(height: 16),
            if (_pauseTab) ...[
              Text(l10n.redesignAbsencePauseHint, style: RdType.body(p)),
              const SizedBox(height: 18),
              RdPrimaryButton(
                label: l10n.redesignAbsencePauseButton,
                icon: Icons.pause_circle_outline,
                onPressed: () => Navigator.of(context).pop(_pause),
              ),
            ] else
              ..._rangeChildren(context, reasons),
          ],
        ),
      ),
    );
  }

  List<Widget> _rangeChildren(BuildContext context, List<String> reasons) {
    final p = context.rd;
    final l10n = context.l10n;
    final locale = currentIntlLocale();
    final from = _from;
    final until = _until;
    String day(DateTime d) => DateFormat.MMMd(locale).format(d);
    final period = from == null
        ? l10n.redesignAbsenceChooseStart
        : until == null
            ? '${day(from)} · ${l10n.redesignAbsenceChooseEnd}'
            : '${day(from)} – ${day(until)}';
    final other = widget.personId;
    final List<({String? date, String title})>? affected;
    if (other != null) {
      // Someone else: their coming Termine the save excuses.
      final upcoming = ref.watch(upcomingAttendancesProvider(other)).valueOrNull;
      affected = from == null || until == null || upcoming == null
          ? null
          : [
              for (final a in rdOtherTermineInRange(upcoming, from, until))
                (date: a['date']?.toString(), title: a['meetingName']?.toString() ?? ''),
            ];
    } else {
      // Same Termine the save changes (selfServiceAbsenceCandidateIds): no
      // unassigned duties, no own duties in the Dienstplan view.
      final data = ref.watch(signoutDataProvider).valueOrNull;
      final duty = ref.watch(myDutyOverviewProvider).valueOrNull;
      affected = from == null || until == null || data == null || duty == null
          ? null
          : [
              for (final a in rdTermineInRange(
                absenceCandidates(data, useDutyView: duty.useDutyView),
                from,
                until,
                tenantId: ref.watch(currentTenantIdProvider),
              ))
                (date: a.date, title: a.eventTitle),
            ];
    }

    return [
      RdCard(
        padding: const EdgeInsets.all(12),
        child: _MonthGrid(
          month: _month,
          from: from,
          until: until,
          onMonth: (m) => setState(() => _month = m),
          onDay: (d) => setState(() {
            final next = rdNextRange(_from, _until, d);
            _from = next.from;
            _until = next.until;
          }),
        ),
      ),
      const SizedBox(height: 14),
      RdGroupedList(
        children: [
          RdListRow(
            title: l10n.redesignAbsencePeriod,
            value: period,
            showChevron: false,
            trailing: from == null
                ? null
                : IconButton(
                    tooltip: l10n.redesignAbsenceReset,
                    icon: Icon(Icons.cancel_outlined, color: p.text2),
                    onPressed: () => setState(() {
                      _from = null;
                      _until = null;
                    }),
                  ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      RdGroupLabel(l10n.redesignAbsenceReason),
      if (reasons.isNotEmpty) ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in reasons)
              RdChoiceChip(
                label: r,
                selected: _reason.text.trim() == r,
                onTap: () => setState(() => _reason.text = r),
              ),
          ],
        ),
        const SizedBox(height: 10),
      ],
      TextField(
        controller: _reason,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: l10n.redesignAbsenceReasonHint,
          filled: true,
          fillColor: p.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(p.buttonRadius),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      if (affected != null) ...[
        const SizedBox(height: 14),
        RdCard(
          color: affected.isEmpty ? null : p.excusedSoft,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                other != null
                    ? l10n.redesignAbsenceAffectsOther(affected.length)
                    : l10n.redesignAbsenceAffects(affected.length),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
              ),
              if (affected.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  affected.take(6).map((a) {
                    final d = EventListUtils.parse(a.date);
                    final date = d == null
                        ? ''
                        : '${DateFormat.E(locale).format(d).replaceAll('.', '')} ${DateFormat('d.M.').format(d)}';
                    return '$date ${a.title}'.trim();
                  }).join(' · '),
                  style: RdType.meta(p, size: 13),
                ),
              ],
            ],
          ),
        ),
      ],
      if (widget.hint != null) ...[
        const SizedBox(height: 14),
        RdHintBox(widget.hint!),
      ],
      const SizedBox(height: 18),
      RdPrimaryButton(
        label: l10n.redesignAbsenceSubmit,
        onPressed: _valid
            ? () => Navigator.of(context).pop(AbsenceInput(
                  reason: _reason.text.trim(),
                  fromDate: _iso(_from!),
                  untilDate: _iso(_until!),
                ))
            : null,
      ),
    ];
  }
}

/// Month view with a selectable period (today and later).
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.from,
    required this.until,
    required this.onMonth,
    required this.onDay,
  });

  final DateTime month;
  final DateTime? from;
  final DateTime? until;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final locale = currentIntlLocale();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonth = DateTime(now.year, now.month);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final lead = DateTime(month.year, month.month).weekday - 1; // Monday first
    final monday = DateTime(2024, 1, 1); // a Monday
    final last = until ?? from;

    bool inRange(DateTime d) =>
        from != null && last != null && !d.isBefore(from!) && !d.isAfter(last);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: l10n.redesignAbsencePrevMonth,
              onPressed: month.isAfter(thisMonth)
                  ? () => onMonth(DateTime(month.year, month.month - 1))
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text(
                  DateFormat.yMMMM(locale).format(month),
                  style: RdType.section(p),
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.redesignAbsenceNextMonth,
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat.E(locale).format(rdAddDays(monday, i)).replaceAll('.', ''),
                      style: RdType.meta(p, size: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (var week = 0; week * 7 < lead + days; week++)
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Builder(builder: (context) {
                    final n = week * 7 + i - lead + 1;
                    if (n < 1 || n > days) return const SizedBox(height: 40);
                    final d = DateTime(month.year, month.month, n);
                    final past = d.isBefore(today);
                    final selected = inRange(d);
                    final edge = d == from || d == last;
                    return Semantics(
                      button: !past,
                      selected: selected,
                      label: DateFormat.yMMMMEEEEd(locale).format(d),
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: past ? null : () => onDay(d),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 40,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: edge ? p.primary : (selected ? p.soft : null),
                            borderRadius: BorderRadius.circular(10),
                            border: d == today && !edge ? Border.all(color: p.primary, width: 1.5) : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$n',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: edge ? FontWeight.w700 : FontWeight.w500,
                              color: edge
                                  ? p.onPrimary
                                  : past
                                      ? p.text2.withValues(alpha: 0.5)
                                      : (selected ? p.softText : p.text),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
      ],
    );
  }
}
