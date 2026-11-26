import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/group_providers.dart';
import '../../../core/providers/player_providers.dart';
import '../../../core/providers/realtime_providers.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../data/models/person/person.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/adaptive/adaptive.dart';
import '../../people/people_list_utils.dart' show sortPeopleByGroup;

/// Provider for left (archived) players using repository.
final leftPlayersProvider = FutureProvider<List<Person>>((ref) async {
  final repository = ref.watch(playerRepositoryWithTenantProvider);
  if (!repository.hasTenantId) return [];
  final players = await repository.getArchivedPlayers();
  final groups = await ref.watch(groupsProvider.future);
  final names = {for (final g in groups) g.id: g.name};
  return sortPeopleByGroup([
    for (final p in players)
      p.copyWith(groupName: p.instrument == null ? null : names[p.instrument]),
  ], groups);
});

/// Restores an archived [player] after confirmation.
Future<void> reactivatePersonWithConfirmation(
  BuildContext context,
  WidgetRef ref,
  Person player,
) async {
  final repository = ref.read(playerRepositoryWithTenantProvider);
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(ctx.l10n.rdTextRestoreTitle(player.fullName)),
      content: Text(ctx.l10n.rdTextRestoreMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(ctx.l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ctx.l10n.redesignArchiveListRestore),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    try {
      await repository.reactivatePlayer(player);

      ref.invalidate(leftPlayersProvider);
      ref.invalidate(realtimePlayersProvider);
      ref.invalidate(playersProvider);

      if (context.mounted) {
        ToastHelper.showSuccess(
          context,
          context.l10n.rdTextRestoreDone(player.fullName),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(
          context,
          context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e)),
        );
      }
    }
  }
}
