import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../l10n/l10n.dart';

/// Pending Players Page - shows self-registered members awaiting approval
/// BL-006: Converted to StatefulWidget to track processing state
class PendingPlayersPage extends ConsumerStatefulWidget {
  const PendingPlayersPage({super.key});

  @override
  ConsumerState<PendingPlayersPage> createState() => _PendingPlayersPageState();
}

class _PendingPlayersPageState extends ConsumerState<PendingPlayersPage> {
  // BL-006: Track IDs currently being processed to prevent double-clicks
  final Set<int> _processingIds = {};

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(realtimePendingPlayersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsPendingPersons),
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
                onPressed: () => ref.invalidate(realtimePendingPlayersProvider),
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
                  const Icon(Icons.people_outline, size: 80, color: AppColors.medium),
                  const SizedBox(height: AppDimensions.paddingL),
                  Text(
                    context.l10n.settingsFlutterPendingEmpty,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  Text(
                    context.l10n.settingsFlutterPendingEmptyHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.medium,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(realtimePendingPlayersProvider);
              await ref.read(realtimePendingPlayersProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                final isProcessing = player.id != null && _processingIds.contains(player.id);
                return _PendingPlayerItem(
                  player: player,
                  isProcessing: isProcessing,
                  onApprove: isProcessing ? null : () => _approvePlayer(player),
                  onDecline: isProcessing ? null : () => _declinePlayer(player),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _approvePlayer(Person player) async {
    final playerId = player.id;
    if (playerId == null) {
      ToastHelper.showError(context, context.l10n.settingsFlutterPendingInvalidId);
      return;
    }

    // BL-006: Guard against double-click
    if (_processingIds.contains(playerId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.settingsFlutterPendingApproveTitle),
        content: Text(context.l10n.settingsFlutterPendingApproveMessage(player.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.settingsFlutterPendingApprove),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processingIds.add(playerId));

    try {
      await ref.read(playerNotifierProvider.notifier).approvePlayer(player);

      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.settingsFlutterPendingApproved(player.fullName));
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(e));
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(playerId));
      }
    }
  }

  Future<void> _declinePlayer(Person player) async {
    final playerId = player.id;
    if (playerId == null) {
      ToastHelper.showError(context, context.l10n.settingsFlutterPendingInvalidId);
      return;
    }

    // BL-006: Guard against double-click
    if (_processingIds.contains(playerId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.settingsFlutterPendingDeclineTitle),
        content: Text(context.l10n.settingsFlutterPendingDeclineMessage(player.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.personDecline),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processingIds.add(playerId));

    try {
      await ref.read(playerNotifierProvider.notifier).declinePlayer(player, 'Abgelehnt');

      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.settingsFlutterPendingDeclined);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(e));
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(playerId));
      }
    }
  }
}

class _PendingPlayerItem extends StatelessWidget {
  const _PendingPlayerItem({
    required this.player,
    required this.isProcessing,
    required this.onApprove,
    required this.onDecline,
  });

  final Person player;
  final bool isProcessing;
  final VoidCallback? onApprove;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    // UX_PEOPLE: Ionic opens the person page in approve mode on tap
    // (duplicate check / merge + approve/decline sheet).
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
      onTap: player.id == null ? null : () => context.push('/people/${player.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                  child: Text(
                    player.initials,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.paddingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (player.email != null)
                        Text(
                          player.email!,
                          style: const TextStyle(fontSize: 12, color: AppColors.medium),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Additional info
            if (player.groupName != null || player.phone != null) ...[
              Wrap(
                spacing: AppDimensions.paddingM,
                runSpacing: AppDimensions.paddingXS,
                children: [
                  if (player.groupName != null)
                    _InfoChip(icon: Icons.piano, label: player.groupName!),
                  if (player.phone != null)
                    _InfoChip(icon: Icons.phone, label: player.phone!),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingM),
            ],

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isProcessing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: onDecline,
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(context.l10n.personDecline),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingS),
                  ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(context.l10n.settingsFlutterPendingApprove),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingS,
        vertical: AppDimensions.paddingXS,
      ),
      decoration: BoxDecoration(
        color: AppColors.medium.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.medium),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.medium)),
        ],
      ),
    );
  }
}
