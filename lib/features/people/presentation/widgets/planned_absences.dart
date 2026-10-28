import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/player_absence/player_absence.dart';
import 'person_detail/upcoming_appointments_accordion.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

String _fmt(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  return d == null ? isoDate : _dateFormat.format(d);
}

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Toast text after entering an absence (Ionic: signout.absenceEntered[Count]).
String absenceEnteredMessage(int count) {
  if (count <= 0) return 'Abwesenheit eingetragen';
  return 'Abwesenheit eingetragen ($count ${count == 1 ? 'Termin' : 'Termine'} entschuldigt)';
}

/// Input of the "Abwesenheit eintragen" sheet.
class AbsenceInput {
  const AbsenceInput({
    required this.reason,
    required this.fromDate,
    required this.untilDate,
  });

  final String reason;

  /// YYYY-MM-DD
  final String fromDate;

  /// YYYY-MM-DD
  final String untilDate;
}

/// Shows the "Abwesenheit eintragen" sheet. Returns null when cancelled.
Future<AbsenceInput?> showAbsenceInputSheet(
  BuildContext context, {
  bool showLongAbsenceHint = false,
}) {
  return showModalBottomSheet<AbsenceInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _AbsenceInputSheet(showLongAbsenceHint: showLongAbsenceHint),
  );
}

class _AbsenceInputSheet extends StatefulWidget {
  const _AbsenceInputSheet({required this.showLongAbsenceHint});

  final bool showLongAbsenceHint;

  @override
  State<_AbsenceInputSheet> createState() => _AbsenceInputSheetState();
}

class _AbsenceInputSheetState extends State<_AbsenceInputSheet> {
  final _reasonController = TextEditingController();
  DateTime? _from;
  DateTime? _until;

