import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/duty_providers.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/telegram_service.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';
import '../../../people/presentation/widgets/planned_absences.dart';
import '../../../redesign/presentation/widgets/members/rd_pause_sheets.dart';

/// Self-service planned absences and self pause actions.

void _refreshAfterAbsenceChange(WidgetRef ref) {
  ref.invalidate(signoutDataProvider);
  ref.invalidate(allPersonAttendancesAcrossTenantsProvider);
  ref.invalidate(currentSelfServicePlayerProvider);
}

/// Candidate attendance IDs touched by self-service absence actions.
Future<Set<String>> selfServiceAbsenceCandidateIds(WidgetRef ref, {bool? useDutyView}) async {
  final raw = await ref.read(signoutDataProvider.future);
  final dutyView = useDutyView ?? (await ref.read(myDutyOverviewProvider.future)).useDutyView;
  return absenceCandidates(raw, useDutyView: dutyView)
      .map((a) => a.id)
      .whereType<String>()
      .toSet();
}

/// Saves an own absence and reports the outcome.
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

/// "Pausieren" sheet + save.
Future<void> selfServicePause(BuildContext context, WidgetRef ref, Person player) async {
  final repo = ref.read(playerRepositoryWithTenantProvider);
  final boundTenantId = ref.read(currentTenantIdProvider);
  final input = await showRdPauseSheet(
    context,
    title: context.l10n.signoutPause,
    hint: context.l10n.rdPeoplePauseSelfHint,
    withFrom: false,
    untilYears: 5,
  );
  if (input == null || !context.mounted) return;
  // Nothing is written after a group change while the sheet was open.
  if (ref.read(currentTenantIdProvider) != boundTenantId) {
    ToastHelper.showError(context, context.l10n.rdPeopleGroupSwitched);
    return;
  }

  final untilIso = input.until == null ? null : DateFormat('yyyy-MM-dd').format(input.until!);
  final pauseText = input.until == null
      ? input.reason
      : '${input.reason} (bis ${DateFormat('dd.MM.yyyy').format(input.until!)})';

  try {
    await repo.pausePlayer(player, untilIso, pauseText);
    // LOGIC_SELF: confirmPause → telegramService.notifyPlayerPaused (best-effort).
    final tenantId = ref.read(currentTenantIdProvider);
    if (player.id != null && tenantId != null) {
      unawaited(ref
          .read(telegramServiceProvider)
          .notifyPlayerPaused(
            playerId: player.id!,
            tenantId: tenantId,
            reason: input.reason,
            pauseUntil: untilIso,
          )
          .catchError((_) {}));
    }
    _refreshAfterAbsenceChange(ref);
  } catch (e) {
    if (context.mounted) ToastHelper.showError(context, context.l10n.signoutFlutterError(friendlyErrorMessage(e)));
  }
}

/// "Pausierung beenden" alert.
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
