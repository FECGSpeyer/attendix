import 'dart:async';

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/duty_providers.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/telegram_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/demo_guard.dart' show DemoModeException;
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../people/presentation/widgets/planned_absences.dart';
import '../../../redesign/presentation/widgets/members/rd_pause_sheets.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'
    show IonAccordionTile, IonButton, IonMdCalendar, IonMdDatetime;
import '../../../../shared/widgets/dialogs/ion_sheet.dart'
    show showIonSheet, IonSheetScaffold, IonCloseButton;
import '../../../../core/utils/error_message.dart';

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

/// PARITY_SELF: person_attendances that Ionic confirmAbsence/deleteAbsence
/// touch: the Termine "Meine Termine" lists as current + upcoming
/// (`currentAttendance` + `actualAttendances` after applyDutyView /
/// applyDutyLayout). Unassigned duties never count; in the Dienstplan view
/// the own duties stay untouched ("Weitere Termine" only). Termine of the
/// tenant without an own row ("alle Termine" mode) have no id and are
/// skipped. Waits for the duty overview (whether the Dienstplan view is
/// active) and throws when it fails, so the callers write nothing.
/// [useDutyView] overrides the Dienstplan view: the Beta passes false, it
/// lists own duties with the other Termine, so an absence covers them too.
Future<Set<String>> selfServiceAbsenceCandidateIds(WidgetRef ref, {bool? useDutyView}) async {
  final raw = await ref.read(signoutDataProvider.future);
  final dutyView = useDutyView ?? (await ref.read(myDutyOverviewProvider.future)).useDutyView;
  return absenceCandidates(raw, useDutyView: dutyView)
      .map((a) => a.id)
      .whereType<String>()
      .toSet();
}

/// "Abwesenheit melden" sheet + save (Ionic confirmAbsence).
Future<void> selfServiceReportAbsence(
  BuildContext context,
  WidgetRef ref,
  Person player, {
  required bool canSelfPause,
}) async {
  // SEL-11: Ionic absence modal – sheet [0, 0.92, 1] above the tab bar.
  final input = await showIonSheet<AbsenceInput>(
    context,
    breakpoints: const [0, 0.92, 1],
    initialBreakpoint: 0.92,
    builder: (_, scrollController) => SelfServiceAbsenceSheet(
      showLongAbsenceHint: canSelfPause,
      scrollController: scrollController,
    ),
  );
  if (input == null || !context.mounted) return;
  await saveSelfServiceAbsence(context, ref, player, input);
}

