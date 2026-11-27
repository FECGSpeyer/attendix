import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/cross_tenant_person_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/repositories/cross_tenant_person_repository.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import 'members/rd_pause_sheets.dart';

final _fmt = DateFormat('dd.MM.yyyy');

/// Input of the "{name} Pausieren" sheet (Ionic people/person pause modal).
class PauseInput {
  const PauseInput({required this.reason, this.from, this.until});

  final String reason;

  /// "Pausiert ab (optional)" — today or earlier
  final DateTime? from;

  /// "Pausiert bis (optional)" — today or later
  final DateTime? until;
}

/// History text like Ionic confirmPause: "Grund (ab dd.MM.yyyy bis dd.MM.yyyy)".
String buildPauseHistoryText(String reason, {DateTime? from, DateTime? until}) {
  final segments = <String>[
    if (from != null) 'ab ${_fmt.format(from)}',
    if (until != null) 'bis ${_fmt.format(until)}',
  ];
  return segments.isEmpty ? reason : '$reason (${segments.join(' ')})';
}

/// Shows the pause sheet. Returns null when cancelled.
Future<PauseInput?> showPauseSheet(BuildContext context, Person person) {
  return showRdPauseSheet(
    context,
    title: context.l10n.rdPeoplePauseTitle('${person.firstName} ${person.lastName}'.trim()),
    hint: context.l10n.rdPeoplePauseHint,
  );
}

/// Full pause flow: sheet → pause → optionally
/// pause in other linked instances where the person's account is active.
/// Returns true when the person was paused.
Future<bool> pausePersonFlow(
  BuildContext context,
  WidgetRef ref,
  Person person, {
  bool showSuccessToast = true,
}) async {
  final repo = ref.read(playerRepositoryWithTenantProvider);
  final crossRepo = ref.read(crossTenantPersonRepositoryWithTenantProvider);
  final tenantId = ref.read(currentTenantIdProvider);
  final input = await showPauseSheet(context, person);
  if (input == null || !context.mounted) return false;
  // The group changed while the sheet was open, so write nothing.
  if (ref.read(currentTenantIdProvider) != tenantId) {
    ToastHelper.showError(context, context.l10n.rdPeopleGroupSwitched);
    return false;
  }

  // The root messenger outlives the sheet and this page.
  final toastContext = ScaffoldMessenger.of(context).context;
  final text = buildPauseHistoryText(input.reason,
      from: input.from, until: input.until);
  final until = input.until != null ? DateHelper.isoDay(input.until!) : null;
  final from = input.from != null ? DateHelper.isoDay(input.from!) : null;

  try {
    await repo.pausePlayer(person, until, text, pauseFrom: from);
  } catch (e) {
    if (toastContext.mounted) {
      ToastHelper.showError(
        toastContext,
        l10nWithoutContext.peopleFlutterErrorWith(friendlyErrorMessage(e)),
      );
    }
    return false;
  }

  // The Beta shows the same toast as after "Wieder aktiv" and "Archivieren"
  // (it had its own green bar at the bottom here).
  if (showSuccessToast && toastContext.mounted) {
    ToastHelper.showSuccess(
      toastContext,
      l10nWithoutContext.peopleFlutterPausedToast(person.firstName),
    );
  }

  final appId = person.appId;
  if (appId == null || !context.mounted) return true;

  // "Auch in anderen Instanzen pausieren?"
  try {
    final linkedIds = await ref.read(linkedTenantIdsProvider.future);
    if (linkedIds.isEmpty) return true;
    final memberOf =
        await crossRepo.getLinkedTenantsOfUser(appId, linkedTenantIds: linkedIds);
    // Only offer instances where the current user may pause people.
    final manageable = await crossRepo.getManageableTenantIds(
      memberOf.map((t) => t.id).toList(),
      linkedTenantIds: linkedIds,
    );
    final others =
        memberOf.where((t) => manageable.contains(t.id)).toList();
    if (others.isEmpty || !context.mounted) return true;

    final selected = await _askPauseInOtherTenants(context, person, others);
    if (selected == null || selected.isEmpty) return true;
    if (ref.read(currentTenantIdProvider) != tenantId) return true;

    final entry = {
      'date': DateTime.now().toUtc().toIso8601String(),
      'text': text,
      'type': PlayerHistoryType.paused.value,
    };
    for (final tenant in selected) {
      try {
        final otherId = await crossRepo.getPersonIdFromTenant(
          appId,
          tenant.id,
          linkedTenantIds: linkedIds,
        );
        if (otherId == null) continue;
        await crossRepo.pausePlayerInOtherTenant(
          playerId: otherId,
          tenantId: tenant.id,
          linkedTenantIds: linkedIds,
          historyEntry: entry,
          pausedUntil: until,
          pauseFrom: from,
        );
      } catch (e) {
        if (toastContext.mounted) {
          ToastHelper.showError(
            toastContext,
            l10nWithoutContext.peopleErrorAt(
                tenant.shortName.isNotEmpty ? tenant.shortName : tenant.name, e),
          );
        }
      }
    }
  } catch (_) {
    // Optional follow-up; the person itself is paused.
  }
  return true;
}

Future<List<LinkedTenantRef>?> _askPauseInOtherTenants(
  BuildContext context,
  Person person,
  List<LinkedTenantRef> tenants,
) {
  return showRdPauseOthersSheet(
    context,
    name: '${person.firstName} ${person.lastName}'.trim(),
    tenants: tenants,
  );
}
