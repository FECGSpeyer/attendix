import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/message_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/message/message.dart';
import '../../../../shared/widgets/common/empty_state.dart';
import '../message_format.dart';
import 'message_compose_page.dart';

/// Mitteilungen overview for admins/responsibles: all sent messages of the tenant.
/// Port of Ionic `MessageListPage` (route `/settings/messages`).
class MessageListPage extends ConsumerWidget {
  const MessageListPage({super.key});

  Future<void> _compose(BuildContext context) async {
    final id = await openMessageCompose(context);
    if (id != null && context.mounted) {
      context.push('/messages/$id');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Message m) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Mitteilung löschen?',
      message:
          'Die Mitteilung verschwindet auch bei allen Empfängern aus der App. '
          'Bereits versendete E-Mails bleiben bestehen.',
      confirmText: 'Löschen',
      isDestructive: true,
    );
    if (!confirmed) return;
    final ok = await ref.read(messageNotifierProvider.notifier).delete(m.id);
    if (!ok && context.mounted) {
      ToastHelper.showError(context, 'Fehler beim Löschen');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(messagesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mitteilungen')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Neue Mitteilung',
        onPressed: () => _compose(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(messagesProvider.future),
        child: messagesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (e, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Mitteilungen konnten nicht geladen werden')),
                ],
              ),
          data: (messages) {
            if (messages.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 48),
                  EmptyStateWidget(
                    icon: Icons.campaign_outlined,
                    title: 'Noch keine Mitteilungen',
                    subtitle:
                        'Informiere deine Gruppe mit einer Mitteilung und sieh direkt, '
                        'wer sie schon gelesen hat.',
                    actionLabel: 'Erste Mitteilung schreiben',
                    onAction: () => _compose(context),
                  ),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM,
                AppDimensions.paddingM,
                AppDimensions.paddingM,
                96,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.paddingS,
                    bottom: AppDimensions.paddingS,
                  ),
                  child: Text(
                    'Gesendet',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: AppColors.medium),
                  ),
                ),
                Card(
                  clipBehavior: Clip.antiAlias,
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < messages.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _MessageRow(
                          item: messages[i],
                          onTap: () => context.push('/messages/${messages[i].message.id}'),
                          onDelete: () => _delete(context, ref, messages[i].message),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.item, required this.onTap, required this.onDelete});

  final MessageWithStats item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final m = item.message;
    final theme = Theme.of(context);
    final subtitle = [
      MessageFormat.date(m.createdAt),
      if (m.senderName != null && m.senderName!.isNotEmpty) m.senderName!,
      MessageFormat.toPeople(m.recipientCount),
    ].join(' · ');

    return Slidable(
      key: ValueKey(m.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.medium),
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: item.readPercent / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.medium.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(AppColors.success),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.isSending
                                ? 'Versand läuft …'
                                : '${item.stats.read} von ${m.recipientCount} gelesen',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        if (item.stats.problems > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              MessageFormat.problems(item.stats.problems),
                              style: theme.textTheme.labelSmall?.copyWith(color: Colors.black),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.paddingS),
              const Icon(Icons.chevron_right, color: AppColors.medium),
            ],
          ),
        ),
      ),
    );
  }
}
