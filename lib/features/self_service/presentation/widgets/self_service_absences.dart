import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../people/presentation/widgets/planned_absences.dart';
import '../../../../l10n/l10n.dart';

/// Self-service planned absences and self pause (Ionic signout page).
///
/// Entry points live where Ionic has them:
/// - pause / unpause: header button of "Meine Termine" ([selfServicePause],
///   [selfServiceUnpause])
/// - "Abwesenheit melden": greet tile ([selfServiceReportAbsence])
/// - "Geplante Abwesenheiten": inset list ([SelfServicePlannedAbsences])

void _refreshAfterAbsenceChange(WidgetRef ref) {
  ref.invalidate(signoutDataProvider);
  ref.invalidate(allPersonAttendancesAcrossTenantsProvider);
  ref.invalidate(currentSelfServicePlayerProvider);
}

/// "Abwesenheit melden" sheet + save (Ionic confirmAbsence).
Future<void> selfServiceReportAbsence(
  BuildContext context,
  WidgetRef ref,
  Person player, {
  required bool canSelfPause,
}) async {
  final input = await showModalBottomSheet<AbsenceInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SelfServiceAbsenceSheet(showLongAbsenceHint: canSelfPause),
  );
  if (input == null || !context.mounted || player.id == null) return;

  final count = await ref.read(playerAbsenceNotifierProvider.notifier).addAbsence(
        personId: player.id!,
        fromDate: input.fromDate,
        untilDate: input.untilDate,
        reason: input.reason,
      );
  if (!context.mounted) return;
  if (count == null) {
    ToastHelper.showError(context, context.l10n.signoutFlutterAbsenceSaveFailed);
    return;
  }
  _refreshAfterAbsenceChange(ref);
  ToastHelper.showSuccess(context, absenceEnteredMessage(count));
}

/// "Pausieren" sheet + save (Ionic openPauseModal / confirmPause).
Future<void> selfServicePause(BuildContext context, WidgetRef ref, Person player) async {
  final result = await showModalBottomSheet<({String reason, DateTime? until})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _SelfPauseSheet(),
  );
  if (result == null || !context.mounted) return;

  final untilIso = result.until == null ? null : DateFormat('yyyy-MM-dd').format(result.until!);
  final pauseText = result.until == null
      ? result.reason
      : '${result.reason} (bis ${DateFormat('dd.MM.yyyy').format(result.until!)})';

  try {
    final repo = ref.read(playerRepositoryWithTenantProvider);
    await repo.pausePlayer(player, untilIso, pauseText);
    _refreshAfterAbsenceChange(ref);
  } catch (e) {
    if (context.mounted) ToastHelper.showError(context, context.l10n.signoutFlutterError(e));
  }
}

/// "Pausierung beenden" alert (Ionic confirmUnpause).
Future<void> selfServiceUnpause(BuildContext context, WidgetRef ref, Person player) async {
  final confirmed = await DialogHelper.showConfirmation(
    context,
    title: context.l10n.signoutEndPause,
    message: context.l10n.signoutEndPauseMessage,
    confirmText: context.l10n.signoutReactivate,
  );
  if (!confirmed || !context.mounted) return;
  try {
    final repo = ref.read(playerRepositoryWithTenantProvider);
    await repo.unpausePlayer(player, historyText: 'Selbst reaktiviert');
    _refreshAfterAbsenceChange(ref);
  } catch (e) {
    if (context.mounted) ToastHelper.showError(context, context.l10n.signoutFlutterError(e));
  }
}

/// "Geplante Abwesenheiten" inset list with a trash button per entry.
///
/// Also lifts expired self pauses once (Ionic: checkAndUnpausePlayers on load
/// when self pause is allowed).
class SelfServicePlannedAbsences extends ConsumerStatefulWidget {
  const SelfServicePlannedAbsences({super.key});

  @override
  ConsumerState<SelfServicePlannedAbsences> createState() => _SelfServicePlannedAbsencesState();
}

class _SelfServicePlannedAbsencesState extends ConsumerState<SelfServicePlannedAbsences> {
  bool _unpauseChecked = false;

  void _maybeCheckUnpause(bool canSelfPause) {
    if (!canSelfPause || _unpauseChecked) return;
    _unpauseChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = ref.read(playerRepositoryWithTenantProvider);
      await repo.checkAndUnpausePlayers();
      if (mounted) ref.invalidate(currentSelfServicePlayerProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(currentSelfServicePlayerProvider).valueOrNull;
    if (player?.id == null) return const SizedBox.shrink();

    _maybeCheckUnpause(ref.watch(canSelfPauseProvider));
    if (!ref.watch(canSelfReportAbsenceProvider)) return const SizedBox.shrink();

    final absences =
        ref.watch(playerAbsencesByPersonIdProvider(player!.id!)).valueOrNull ?? const [];
    if (absences.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              context.l10n.signoutPlannedAbsences,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          for (final absence in absences)
            PlannedAbsenceTile(
              absence: absence,
              onDelete: () async {
                final ok = await deletePlannedAbsenceFlow(
                  context,
                  ref,
                  absence,
                  selfService: true,
                );
                if (ok) _refreshAfterAbsenceChange(ref);
              },
            ),
        ],
      ),
    );
  }
}