  bool get _isValid =>
      _reasonController.text.trim().isNotEmpty && _from != null && _until != null;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDateRange: _from != null && _until != null
          ? DateTimeRange(start: _from!, end: _until!)
          : null,
      locale: const Locale('de', 'DE'),
      helpText: 'Zeitraum wählen',
      saveText: 'Übernehmen',
    );
    if (range != null) {
      setState(() {
        _from = range.start;
        _until = range.end;
      });
    }
  }

  void _submit() {
    if (!_isValid) {
      ToastHelper.showError(context, 'Bitte fülle alle Pflichtfelder aus');
      return;
    }
    Navigator.of(context).pop(AbsenceInput(
      reason: _reasonController.text.trim(),
      fromDate: _isoDay(_from!),
      untilDate: _isoDay(_until!),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: const Text('Abwesenheit eintragen'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: TextField(
                controller: _reasonController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Grund *',
                  hintText: 'z.B. Urlaub, Krankheit...',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Von *'),
              subtitle: Text(_from != null
                  ? _dateFormat.format(_from!)
                  : 'Kein Datum gewählt'),
              onTap: _pickRange,
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Bis *'),
              subtitle: Text(_until != null
                  ? _dateFormat.format(_until!)
                  : 'Kein Datum gewählt'),
              trailing: _from != null
                  ? IconButton(
                      icon: const Icon(Icons.cancel_outlined,
                          color: AppColors.medium),
                      onPressed: () => setState(() {
                        _from = null;
                        _until = null;
                      }),
                    )
                  : null,
              onTap: _pickRange,
            ),
            if (widget.showLongAbsenceHint)
              const Padding(
                padding: EdgeInsets.all(AppDimensions.paddingM),
                child: Text(
                  'Für längere Abwesenheiten empfiehlt sich die Pausieren-Funktion, '
                  'damit du nicht in neuen Terminen erscheinst.',
                  style: TextStyle(color: AppColors.warning),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: FilledButton.icon(
                onPressed: _isValid ? _submit : null,
                icon: const Icon(Icons.calendar_month),
                label: const Text('Abwesenheit eintragen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the sheet, stores the absence, excuses upcoming attendances and
/// shows the result toast. Returns true on success.
Future<bool> addPlannedAbsenceFlow(
  BuildContext context,
  WidgetRef ref, {
  required int personId,
  bool showLongAbsenceHint = false,
}) async {
  final input = await showAbsenceInputSheet(
    context,
    showLongAbsenceHint: showLongAbsenceHint,
  );
  if (input == null || !context.mounted) return false;

  final count = await ref.read(playerAbsenceNotifierProvider.notifier).addAbsence(
        personId: personId,
        fromDate: input.fromDate,
        untilDate: input.untilDate,
        reason: input.reason,
      );
  if (!context.mounted) return count != null;
  if (count == null) {
    ToastHelper.showError(context, 'Abwesenheit konnte nicht gespeichert werden');
    return false;
  }
  ref.invalidate(upcomingAttendancesProvider(personId));
  ToastHelper.showSuccess(context, absenceEnteredMessage(count));
  return true;
}

/// Confirms and deletes an absence (resets excused attendances).
Future<bool> deletePlannedAbsenceFlow(
  BuildContext context,
  WidgetRef ref,
  PlayerAbsence absence, {
  bool selfService = false,
}) async {
  final confirmed = await DialogHelper.showConfirmation(
    context,
    title: 'Abwesenheit löschen',
    message: selfService
        ? 'Soll die Abwesenheit gelöscht werden? Bereits entschuldigte Termine in '
            'diesem Zeitraum werden auf den Standardstatus des jeweiligen Termintyps '
            'zurückgesetzt.'
        : 'Soll die Abwesenheit gelöscht werden? Bereits entschuldigte Termine in '
            'diesem Zeitraum werden auf "Neutral" zurückgesetzt.',
    confirmText: 'Löschen',
    isDestructive: true,
  );
  if (!confirmed || !context.mounted) return false;

  final ok =
      await ref.read(playerAbsenceNotifierProvider.notifier).deleteAbsence(absence);
  if (!context.mounted) return ok;
  if (ok) {
    ref.invalidate(upcomingAttendancesProvider(absence.personId));
    ToastHelper.showSuccess(context, 'Abwesenheit gelöscht');
  } else {
    ToastHelper.showError(context, 'Abwesenheit konnte nicht gelöscht werden');
  }
  return ok;
}

/// One absence row: "dd.MM.yyyy – dd.MM.yyyy" + reason + delete button.
class PlannedAbsenceTile extends StatelessWidget {
  const PlannedAbsenceTile({
    super.key,
    required this.absence,
    required this.onDelete,
  });

  final PlayerAbsence absence;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('${_fmt(absence.fromDate)} – ${_fmt(absence.untilDate)}'),
      subtitle: absence.reason.isNotEmpty ? Text(absence.reason) : null,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
        tooltip: 'Abwesenheit löschen',
        onPressed: onDelete,
      ),
    );
  }
}

/// Person detail: "Abwesenheiten" accordion (Ionic person.page absences).
/// Only rendered when the current user may manage planned absences.
class PlannedAbsencesAccordion extends ConsumerStatefulWidget {
  const PlannedAbsencesAccordion({super.key, required this.personId});

  final int personId;

  @override
  ConsumerState<PlannedAbsencesAccordion> createState() =>
      _PlannedAbsencesAccordionState();
}

class _PlannedAbsencesAccordionState
    extends ConsumerState<PlannedAbsencesAccordion> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManagePlannedAbsencesProvider);
    if (!canManage) return const SizedBox.shrink();

    final absences =
        ref.watch(playerAbsencesByPersonIdProvider(widget.personId)).valueOrNull ??
            const <PlayerAbsence>[];

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              absences.isNotEmpty
                  ? 'Abwesenheiten (${absences.length})'
                  : 'Abwesenheiten',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
          if (_isExpanded) ...[
            for (final absence in absences)
              PlannedAbsenceTile(
                absence: absence,
                onDelete: () => deletePlannedAbsenceFlow(context, ref, absence),
              ),
            if (absences.isEmpty)
              const ListTile(
                title: Text(
                  'Keine Abwesenheiten eingetragen',
                  style: TextStyle(color: AppColors.medium),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              title: const Text(
                'Abwesenheit hinzufügen',
                style: TextStyle(color: AppColors.primary),
              ),
              onTap: () => addPlannedAbsenceFlow(
                context,
                ref,
                personId: widget.personId,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
