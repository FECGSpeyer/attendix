import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/haptic_helper.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../data/models/person/person.dart';
import 'attendance_detail_sheets.dart';
import 'status_chip.dart';

/// Tile displaying a person with their attendance status and actions
class AttendancePersonTile extends StatelessWidget {
  const AttendancePersonTile({
    super.key,
    required this.person,
    required this.status,
    required this.notes,
    required this.availableStatuses,
    required this.onStatusChanged,
    required this.onNoteChanged,
    required this.onShowModifierInfo,
    required this.onRemoveFromAttendance,
    this.clickMode = false,
    this.registrationSummary,
    this.onEditRegistrationFields,
  });

  final Person person;
  final AttendanceStatus status;
  final String? notes;
  final List<AttendanceStatus> availableStatuses;
  final void Function(AttendanceStatus) onStatusChanged;
  final void Function(String?) onNoteChanged;
  final VoidCallback onShowModifierInfo;
  final VoidCallback onRemoveFromAttendance;
  final bool clickMode;

  /// Summary of the registration answers ("Feld: Wert · ...").
  final String? registrationSummary;

  /// "Anmeldefelder bearbeiten" – only when the type has registration fields.
  final VoidCallback? onEditRegistrationFields;

  @override
  Widget build(BuildContext context) {
    final hasNotes = notes?.isNotEmpty == true;

    return Slidable(
      key: ValueKey(person.id),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: onEditRegistrationFields != null ? 0.5 : 0.25,
        children: [
          if (onEditRegistrationFields != null)
            SlidableAction(
              onPressed: (_) => onEditRegistrationFields!(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: Icons.edit_note,
              label: 'Anmeldefelder',
            ),
          SlidableAction(
            onPressed: (_) => onRemoveFromAttendance(),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.person_remove,
            label: 'Entfernen',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: status != AttendanceStatus.neutral && status != AttendanceStatus.lateExcused
            ? 0.65 // 4 actions
            : status != AttendanceStatus.neutral
                ? 0.5  // 3 actions (no neutral)
                : status != AttendanceStatus.lateExcused
                    ? 0.5  // 3 actions (no lateExcused)
                    : 0.4, // 2 actions (both excluded)
        children: [
          // Neutral status swipe action (if not already neutral)
          if (status != AttendanceStatus.neutral)
            SlidableAction(
              onPressed: (_) => _onStatusChangedWithHaptic(AttendanceStatus.neutral),
              backgroundColor: AppColors.medium,
              foregroundColor: Colors.white,
              icon: Icons.remove_circle_outline,
              label: 'Neutral',
            ),
          // LateExcused status swipe action (if not already lateExcused)
          if (status != AttendanceStatus.lateExcused)
            SlidableAction(
              onPressed: (_) => _onStatusChangedWithHaptic(AttendanceStatus.lateExcused),
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              icon: Icons.watch_later,
              label: 'Versp.(E)',
            ),
          SlidableAction(
            onPressed: (_) => _showNoteDialog(context),
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
            icon: hasNotes ? Icons.edit_note : Icons.note_add,
            label: 'Notiz',
          ),
          SlidableAction(
            onPressed: (_) => onShowModifierInfo(),
            backgroundColor: AppColors.tertiary,
            foregroundColor: Colors.white,
            icon: Icons.info_outline,
            label: 'Info',
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: AppDimensions.paddingXS),
        child: InkWell(
          onTap: clickMode ? _cycleStatus : () => _showStatusPicker(context),
          onLongPress: clickMode ? () => _showStatusPicker(context) : null,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
              vertical: AppDimensions.paddingS,
            ),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: status.color.withValues(alpha: 0.2),
                  backgroundImage: person.img != null ? NetworkImage(person.img!) : null,
                  child: person.img == null
                      ? Text(
                          person.initials,
                          style: TextStyle(
                            color: status.color,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppDimensions.paddingM),

                // Name and notes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (hasNotes)
                        Row(
                          children: [
                            Icon(
                              Icons.sticky_note_2,
                              size: 12,
                              color: AppColors.medium,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                notes!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.medium,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (registrationSummary?.isNotEmpty == true)
                        Text(
                          registrationSummary!,
                          style: const TextStyle(fontSize: 12, color: AppColors.medium),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                // Status indicator
                StatusChip(
                  status: status,
                  onTap: clickMode ? _cycleStatus : () => _showStatusPicker(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Note action sheet with the tenant's absence reasons (Ionic `addNote`).
  Future<void> _showNoteDialog(BuildContext context) async {
    final tenant = ProviderScope.containerOf(context, listen: false).read(currentTenantProvider);
    final result = await showPersonNoteSheet(
      context,
      currentNote: notes,
      presetReasons: EventListUtils.absenceReasonsOf(tenant?.absenceReasons),
    );
    if (result == null) return;
    onNoteChanged(result.isEmpty ? null : result);
  }

  /// Trigger haptic feedback and change status
  void _onStatusChangedWithHaptic(AttendanceStatus newStatus) {
    HapticHelper.light();
    onStatusChanged(newStatus);
  }

  /// Cycle through available statuses
  void _cycleStatus() {
    final currentIndex = availableStatuses.indexOf(status);
    final nextIndex = (currentIndex + 1) % availableStatuses.length;
    _onStatusChangedWithHaptic(availableStatuses[nextIndex]);
  }

  void _showStatusPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                person.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Status auswählen'),
            ),
            const Divider(),
            ...availableStatuses.map((s) => ListTile(
              leading: Icon(
                s.icon,
                color: s.color,
              ),
              title: Text(s.label),
              selected: s == status,
              onTap: () {
                _onStatusChangedWithHaptic(s);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: AppDimensions.paddingM),
          ],
        ),
      ),
    );
  }
}
