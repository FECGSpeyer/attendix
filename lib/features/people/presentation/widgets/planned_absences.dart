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
import '../../../../core/utils/date_helper.dart';
import '../../../../l10n/l10n.dart';
import 'ion/ion_widgets.dart';

DateFormat get _dateFormat => DateFormat(dateFmt());

String _fmt(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  return d == null ? isoDate : _dateFormat.format(d);
}

/// Toast text after entering an absence (Ionic: signout.absenceEntered[Count]).
String absenceEnteredMessage(int count) {
  if (count <= 0) return l10nWithoutContext.signoutAbsenceEntered;
  return l10nWithoutContext.signoutAbsenceEnteredCount(count);
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
  bool forOther = false,
}) {
  return showModalBottomSheet<AbsenceInput>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _AbsenceInputSheet(
          showLongAbsenceHint: showLongAbsenceHint,
          forOther: forOther,
        ),
  );
}

class _AbsenceInputSheet extends StatefulWidget {
  const _AbsenceInputSheet({
    required this.showLongAbsenceHint,
    this.forOther = false,
  });

  final bool showLongAbsenceHint;

  /// Admin enters the absence for another person (Ionic person.longAbsenceHint)
  final bool forOther;

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
      locale: Locale(currentLanguage()),
      helpText: context.l10n.personFlutterChooseRange,
      saveText: context.l10n.commonApply,
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
      ToastHelper.showError(context, context.l10n.signoutFillRequired);
      return;
    }
    Navigator.of(context).pop(AbsenceInput(
      reason: _reasonController.text.trim(),
      fromDate: DateHelper.isoDay(_from!),
      untilDate: DateHelper.isoDay(_until!),
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
              title: Text(context.l10n.personEnterAbsence),
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
                decoration: InputDecoration(
                  labelText: context.l10n.signoutReasonRequired,
                  hintText: context.l10n.signoutReasonPlaceholder,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: Text(context.l10n.personFromRequired),
              subtitle: Text(_from != null
                  ? _dateFormat.format(_from!)
                  : context.l10n.personNoDateChosen),
              onTap: _pickRange,
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: Text(context.l10n.personUntilRequired),
              subtitle: Text(_until != null
                  ? _dateFormat.format(_until!)
                  : context.l10n.personNoDateChosen),
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
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Text(
                  widget.forOther
                      ? context.l10n.personLongAbsenceHint
                      : context.l10n.signoutLongAbsenceHint,
                  style: const TextStyle(color: AppColors.warning),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: FilledButton.icon(
                onPressed: _isValid ? _submit : null,
                icon: const Icon(Icons.calendar_month),
                label: Text(context.l10n.personEnterAbsence),
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
  bool forOther = false,
}) async {
  final input = await showAbsenceInputSheet(
    context,
    showLongAbsenceHint: showLongAbsenceHint,
    forOther: forOther,
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
    ToastHelper.showError(context, context.l10n.personFlutterAbsenceSaveFailed);
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
    title: context.l10n.signoutDeleteAbsence,
    message: selfService
        ? context.l10n.signoutDeleteAbsenceMessage
        : context.l10n.personDeleteAbsenceMessage,
    confirmText: context.l10n.commonDelete,
    isDestructive: true,
  );
  if (!confirmed || !context.mounted) return false;

  final ok =
      await ref.read(playerAbsenceNotifierProvider.notifier).deleteAbsence(absence);
  if (!context.mounted) return ok;
  if (ok) {
    ref.invalidate(upcomingAttendancesProvider(absence.personId));
    ToastHelper.showSuccess(context, context.l10n.signoutAbsenceDeleted);
  } else {
    ToastHelper.showError(context, context.l10n.personFlutterAbsenceDeleteFailed);
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
        tooltip: context.l10n.signoutDeleteAbsence,
        onPressed: onDelete,
      ),
    );
  }
}

/// Person detail: "Abwesenheiten" accordion (Ionic person.page absences).
/// Only rendered when the current user may manage planned absences.
class PlannedAbsencesAccordion extends ConsumerStatefulWidget {
  const PlannedAbsencesAccordion({
    super.key,
    required this.personId,
    this.extra = const [],
  });

  final int personId;

  /// UX_PEOPLE: further items at the end of the list (Ionic: "Regelmäßig
  /// verhindert" when the tenant uses duty types).
  final List<Widget> extra;

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

    return IonAccordion(
      title: absences.isNotEmpty
                  ? context.l10n.personAbsencesCount(absences.length)
                  : context.l10n.personAbsences,
      expanded: _isExpanded,
      onToggle: () => setState(() => _isExpanded = !_isExpanded),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final absence in absences)
              PlannedAbsenceTile(
                absence: absence,
                onDelete: () => deletePlannedAbsenceFlow(context, ref, absence),
              ),
            if (absences.isEmpty)
              ListTile(
                title: Text(
                  context.l10n.personNoAbsences,
                  style: const TextStyle(color: AppColors.medium),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              title: Text(
                context.l10n.personAddAbsence,
                style: const TextStyle(color: AppColors.primary),
              ),
              onTap: () => addPlannedAbsenceFlow(
                context,
                ref,
                personId: widget.personId,
                showLongAbsenceHint: true,
                forOther: true,
              ),
            ),
            ...widget.extra,
          ],
      ),
    );
  }
}
