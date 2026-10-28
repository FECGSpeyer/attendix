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
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)
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
      title: context.l10n.messagesDeleteConfirm,
      message: context.l10n.messagesDeleteHint,
      confirmText: context.l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed) return;
    final ok = await ref.read(messageNotifierProvider.notifier).delete(m.id);
    if (!ok && context.mounted) {
      ToastHelper.showError(context, context.l10n.messagesDeleteFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(messagesProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.messagesMessages)),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.messagesNewMessage,
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
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(l10n.messagesListLoadFailed)),
                ],
              ),
          data: (messages) {
            if (messages.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 48),
                  _MessagesEmptyState(onCompose: () => _compose(context)),
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
              // UX_SETTINGS (WAVE 8): message-list.page.html — list header
              // "Gesendet" + one inset list of sliding detail items.
              children: [
                SettingsListSection(
                  title: l10n.messagesSent,
                  icons: false,
                  children: [
                    for (final item in messages)
                      _MessageRow(
                        item: item,
                        onTap: () => context.push('/messages/${item.message.id}'),
                        onDelete: () => _delete(context, ref, item.message),
                      ),
                  ],
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
    final ios = ionIsIos(context);
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
          padding: ios
              ? const EdgeInsets.fromLTRB(
                  IonIos.itemPaddingStart, 10, IonIos.itemPaddingEnd, 10)
              : const EdgeInsets.all(AppDimensions.paddingM),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // h2 (600)
                    Text(
                      m.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: ios ? 16 : null,
                        fontWeight: FontWeight.w600,
                        letterSpacing: ios ? 0 : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // p
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: ios ? IonIos.labelP(context) : AppColors.medium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // .bar: 5px, radius 3, step-150 track, primary fill
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 5,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ColoredBox(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFF3A3A3C)
                                    : const Color(0xFFE3E3E8),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: (item.readPercent / 100).clamp(0.0, 1.0),
                              heightFactor: 1,
                              child: const ColoredBox(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // .meta: 0.8rem medium, tabular numbers
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.isSending
                                ? context.l10n.messagesSending
                                : context.l10n.messagesReadOf(item.stats.read, m.recipientCount),
                            style: const TextStyle(
                              fontSize: 12.8,
                              color: AppColors.medium,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        if (item.stats.problems > 0)
                          IonBadge(
                            text: MessageFormat.problems(item.stats.problems),
                            color: AppColors.warning,
                            textColor: Colors.black,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: ios ? 8 : AppDimensions.paddingS),
              ios
                  ? const IonDetailChevron()
                  : const Icon(Icons.chevron_right, color: AppColors.medium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ionic `.empty-state`: 88pt primary-tinted circle with the megaphone,
/// h2 1.25rem/600, medium hint, round "write first" button.
class _MessagesEmptyState extends StatelessWidget {
  const _MessagesEmptyState({required this.onCompose});

  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.campaign_outlined, size: 42, color: AppColors.primary),
          ),
          Text(
            l10n.messagesNone,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              l10n.messagesNoneHint,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.4, color: AppColors.medium),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
            onPressed: onCompose,
            icon: const Icon(Icons.edit_note),
            label: Text(l10n.messagesWriteFirst),
          ),
        ],
      ),
    );
  }
}
