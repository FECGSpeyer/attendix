import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/duty_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/duty/person_unavailability.dart';
import 'duty_actions.dart';
import 'duty_assign_sheet.dart';

/// "Besetzung" block on the attendance detail page for Termine of duty types.
class DutyStaffingSection extends ConsumerStatefulWidget {
  const DutyStaffingSection({
    super.key,
    required this.attendance,
    required this.attendanceType,
  });

  final Attendance attendance;
  final AttendanceType attendanceType;

  @override
  ConsumerState<DutyStaffingSection> createState() => _DutyStaffingSectionState();
}

class _DutyStaffingSectionState extends ConsumerState<DutyStaffingSection> {
  int? _localRequired;
  bool _busy = false;

  int get _attendanceId => widget.attendance.id!;

  int get _required =>
      _localRequired ?? dutyRequired(widget.attendance, widget.attendanceType);

  @override
  Widget build(BuildContext context) {
    final players = ref.watch(filteredPersonAttendancesForAttendanceProvider(_attendanceId)).valueOrNull ??
        const <PersonAttendance>[];
    final canManage = ref.watch(canManageDutyProvider);
    final myPersonId = ref.watch(currentSelfServicePlayerProvider).valueOrNull?.id;

    final occupants = players.where(occupiesDuty).toList();
    final available = players.where((p) => (p.dutyState ?? '').isEmpty && !isCancelled(p)).toList();
    final unavailable = players.where(isCancelled).toList();
    final fillColor = dutyFillColor(dutyFill(players, _required));
    final neededText = _required == 1 ? 'Benötigt: 1 Person' : 'Benötigt: $_required Personen';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.headset_mic_outlined, color: AppColors.primary),
            title: Row(
              children: [
                const Text('Besetzung', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                DutyPill(text: '${occupants.length}/$_required', color: fillColor),
              ],
            ),
            subtitle: Text(neededText),
            trailing: canManage
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        tooltip: 'Weniger Personen benötigt',
                        onPressed: _required <= 1 || _busy ? null : () => _changeRequired(-1),
                      ),
                      Text('$_required'),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Mehr Personen benötigt',
                        onPressed: _busy ? null : () => _changeRequired(1),
                      ),
                    ],
                  )
                : null,
          ),
          const Divider(height: 1),
          for (final pa in occupants) ...[
            ListTile(
              dense: true,
              title: Text(pa.fullName),
              subtitle: pa.dutyState == DutyState.self ? const Text('selbst eingetragen') : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DutyPill(
                    text: pa.dutyState == DutyState.requested ? 'angefragt' : 'bestätigt',
                    color: pa.dutyState == DutyState.requested ? AppColors.warningDark : AppColors.successDark,
                  ),
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.medium),
                      tooltip: 'Austragen',
                      onPressed: () => _unassign(pa),
                    ),
                ],
              ),
            ),
            if (pa.dutyState == DutyState.requested && myPersonId != null && pa.personId == myPersonId)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Du bist eingeteilt · Bitte bestätigen',
                          style: TextStyle(color: AppColors.medium, fontSize: 13)),
                    ),
                    OutlinedButton(
                      onPressed: () => declineDutyAction(context, ref, pa.id!, _attendanceId),
                      child: const Text('Kann nicht'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                      onPressed: () => confirmDutyAction(context, ref, pa.id!, _attendanceId),
                      child: const Text('Bestätigen'),
                    ),
                  ],
                ),
              ),
          ],
          if (canManage)
            ListTile(
              leading: const Icon(Icons.person_add_alt_outlined, color: AppColors.primary),
              title: const Text('Person einteilen', style: TextStyle(color: AppColors.primary)),
              onTap: _busy ? null : () => _openAssign(players, occupants.length),
            ),
          if (canManage && available.isNotEmpty) ...[
            _divider('Verfügbar'),
            for (final pa in available)
              ListTile(
                dense: true,
                title: Text(pa.fullName),
                trailing: OutlinedButton(
                  onPressed: _busy ? null : () => _assign([pa.id!]),
                  child: const Text('Einteilen'),
                ),
              ),
          ],
          if (unavailable.isNotEmpty) ...[
            _divider('Kann nicht'),
            for (final pa in unavailable)
              ListTile(
                dense: true,
                title: Text(pa.fullName),
                subtitle: (pa.notes ?? '').isNotEmpty ? Text(pa.notes!) : null,
                trailing: DutyPill(
                  text: (pa.dutyState ?? '').isNotEmpty ? 'abgesagt' : 'abgemeldet',
                  color: AppColors.medium,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _divider(String label) => Container(
        color: AppColors.medium.withAlpha(20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );

  Future<void> _changeRequired(int delta) async {
    final next = (_required + delta) < 1 ? 1 : _required + delta;
    setState(() => _localRequired = next);
    final ok = await ref.read(dutyNotifierProvider.notifier).updateDutyRequired(_attendanceId, next);
    if (!ok && mounted) ToastHelper.showError(context, 'Fehler beim Speichern');
  }

  Future<void> _assign(List<String> ids) async {
    setState(() => _busy = true);
    final ok = await ref.read(dutyNotifierProvider.notifier).assign(ids, _attendanceId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ToastHelper.showSuccess(
        context,
        ids.length == 1
            ? 'Eingeteilt, die Person wird benachrichtigt'
            : 'Eingeteilt, die Personen werden benachrichtigt',
      );
    } else {
      ToastHelper.showError(context, 'Fehler beim Einteilen');
    }
  }

  Future<void> _unassign(PersonAttendance pa) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Aus dem Dienst austragen?',
      message: '${pa.firstName ?? ''} ist dann nicht mehr eingeteilt.',
      confirmText: 'Austragen',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(dutyNotifierProvider.notifier).unassign(pa.id!, _attendanceId);
    if (!ok && mounted) ToastHelper.showError(context, 'Fehler beim Austragen');
  }

  /// Sheet "Person einteilen": candidates sorted by their duties in the Termin's month.
  Future<void> _openAssign(List<PersonAttendance> players, int occupied) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(dutyRepositoryWithTenantProvider);
      final types = ref.read(attendanceTypesProvider).valueOrNull ?? [widget.attendanceType];
      final candidates = players.where((p) => !occupiesDuty(p) && p.id != null).toList();
      final date = DateTime.tryParse(widget.attendance.date)?.toLocal() ?? DateTime.now();
      final monthStart = DateTime(date.year, date.month);
      final monthEnd = DateTime(date.year, date.month + 1).subtract(const Duration(milliseconds: 1));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

      final results = await Future.wait([
        repo.getDutyCounts(
          candidates.map((c) => c.personId).whereType<int>().toList(),
          monthStart,
          monthEnd,
        ),
        repo.getUnavailabilityForTenant(),
        repo.getUpcomingDutyTermine(types, from: dayStart, until: dayEnd),
      ]);
      final counts = results[0] as Map<int, int>;
      final unavailability = results[1] as List<PersonUnavailability>;
      final sameDay = results[2] as List<DutyTermin>;

      final busyToday = <int>{};
      for (final t in sameDay) {
        if (t.attendance.id == _attendanceId) continue;
        for (final p in t.persons.where(occupiesDuty)) {
          if (p.personId != null) busyToday.add(p.personId!);
        }
      }

      final list = candidates.map((pa) {
        final rule = pa.personId == null
            ? null
            : matchingUnavailability(
                unavailability, pa.personId!, widget.attendance.date, widget.attendance.typeId);
        var note = '';
        if (isCancelled(pa)) {
          note = (pa.notes ?? '').isNotEmpty ? 'Kann nicht: ${pa.notes}' : 'Kann nicht';
        } else if (rule != null) {
          note = rule.reason.isNotEmpty ? 'Regelmäßig verhindert: ${rule.reason}' : 'Regelmäßig verhindert';
        }
        return DutyCandidate(
          personAttendanceId: pa.id!,
          name: pa.fullName,
          count: counts[pa.personId] ?? 0,
          sameDay: busyToday.contains(pa.personId),
          unavailableNote: note,
        );
      }).toList();

      if (!mounted) return;
      setState(() => _busy = false);
      final dateLabel = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.';
      final selected = await showDutyAssignSheet(
        context,
        title: '${widget.attendanceType.name} · $dateLabel',
        openPlaces: (_required - occupied).clamp(0, 999),
        candidates: list,
        monthLabel: monthNames[date.month - 1],
      );
      if (selected != null && selected.isNotEmpty && mounted) {
        await _assign(selected);
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Fehler: $e');
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }
}
