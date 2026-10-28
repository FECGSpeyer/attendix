import 'package:flutter/material.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/l10n.dart';

// UX_ATT: Ionic attendance page status badges and click cycle.

/// Ionic `--ion-color-rosa` (Verspätet entschuldigt badge).
const Color ionicRosa = Color(0xFFBE72C0);

/// Letter + color of the Ionic status badge
/// (N medium, ✓ success, E warning, L tertiary, LE rosa, A danger).
({String text, Color color}) ionicStatusBadge(AttendanceStatus status) {
  return switch (status) {
    AttendanceStatus.neutral => (text: 'N', color: AppColors.medium),
    AttendanceStatus.present => (text: '✓', color: AppColors.success),
    AttendanceStatus.excused => (text: 'E', color: AppColors.warning),
    AttendanceStatus.late => (text: 'L', color: AppColors.tertiary),
    AttendanceStatus.lateExcused => (text: 'LE', color: ionicRosa),
    AttendanceStatus.absent => (text: 'A', color: AppColors.danger),
  };
}

/// Labels of the Ionic status select / filter (common.status.*).
String ionicStatusLabel(AttendanceStatus status) {
  final l10n = l10nWithoutContext;
  return switch (status) {
    AttendanceStatus.neutral => l10n.commonStatusNeutral,
    AttendanceStatus.present => l10n.commonStatusPresent,
    AttendanceStatus.excused => l10n.commonStatusExcused,
    AttendanceStatus.late => l10n.commonStatusLateShort,
    AttendanceStatus.lateExcused => l10n.commonStatusLateExcused,
    AttendanceStatus.absent => l10n.commonStatusAbsent,
  };
}

/// Statuses offered by the Ionic status select, in Ionic order
/// (Neutral, Anwesend, Entschuldigt, Verspätet, Verspätet entschuldigt,
/// Abwesend). "Verspätet entschuldigt" comes with "Verspätet".
List<AttendanceStatus> ionicSelectableStatuses(Iterable<AttendanceStatus> available) {
  final has = available.toSet();
  return [
    if (has.contains(AttendanceStatus.neutral)) AttendanceStatus.neutral,
    if (has.contains(AttendanceStatus.present)) AttendanceStatus.present,
    if (has.contains(AttendanceStatus.excused)) AttendanceStatus.excused,
    if (has.contains(AttendanceStatus.late)) AttendanceStatus.late,
    if (has.contains(AttendanceStatus.late)) AttendanceStatus.lateExcused,
    if (has.contains(AttendanceStatus.absent)) AttendanceStatus.absent,
  ];
}

/// Next status when a person row is tapped (Ionic onAttChange with
/// ATTENDANCE_STATUS_MAPPING). Returns null when the type's statuses match
/// none of the Ionic mappings ("Fehler beim Ändern des Anwesenheitsstatus").
AttendanceStatus? nextClickStatus(
  AttendanceStatus current,
  Iterable<AttendanceStatus> available,
) {
  const n = AttendanceStatus.neutral;
  const p = AttendanceStatus.present;
  const e = AttendanceStatus.excused;
  const l = AttendanceStatus.late;
  const le = AttendanceStatus.lateExcused;
  const a = AttendanceStatus.absent;

  final has = available.toSet()..remove(le);
  Map<AttendanceStatus, AttendanceStatus>? mapping;
  if (has.containsAll(const [n, p, e, l, a])) {
    mapping = const {n: p, a: p, p: e, e: l, l: a, le: a}; // DEFAULT
  } else if (has.contains(e) && has.contains(l)) {
    mapping = const {p: e, e: l, l: a, a: p, le: a}; // NO_NEUTRAL
  } else if (has.contains(l) && has.contains(n)) {
    mapping = const {n: p, a: p, p: l, l: a, le: a, e: p}; // NO_EXCUSED
  } else if (has.contains(e) && has.contains(n)) {
    mapping = const {n: p, a: p, p: e, e: a, l: a, le: a}; // NO_LATE
  } else if (has.contains(l)) {
    mapping = const {p: a, l: p, le: p, a: l, e: p}; // NO_NEUTRAL_NO_EXCUSED
  } else if (has.contains(n)) {
    mapping = const {n: p, a: p, p: a, e: p, l: p, le: p}; // NO_LATE_NO_EXCUSED
  } else if (has.contains(e)) {
    mapping = const {p: e, e: a, a: p, l: p, le: p}; // NO_LATE_NO_NEUTRAL
  } else if (has.length == 2 && has.contains(p) && has.contains(a)) {
    mapping = const {p: a, a: p, l: p, le: p, e: p}; // ONLY_PRESENT_ABSENT
  }
  if (mapping == null) return null;
  // LOGIC_ATT: Ionic writes `undefined` when the current status is not in
  // the mapping (no change) – keep the status instead of jumping to Anwesend.
  return mapping[current] ?? current;
}

/// Ionic `ion-badge` with the status letter.
class AttendanceStatusBadge extends StatelessWidget {
  const AttendanceStatusBadge({super.key, required this.status});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final badge = ionicStatusBadge(status);
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badge.color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        badge.text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          height: 1.1,
        ),
      ),
    );
  }
}
