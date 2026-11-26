import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/tenant_providers.dart';
import '../../../core/providers/user_registration_providers.dart';
import '../../../core/utils/dialog_helper.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../data/models/person/person.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/adaptive/adaptive.dart';

/// Persons of [players] only while the list is settled and every entry belongs
/// to [tenantId]; otherwise empty (prevents stale cross-tenant flash during switch).
List<Person> playersOfCurrentTenant(
  AsyncValue<List<Person>> players,
  int? tenantId,
) {
  if (tenantId == null || players.isLoading || players.hasError) return const [];
  final list = players.valueOrNull ?? const <Person>[];
  if (list.any((p) => p.tenantId != tenantId)) return const [];
  return list;
}

/// Shows confirmation and batch-creates accounts for all [players] without an
/// account in the current tenant.
Future<void> createMissingAccounts(
  BuildContext context,
  WidgetRef ref,
  List<Person> players,
) async {
  final l10n = context.l10n;
  final tenantId = ref.read(currentTenantIdProvider);
  if (tenantId == null || players.any((p) => p.tenantId != tenantId)) {
    ToastHelper.showError(
      context,
      l10n.settingsCreateAccountsFailed(l10n.coreFlutterRepoPersonsNotInTenant),
    );
    return;
  }
  final confirmed = await DialogHelper.showConfirmation(
    context,
    title: l10n.settingsCreateAccounts,
    message: l10n.settingsCreateAccountsMessage(
      players.map((p) => '${p.firstName} ${p.lastName}').join(', '),
    ),
    confirmText: l10n.settingsContinue,
    cancelText: l10n.commonCancel,
  );
  if (!confirmed || !context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: AppSpinner()),
    ),
  );
  final AccountCreationResult result;
  try {
    result = await ref
        .read(accountCreationNotifierProvider.notifier)
        .createAccounts(players, stopOnError: true, expectedTenantId: tenantId);
  } finally {
    navigator.pop();
  }
  if (!context.mounted) return;
  if (result.hasErrors) {
    ToastHelper.showError(
      context,
      l10n.settingsCreateAccountsFailed(result.errors.first),
    );
  } else {
    ToastHelper.showSuccess(context, l10n.settingsAccountsCreated);
  }
}
