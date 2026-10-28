import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';

/// Provider for left (archived) players using repository
final leftPlayersProvider = FutureProvider<List<Person>>((ref) async {
  final repository = ref.watch(playerRepositoryWithTenantProvider);
  if (!repository.hasTenantId) return [];
  return repository.getArchivedPlayers();
});

/// Left Players Page - shows archived/former members
class LeftPlayersPage extends ConsumerWidget {
  const LeftPlayersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(leftPlayersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsArchive),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: playersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text(context.l10n.settingsFlutterErrorDetail(e)),
              const SizedBox(height: AppDimensions.paddingM),
              ElevatedButton(
                onPressed: () => ref.invalidate(leftPlayersProvider),
                child: Text(context.l10n.messagesRetry),
              ),
            ],
          ),
        ),
        data: (players) {
          if (players.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_outlined, size: 80, color: AppColors.medium),
                  const SizedBox(height: AppDimensions.paddingL),
                  Text(
                    context.l10n.settingsNoArchived,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  Text(
                    context.l10n.settingsFlutterArchiveHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.medium),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            // FN-010: await provider.future to show spinner until data loads
            onRefresh: () async {
              ref.invalidate(leftPlayersProvider);
              await ref.read(leftPlayersProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                return _LeftPlayerItem(
                  player: player,
                  onReactivate: () => _reactivatePlayer(context, ref, player),
                  onViewDetails: () => context.push('/people/${player.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _reactivatePlayer(BuildContext context, WidgetRef ref, Person player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.peopleReactivateConfirm),
        content: Text(ctx.l10n.settingsFlutterReactivateMessage(player.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.signoutReactivate),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = ref.read(playerRepositoryWithTenantProvider);
        await repository.reactivatePlayer(player);

        ref.invalidate(leftPlayersProvider);
        ref.invalidate(realtimePlayersProvider);
        ref.invalidate(playersProvider);

        if (context.mounted) {
          ToastHelper.showSuccess(context, context.l10n.settingsFlutterReactivated(player.fullName));
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(e));
        }
      }
    }
  }
}

class _LeftPlayerItem extends StatelessWidget {
  const _LeftPlayerItem({
    required this.player,
    required this.onReactivate,
    required this.onViewDetails,
  });

  final Person player;
  final VoidCallback onReactivate;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      child: ListTile(
        onTap: onViewDetails,
        leading: CircleAvatar(
          backgroundColor: AppColors.medium.withValues(alpha: 0.2),
          child: Text(
            player.initials,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.medium,
            ),
          ),
        ),
        title: Text(
          player.fullName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (player.groupName != null)
              Text(
                player.groupName!,
                style: const TextStyle(fontSize: 12, color: AppColors.medium),
              ),
            if (player.left != null)
              Text(
                context.l10n.settingsLeftOn(_formatDate(player.left!)),
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.restore, color: AppColors.success),
          tooltip: context.l10n.signoutReactivate,
          onPressed: onReactivate,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return DateFormat(dateFmt()).format(date);
  }
}
