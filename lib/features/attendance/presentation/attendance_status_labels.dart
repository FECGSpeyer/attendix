import 'package:flutter/material.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';

/// Color used for "Verspätet entschuldigt" badges.
const Color ionicRosa = Color(0xFFBE72C0);

/// Letter and color of the status badge.
({String text, Color color}) ionicStatusBadge(AttendanceStatus status) {
  return switch (status) {
    AttendanceStatus.neutral => (text: 'N', color: AppColors.statusNeutral),
    AttendanceStatus.present => (text: '✓', color: AppColors.success),
    AttendanceStatus.excused => (text: 'E', color: AppColors.warning),
    AttendanceStatus.late => (text: 'L', color: AppColors.tertiary),
    AttendanceStatus.lateExcused => (text: 'LE', color: ionicRosa),
    AttendanceStatus.absent => (text: 'A', color: AppColors.danger),
  };
}

/// Labels of the status select / filter (`common.status.*`).
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

/// Statuses offered by the status select in canonical order.
/// "Verspätet entschuldigt" is offered alongside "Verspätet".
List<AttendanceStatus> ionicSelectableStatuses(
  Iterable<AttendanceStatus> available,
) {
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

/// Next status when a person row is tapped in the status cycle.
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
    mapping = const {n: p, a: p, p: e, e: l, l: a, le: a};
  } else if (has.contains(e) && has.contains(l)) {
    mapping = const {p: e, e: l, l: a, a: p, le: a};
  } else if (has.contains(l) && has.contains(n)) {
    mapping = const {n: p, a: p, p: l, l: a, le: a, e: p};
  } else if (has.contains(e) && has.contains(n)) {
    mapping = const {n: p, a: p, p: e, e: a, l: a, le: a};
  } else if (has.contains(l)) {
    mapping = const {p: a, l: p, le: p, a: l, e: p};
  } else if (has.contains(n)) {
    mapping = const {n: p, a: p, p: a, e: p, l: p, le: p};
  } else if (has.contains(e)) {
    mapping = const {p: e, e: a, a: p, l: p, le: p};
  } else if (has.length == 2 && has.contains(p) && has.contains(a)) {
    mapping = const {p: a, a: p, l: p, le: p, e: p};
  }
  if (mapping == null) return null;
  return mapping[current] ?? current;
}