/// Saves an own absence and reports the outcome (shared by the absence
/// sheet and the new design's absence sheet).
Future<void> saveSelfServiceAbsence(
  BuildContext context,
  WidgetRef ref,
  Person player,
  AbsenceInput input, {
  bool? useDutyView,
}) async {
  if (player.id == null) return;
  // The write goes through the current group's repository: if the group
  // changes while the candidates load, the ids belong to the old group.
  final tenantId = ref.read(currentTenantIdProvider);
  final Set<String> onlyIds;
  try {
    onlyIds = await selfServiceAbsenceCandidateIds(ref, useDutyView: useDutyView);
    if (ref.read(currentTenantIdProvider) != tenantId) {
      throw StateError('Instanz während des Speicherns gewechselt');
    }
  } catch (_) {
    if (context.mounted) {
      ToastHelper.showError(context, context.l10n.signoutFlutterAbsenceSaveFailed);
    }
    return;
  }
  final count = await ref.read(playerAbsenceNotifierProvider.notifier).addAbsence(
        personId: player.id!,
        fromDate: input.fromDate,
        untilDate: input.untilDate,
        reason: input.reason,
        onlyIds: onlyIds,
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
  final repo = ref.read(playerRepositoryWithTenantProvider);
  final beta = RedesignRoutes.active;
  final boundTenantId = ref.read(currentTenantIdProvider);
  final ({String reason, DateTime? until})? result;
  if (beta) {
    // REDESIGN: the pause sheet of the new design without "Ab".
    final input = await showRdPauseSheet(
      context,
      title: context.l10n.signoutPause,
      hint: context.l10n.rdPeoplePauseSelfHint,
      withFrom: false,
      untilYears: 5,
    );
    result = input == null ? null : (reason: input.reason, until: input.until);
  } else {
    // SEL-10/SEL-11: Ionic pause modal – sheet [0, 0.75, 1] above the tab
    // bar (showIonSheet uses the root navigator).
    result = await showIonSheet<({String reason, DateTime? until})>(
      context,
      breakpoints: const [0, 0.75, 1],
      initialBreakpoint: 0.75,
      builder: (context, scrollController) =>
          _SelfPauseSheet(scrollController: scrollController),
    );
  }
  if (result == null || !context.mounted) return;
  // TENANT (Beta): nothing is written after a group change.
  if (beta && ref.read(currentTenantIdProvider) != boundTenantId) {
    ToastHelper.showError(context, context.l10n.rdPeopleGroupSwitched);
    return;
  }

  final untilIso = result.until == null ? null : DateFormat('yyyy-MM-dd').format(result.until!);
  final pauseText = result.until == null
      ? result.reason
      : '${result.reason} (bis ${DateFormat('dd.MM.yyyy').format(result.until!)})';

  try {
    await repo.pausePlayer(player, untilIso, pauseText);
    // LOGIC_SELF: Ionic confirmPause → telegramService.notifyPlayerPaused
    // (best-effort, the pause itself is saved).
    final tenantId = ref.read(currentTenantIdProvider);
    if (player.id != null && tenantId != null) {
      unawaited(ref
          .read(telegramServiceProvider)
          .notifyPlayerPaused(
            playerId: player.id!,
            tenantId: tenantId,
            reason: result.reason,
            pauseUntil: untilIso,
          )
          .catchError((_) {}));
    }
    _refreshAfterAbsenceChange(ref);
  } catch (e) {
    if (context.mounted) ToastHelper.showError(context, context.l10n.signoutFlutterError(friendlyErrorMessage(e)));
  }
}

/// "Pausierung beenden" alert (Ionic confirmUnpause).
Future<void> selfServiceUnpause(BuildContext context, WidgetRef ref, Person player) async {
  final repo = ref.read(playerRepositoryWithTenantProvider);
  final confirmed = await DialogHelper.showConfirmation(
    context,
    title: context.l10n.signoutEndPause,
    message: context.l10n.signoutEndPauseMessage,
    confirmText: context.l10n.signoutReactivate,
  );
  if (!confirmed || !context.mounted) return;
  try {
    await repo.unpausePlayer(player, historyText: 'Selbst reaktiviert');
    _refreshAfterAbsenceChange(ref);
  } catch (e) {
    if (context.mounted) ToastHelper.showError(context, context.l10n.signoutFlutterError(friendlyErrorMessage(e)));
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
      try {
        await repo.checkAndUnpausePlayers();
      } on DemoModeException {
        // Demo account: the guard already showed the demo hint; load anyway.
      }
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

    // UX_SONGS_SELF: Ionic ion-list inset with ion-list-header + items
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IonListHeader(context.l10n.signoutPlannedAbsences),
        IonInsetList(
          children: [
          for (final absence in absences)
            PlannedAbsenceTile(
              absence: absence,
              onDelete: () async {
                final ok = await deletePlannedAbsenceFlow(
                  context,
                  ref,
                  absence,
                  selfService: true,
                  // Own duties too, whatever the view: the reset only takes
                  // back Termine excused with this absence's reason, and an
                  // absence entered in the Beta or by the leadership also
                  // excused own duties.
                  onlyIds: () => selfServiceAbsenceCandidateIds(ref, useDutyView: false),
                );
                if (ok) _refreshAfterAbsenceChange(ref);
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// "Abwesenheit melden" sheet (Ionic signout absence modal): reason, then
/// start and end day tapped in one inline calendar.
class SelfServiceAbsenceSheet extends StatefulWidget {
  const SelfServiceAbsenceSheet({
    super.key,
    this.showLongAbsenceHint = false,
    this.scrollController,
  });

  final bool showLongAbsenceHint;

  /// The controller of the Ionic breakpoint sheet ([showIonSheet]); null =
  /// a plain content-sized sheet with its own header.
  final ScrollController? scrollController;

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
          Icon(AppIcons.calendarTodayOutlined, size: 18, color: AppColors.medium),
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
          Icon(AppIcons.calendarTodayOutlined, size: 18, color: AppColors.primary),
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
            icon: Icon(AppIcons.cancelOutlined, color: AppColors.medium),
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
    final content = <Widget>[
      // SEL-11: Ionic `ion-list [inset]` (margin-top 12) with one item:
      // stacked label + auto-growing `ion-textarea`.
      IonInsetList(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: _reasonController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: null,
              onChanged: (_) => setState(() {}),
              decoration: ionInputDecoration(
                context,
                label: context.l10n.signoutReasonRequired,
                hintText: context.l10n.signoutReasonPlaceholder,
              ),
            ),
          ),
        ],
      ),
      _rangeHeader(),
      _inlineCalendar(
        context,
        key: ValueKey(_calendarKey),
        initialDate: _until ?? _from ?? now,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 5),
        onPick: _onPick,
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
        child: IonButton(
          expand: true,
          icon: AppIcons.calendarTodayOutlined,
          label: context.l10n.signoutEnterAbsence,
          onPressed: _valid ? _confirm : null,
        ),
      ),
    ];
    final scrollController = widget.scrollController;
    if (scrollController != null) {
      return IonSheetScaffold(
        title: context.l10n.signoutReportAbsence,
        showClose: true,
        body: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: content,
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IonSheetHeader(
              title: context.l10n.signoutReportAbsence,
              end: [IonCloseButton(onPressed: () => Navigator.of(context).pop())],
            ),
            ...content,
          ],
        ),
      ),
    );
  }
}

