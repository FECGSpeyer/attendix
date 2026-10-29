import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/duty_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/duty/person_unavailability.dart';
import 'duty_actions.dart';
import 'duty_assign_sheet.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive_platform.dart' show useIosLook; // PARITY_R9
import '../../../../shared/widgets/layout/ionic_md.dart' show IonMd; // PARITY_R9
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/ion_button_label.dart';

/// ASTRA_DUTY_GROUPS: Ionic attendance.page.ts builds the Besetzung block from
/// `this.players`, i.e. the person rows after the helper group filter of
/// `initializeAttObjects` (helpers without `attendance_all_groups` only see
/// their own group). Same [AttendanceGroupScope] as the participant list of
/// the attendance detail page (loading/error/no group = nobody).
List<PersonAttendance> dutyStaffingPlayers(List<PersonAttendance> rows, AttendanceGroupScope scope) =>
    scope.isAll ? rows : rows.where((p) => scope.allowsGroup(p.instrument)).toList();

/// ASTRA_DUTY_GROUPS: note shown under a person who cannot do the duty. Uses
/// the note permission of the participant list (canViewAttendanceNotesFor,
/// Ionic `player_notes_view`): without it a note is masked as
/// "Notiz hinzugefügt". Ionic's own duty block prints `pa.notes` unmasked;
/// Flutter deliberately applies the stricter list rule here.
String? dutyStaffingNote(String? notes, {required bool canViewNotes, required String noteAddedLabel}) {
  if (notes == null || notes.isEmpty) return null;
  return canViewNotes ? notes : noteAddedLabel;
}

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
    final allRows = ref.watch(filteredPersonAttendancesForAttendanceProvider(_attendanceId)).valueOrNull ??
        const <PersonAttendance>[];
    // ASTRA_DUTY_GROUPS: same group scope + note permission as the list.
    final groupScope = resolvedGroupScope(ref.watch(attendanceGroupScopeProvider));
    final canViewNotes = ref.watch(canViewAttendanceNotesProvider);
    final players = dutyStaffingPlayers(allRows, groupScope);
    final canManage = ref.watch(canManageDutyProvider);
    final myPersonId = ref.watch(currentSelfServicePlayerProvider).valueOrNull?.id;

    final occupants = players.where(occupiesDuty).toList();
    final available = players.where((p) => (p.dutyState ?? '').isEmpty && !isCancelled(p)).toList();
    final unavailable = players.where(isCancelled).toList();
    final fillColor = dutyFillColor(dutyFill(players, _required));
    final l10n = context.l10n;
    final neededText = l10n.attendanceNeeded(_required);

    // PARITY_R9: an `ion-item-group` of Ionic's inset list, not an
    // ion-card – md shows a flat block with radius 16 and no shadow.
    final ios = useIosLook(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingXS),
      elevation: ios ? null : 0,
      shape: ios ? null : IonMd.insetGroupShape,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.headset_mic_outlined, color: AppColors.primary),
            title: Row(
              children: [
                Text(l10n.attendanceStaffing, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                        tooltip: l10n.attendanceFewerPeopleNeeded,
                        onPressed: _required <= 1 || _busy ? null : () => _changeRequired(-1),
                      ),
                      Text('$_required'),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: l10n.attendanceMorePeopleNeeded,
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
              subtitle: pa.dutyState == DutyState.self ? Text(l10n.attendanceSelfSignedUp) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DutyPill(
                    text: pa.dutyState == DutyState.requested ? l10n.attendanceRequested : l10n.attendanceConfirmed,
                    color: pa.dutyState == DutyState.requested ? AppColors.warningDark : AppColors.successDark,
                  ),
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.medium),
                      tooltip: l10n.attendanceUnassign,
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
                    Expanded(
                      child: Text('${l10n.signoutYouAreAssigned} · ${l10n.signoutPleaseConfirm}',
                          style: const TextStyle(color: AppColors.medium, fontSize: 13)),
                    ),
                    OutlinedButton(
                      onPressed: () => declineDutyAction(context, ref, pa.id!, _attendanceId),
                      child: IonButtonLabel(l10n.signoutCannot),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                      onPressed: () => confirmDutyAction(context, ref, pa.id!, _attendanceId),
                      child: IonButtonLabel(l10n.commonConfirm),
                    ),
                  ],
                ),
              ),
          ],
          if (canManage)
            ListTile(
              leading: const Icon(Icons.person_add_alt_outlined, color: AppColors.primary),
              title: Text(l10n.attendanceAssignPerson, style: const TextStyle(color: AppColors.primary)),
              onTap: _busy ? null : () => _openAssign(players, occupants.length),
            ),
          if (canManage && available.isNotEmpty) ...[
            _divider(l10n.attendanceAvailable),
            for (final pa in available)
              ListTile(
                dense: true,
                title: Text(pa.fullName),
                trailing: OutlinedButton(
                  onPressed: _busy ? null : () => _assign([pa.id!]),
                  child: IonButtonLabel(l10n.attendanceAssign),
                ),
              ),
          ],
          if (unavailable.isNotEmpty) ...[
            _divider(l10n.signoutCannot),
            for (final pa in unavailable)
              ListTile(
                dense: true,
                title: Text(pa.fullName),
                subtitle: switch (dutyStaffingNote(pa.notes,
                    canViewNotes: canViewNotes, noteAddedLabel: l10n.attendanceNoteAdded)) {
                  final note? => Text(note),
                  null => null,
                },
                trailing: DutyPill(
                  text: (pa.dutyState ?? '').isNotEmpty ? l10n.attendanceDeclined : l10n.attendanceSignedOut,
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
    if (!ok && mounted) ToastHelper.showError(context, context.l10n.extraFieldsSaveFailed);
  }

  Future<void> _assign(List<String> ids) async {
    setState(() => _busy = true);
    final ok = await ref.read(dutyNotifierProvider.notifier).assign(ids, _attendanceId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ToastHelper.showSuccess(
        context,
        context.l10n.attendanceAssignedNotified(ids.length),
      );
    } else {
      ToastHelper.showError(context, context.l10n.svcAssignFailed);
    }
  }

  Future<void> _unassign(PersonAttendance pa) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.attendanceUnassignConfirm,
      message: context.l10n.dutyFlutterUnassignMessage(pa.firstName ?? ''),
      confirmText: context.l10n.attendanceUnassign,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(dutyNotifierProvider.notifier).unassign(pa.id!, _attendanceId);
    if (!ok && mounted) ToastHelper.showError(context, context.l10n.svcUnassignFailed);
  }

  /// Sheet "Person einteilen": candidates sorted by their duties in the Termin's month.
  Future<void> _openAssign(List<PersonAttendance> players, int occupied) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final repo = ref.read(dutyRepositoryWithTenantProvider);
      final canViewNotes = ref.read(canViewAttendanceNotesProvider);
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
          final visible = dutyStaffingNote(pa.notes,
              canViewNotes: canViewNotes, noteAddedLabel: l10n.attendanceNoteAdded); // ASTRA_DUTY_GROUPS
          note = visible != null ? l10n.attendanceCannotWithNote(visible) : l10n.signoutCannot;
        } else if (rule != null) {
          note = rule.reason.isNotEmpty
              ? l10n.attendanceRegularlyUnavailableWithReason(rule.reason)
              : l10n.signoutRegularlyUnavailable;
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
        monthLabel: DateFormat.MMMM(currentIntlLocale()).format(date),
      );
      if (selected != null && selected.isNotEmpty && mounted) {
        await _assign(selected);
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, l10n.dutyFlutterErrorWith(friendlyErrorMessage(e)));
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }
}
