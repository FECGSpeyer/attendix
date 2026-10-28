import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../core/utils/haptic_helper.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/person/person.dart';
import 'attendance_detail_sheets.dart';
import 'status_chip.dart';

/// Person row of the attendance detail page.
///
/// UX_ATT: mirrors the Ionic `ion-item-sliding` row: optional avatar, name,
/// note, registration summary / sort line; on the right the status badge
/// (tap cycles the status) or, with "Explizite Statusauswahl", a status
/// dropdown. Swiping left reveals "Mehr" (grey) and "Notiz" (yellow).
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
    this.clickMode = true,
    this.registrationSummary,
    this.onEditRegistrationFields,
    this.showAvatar = true,
    this.extraLine,
    this.onSendReminder,
    this.showModifierInfo = true,
  });

  final Person person;
  final AttendanceStatus status;
  final String? notes;
  final List<AttendanceStatus> availableStatuses;
  final void Function(AttendanceStatus) onStatusChanged;
  final void Function(String?) onNoteChanged;
  final VoidCallback onShowModifierInfo;
  final VoidCallback onRemoveFromAttendance;

  /// Ionic AttendanceViewMode.CLICK (tap cycles) vs. SELECT (dropdown).
  final bool clickMode;

  /// Summary of the registration answers ("Feld: Wert · ...").
  final String? registrationSummary;

  /// "Anmeldefelder bearbeiten" – only when the type has registration fields.
  final VoidCallback? onEditRegistrationFields;

  /// "Bilder anzeigen" view option.
  final bool showAvatar;

  /// Extra line under the name (active sort value · group).
  final String? extraLine;

  /// "Erinnerung senden" for this person (null = not available).
  final VoidCallback? onSendReminder;

  /// Leaders only (not Helfer): "Wer hat geändert?" and "Person entfernen".
  final bool showModifierInfo;

  @override
  Widget build(BuildContext context) {
    final hasNotes = notes?.isNotEmpty == true;
    final medium = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.medium,
          fontSize: 12.5,
        );

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (showAvatar) ...[
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.light,
              backgroundImage: person.img != null ? NetworkImage(person.img!) : null,
              child: person.img == null
                  ? const Icon(Icons.person, color: AppColors.medium)
                  : null,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.fullName,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (hasNotes)
                  Text(
                    notes!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (registrationSummary?.isNotEmpty == true)
                  Text(registrationSummary!, style: medium, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (extraLine?.isNotEmpty == true)
                  Text(extraLine!, style: medium, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (clickMode)
            AttendanceStatusBadge(status: status)
          else
            _StatusSelect(
              status: status,
              options: ionicSelectableStatuses(availableStatuses),
              onChanged: _onStatusChangedWithHaptic,
            ),
        ],
      ),
    );

    return Slidable(
      key: ValueKey(person.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.36,
        children: [
          SlidableAction(
            onPressed: (_) => _showMoreSheet(context),
            backgroundColor: AppColors.medium,
            foregroundColor: Colors.white,
            icon: Icons.more_horiz,
          ),
          SlidableAction(
            onPressed: (_) => _showNoteDialog(context),
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.black,
            icon: Icons.edit,
          ),
        ],
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: clickMode
            ? InkWell(onTap: () => _cycleStatus(context), child: content)
            : content,
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

  /// Person action sheet (Ionic openMoreSheet, same option order).
  Future<void> _showMoreSheet(BuildContext context) async {
    final canLateExcused = clickMode && availableStatuses.contains(AttendanceStatus.late);
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        Widget option(String label, IconData icon, VoidCallback onTap, {bool destructive = false}) {
          final color = destructive ? AppColors.danger : null;
          return ListTile(
            leading: Icon(icon, color: color),
            title: Text(label, style: TextStyle(color: color)),
            onTap: () {
              Navigator.pop(ctx);
              onTap();
            },
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    person.fullName,
                    style: const TextStyle(color: AppColors.medium, fontSize: 13),
                  ),
                ),
                if (status != AttendanceStatus.neutral)
                  option('Status neutral setzen', Icons.remove_circle_outline,
                      () => _onStatusChangedWithHaptic(AttendanceStatus.neutral)),
                if (canLateExcused)
                  option('Verspätet entschuldigt', Icons.schedule,
                      () => _onStatusChangedWithHaptic(AttendanceStatus.lateExcused)),
                if (onEditRegistrationFields != null)
                  option('Anmeldefelder bearbeiten', Icons.edit_outlined, onEditRegistrationFields!),
                if (showModifierInfo) ...[
                  option('Wer hat geändert?', Icons.info_outline, onShowModifierInfo),
                  option('Person entfernen', Icons.delete_outline, onRemoveFromAttendance,
                      destructive: true),
                ],
                if (onSendReminder != null)
                  option('Erinnerung senden', Icons.notifications_outlined, onSendReminder!),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Abbrechen', textAlign: TextAlign.center),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Trigger haptic feedback and change status
  void _onStatusChangedWithHaptic(AttendanceStatus newStatus) {
    HapticHelper.light();
    onStatusChanged(newStatus);
  }

  /// Ionic onAttChange: tap moves to the next status of the type's mapping.
  void _cycleStatus(BuildContext context) {
    final next = nextClickStatus(status, availableStatuses);
    if (next == null) {
      ToastHelper.showError(
        context,
        'Fehler beim Ändern des Anwesenheitsstatus, bitte versuche es später erneut',
      );
      return;
    }
    _onStatusChangedWithHaptic(next);
  }
}

/// Ionic `ion-select interface="popover"` with the status labels.
class _StatusSelect extends StatelessWidget {
  const _StatusSelect({
    required this.status,
    required this.options,
    required this.onChanged,
  });

  final AttendanceStatus status;
  final List<AttendanceStatus> options;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = options.contains(status) ? options : [status, ...options];
    return DropdownButtonHideUnderline(
      child: DropdownButton<AttendanceStatus>(
        value: status,
        isDense: true,
        alignment: AlignmentDirectional.centerEnd,
        items: [
          for (final s in items)
            DropdownMenuItem(value: s, child: Text(ionicStatusLabel(s))),
        ],
        onChanged: (s) {
          if (s != null && s != status) onChanged(s);
        },
      ),
    );
  }
}