/// SEL-03 (md part): the inline `ion-datetime presentation="date"` of the
/// absence / pause sheets. md look = the Ionic md calendar of stage 1
/// ([IonMdCalendar]); the iOS look keeps the calendar grid the app uses for
/// every iOS date card (the same one as `showAppDatePicker`).
Widget _inlineCalendar(
  BuildContext context, {
  Key? key,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required ValueChanged<DateTime> onPick,
}) {
  if (isIosLook(context)) {
    return CalendarDatePicker(
      key: key,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      onDateChanged: onPick,
    );
  }
  return SizedBox(
    key: key,
    height: IonMdDatetime.gridHeight,
    child: IonMdCalendar(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      onChanged: (d, {required bool byDay}) {
        if (byDay) onPick(d);
      },
    ),
  );
}

/// "Pausieren" sheet: reason (required) + optional end date.
///
/// SEL-10: Ionic pause modal content (`ion-content class="ion-padding"`):
/// `ion-item` with a stacked `ion-textarea rows=3`, an `ion-accordion` whose
/// header is an `ion-item color="light"` (end date + clear button) and whose
/// content is the calendar, then the warning block button.
class _SelfPauseSheet extends StatefulWidget {
  const _SelfPauseSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_SelfPauseSheet> createState() => _SelfPauseSheetState();
}

class _SelfPauseSheetState extends State<_SelfPauseSheet> {
  final _reasonController = TextEditingController();
  DateTime? _until;

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IonSheetScaffold(
      title: context.l10n.signoutPause,
      showClose: true,
      body: SingleChildScrollView(
        controller: widget.scrollController,
        padding: EdgeInsets.fromLTRB(16, 16, 16,
            16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: TextField(
                controller: _reasonController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
                decoration: ionInputDecoration(
                  context,
                  label: context.l10n.excuseReason,
                  hintText: context.l10n.signoutPauseReasonPlaceholder,
                ),
              ),
            ),
            // Ionic: accordion "Pausiert bis (optional)" with inline calendar
            IonAccordionTile(
              headerColor: dark ? AppColors.lightOnDark : AppColors.light,
              title: Text(context.l10n.signoutPausedUntil),
              subtitle: Text(_until != null
                  ? DateFormat(dateFmt()).format(_until!)
                  : context.l10n.signoutNoEndDate),
              trailing: _until == null
                  ? null
                  : IconButton(
                      icon: Icon(AppIcons.cancelOutlined,
                          color: AppColors.medium,
                          semanticLabel: context.l10n.commonRemove),
                      onPressed: () => setState(() => _until = null),
                    ),
              children: [
                _inlineCalendar(
                  context,
                  initialDate: _until ?? now,
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: DateTime(now.year + 5),
                  onPick: (d) => setState(() => _until = d),
                ),
              ],
            ),
            const SizedBox(height: 16),
            IonButton(
              // Ionic color="warning": black contrast text
              color: AppColors.warning,
              foregroundColor: Colors.black,
              expand: true,
              label: context.l10n.signoutConfirmPause,
              onPressed: _confirm,
            ),
          ],
        ),
      ),
    );
  }
}