/// "Abwesenheit melden" sheet (Ionic signout absence modal): reason, then
/// start and end day tapped in one inline calendar.
class SelfServiceAbsenceSheet extends StatefulWidget {
  const SelfServiceAbsenceSheet({super.key, this.showLongAbsenceHint = false});

  final bool showLongAbsenceHint;

  @override
  State<SelfServiceAbsenceSheet> createState() => _SelfServiceAbsenceSheetState();
}

class _SelfServiceAbsenceSheetState extends State<SelfServiceAbsenceSheet> {
  final _reasonController = TextEditingController();
  DateTime? _from;
  DateTime? _until;
  int _calendarKey = 0;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  static String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// First tap: start; second tap: end (swapped when before start).
  void _onPick(DateTime date) {
    setState(() {
      if (_from == null || _until != null) {
        _from = date;
        _until = null;
      } else if (date.isBefore(_from!)) {
        _until = _from;
        _from = date;
      } else {
        _until = date;
      }
    });
  }

  void _reset() => setState(() {
        _from = null;
        _until = null;
        _calendarKey++;
      });

  bool get _valid =>
      _reasonController.text.trim().isNotEmpty && _from != null && _until != null;

  void _confirm() {
    if (!_valid) {
      ToastHelper.showError(context, context.l10n.signoutFillRequired);
      return;
    }
    Navigator.of(context).pop(AbsenceInput(
      reason: _reasonController.text.trim(),
      fromDate: _iso(_from!),
      untilDate: _iso(_until!),
    ));
  }

  Widget _rangeHeader() {
    final theme = Theme.of(context);
    final Widget content;
    if (_from == null || _until == null) {
      content = Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.medium),
          const SizedBox(width: 6),
          Text(
            _from == null ? context.l10n.signoutChooseStart : context.l10n.signoutChooseEnd,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.medium),
          ),
        ],
      );
    } else {
      content = Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${DateFormat(dateFmt(DateFmtKind.dayMonth)).format(_from!)} – ${DateFormat(dateFmt()).format(_until!)}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: AppColors.medium),
            tooltip: context.l10n.dateDialogReset,
            onPressed: _reset,
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: SizedBox(height: 40, child: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text(context.l10n.signoutReportAbsence),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.l10n.commonClose,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _reasonController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: context.l10n.signoutReasonRequired,
                    hintText: context.l10n.signoutReasonPlaceholder,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            _rangeHeader(),
            CalendarDatePicker(
              key: ValueKey(_calendarKey),
              initialDate: _until ?? _from ?? now,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 5),
              onDateChanged: _onPick,
            ),
            if (widget.showLongAbsenceHint)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  context.l10n.signoutLongAbsenceHint,
                  style: const TextStyle(color: AppColors.warningDark),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                onPressed: _valid ? _confirm : null,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(context.l10n.signoutEnterAbsence),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Pausieren" sheet: reason (required) + optional end date.
class _SelfPauseSheet extends StatefulWidget {
  const _SelfPauseSheet();

  @override
  State<_SelfPauseSheet> createState() => _SelfPauseSheetState();
}

class _SelfPauseSheetState extends State<_SelfPauseSheet> {
  final _reasonController = TextEditingController();
  DateTime? _until;
  bool _calendarOpen = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.signoutGiveReason);
      return;
    }
    Navigator.of(context).pop((reason: reason, until: _until));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text(context.l10n.signoutPause),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.l10n.commonClose,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: TextField(
                controller: _reasonController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: context.l10n.excuseReason,
                  hintText: context.l10n.signoutPauseReasonPlaceholder,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
            ),
            // Ionic: accordion "Pausiert bis (optional)" with inline calendar
            ListTile(
              tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              title: Text(context.l10n.signoutPausedUntil),
              subtitle: Text(_until != null
                  ? DateFormat(dateFmt()).format(_until!)
                  : context.l10n.signoutNoEndDate),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_until != null)
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.medium),
                      onPressed: () => setState(() => _until = null),
                    ),
                  Icon(_calendarOpen ? Icons.expand_less : Icons.expand_more),
                ],
              ),
              onTap: () => setState(() => _calendarOpen = !_calendarOpen),
            ),
            if (_calendarOpen)
              CalendarDatePicker(
                initialDate: _until ?? now,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: DateTime(now.year + 5),
                onDateChanged: (d) => setState(() => _until = d),
              ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
                onPressed: _confirm,
                child: Text(context.l10n.signoutConfirmPause),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
