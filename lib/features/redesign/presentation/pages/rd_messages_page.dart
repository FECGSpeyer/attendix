import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/auto_message_providers.dart';
import '../../../../core/providers/message_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../data/models/message/message.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/event/rd_event_head.dart' show rdEventMeta;
import '../widgets/manage/rd_manage_list.dart';

/// REDESIGN: Verwaltung › Mitteilungen in the template "Verwaltungsliste"
/// (replaces `/settings/messages` while the Beta is on; canvas K1). The
/// automatic messages as first row, then the sent messages with their read
/// status and problems. "+" opens "Mitteilung schreiben" and then the new
/// message; deleting sits in the message under "•••".
class RdMessagesPage extends ConsumerWidget {
  const RdMessagesPage({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, String id) async {
    await context.push('/messages/$id');
    // Like the old list: read counts and "wird gesendet" refresh on return.
    if (context.mounted) ref.invalidate(messagesProvider);
  }

  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    final id = await context.push<String>(RedesignRoutes.compose);
    if (!context.mounted) return;
    ref.invalidate(messagesProvider);
    if (id != null) await _open(context, ref, id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(messagesProvider);
    final messages = async.valueOrNull;
    final active = ref.watch(activeAutoMessageRulesCountProvider).valueOrNull;

    Future<void> refresh() async {
      ref.invalidate(autoMessageRulesProvider);
      ref.invalidate(messagesProvider);
      await ref.read(messagesProvider.future).catchError((_) => const <MessageWithStats>[]);
    }

    return RdManageListPage(
      title: l10n.messagesMessages,
      intro: l10n.redesignMessagesIntro,
      // The automatic messages row is always there, so "nothing sent yet"
      // is a note instead of the empty card.
      notice: messages != null && messages.isEmpty ? l10n.messagesNoneHint : null,
      sections:
          messages == null
              ? null
              : [
                RdManageListSection(
                  key: 'auto',
                  items: [
                    RdManageListItem(
                      id: 'auto-messages',
                      title: l10n.messagesAutoEntry,
                      icon: Icons.timer_outlined,
                      subtitle: active == null ? null : l10n.messagesAutoActive(active),
                      onTap: () => context.push('/settings/auto-messages'),
                    ),
                  ],
                ),
                RdManageListSection(
                  key: 'sent',
                  title: messages.isEmpty ? null : l10n.messagesSent,
                  items: [
                    for (final item in messages)
                      RdManageListItem(
                        id: item.message.id,
                        title: item.message.title,
                        icon: Icons.mail_outline,
                        subtitle: rdMessageRowMeta(l10n, item),
                        count: item.stats.problems > 0 ? l10n.messagesFlutterProblems(item.stats.problems) : null,
                        countWarn: item.stats.problems > 0,
                        onTap: () => _open(context, ref, item.message.id),
                      ),
                  ],
                ),
              ],
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(messagesProvider),
      emptyText: l10n.messagesNoneHint,
      emptyIcon: Icons.mail_outline,
      addLabel: l10n.messagesNewMessage,
      onAdd: () => _compose(context, ref),
      onRefresh: refresh,
    );
  }
}

/// "Mo 3. Nov · Leon · 24 von 38 gelesen" (or "Versand läuft …").
String rdMessageRowMeta(AppLocalizations l10n, MessageWithStats item) {
  final m = item.message;
  final created = m.createdAt?.toLocal();
  return [
    if (created != null) rdEventMeta(created),
    if (m.senderName != null && m.senderName!.isNotEmpty) m.senderName!,
    m.isSending ? l10n.messagesSending : l10n.messagesReadOf(item.stats.read, m.recipientCount),
  ].join(' · ');
}
