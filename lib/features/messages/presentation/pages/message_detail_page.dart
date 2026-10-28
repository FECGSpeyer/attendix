import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/message_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/quill_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/message/message.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)
import '../message_format.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

enum _Filter { all, read, open, problems }

/// One Mitteilung (port of Ionic `MessageDetailPage`, route `/messages/:id`).
///
/// Every recipient sees the formatted message (opening it marks it read);
/// admins/responsibles additionally get the delivery and read overview.
class MessageDetailPage extends ConsumerStatefulWidget {
  const MessageDetailPage({super.key, required this.messageId});

  final String messageId;

  @override
  ConsumerState<MessageDetailPage> createState() => _MessageDetailPageState();
}

class _MessageDetailPageState extends ConsumerState<MessageDetailPage> {
  bool _markedRead = false;
  bool? _showContent;
  _Filter _filter = _Filter.all;

  bool _switchingTenant = false;

  bool get _isManager {
    final role = ref.watch(effectiveRoleProvider);
    return role.isAdmin || role.isResponsible;
  }

  /// Ionic message-detail load: a message of another instance of the user
  /// switches the current instance to it. Returns true while switching.
  bool _switchTenantIfNeeded(Message message) {
    final currentId = ref.read(currentTenantIdProvider);
    if (currentId == null || message.tenantId == currentId) return false;
    if (_switchingTenant) return true;
    final tenant = (ref.read(userTenantsProvider).valueOrNull ?? const <Tenant>[])
        .where((t) => t.id == message.tenantId)
        .firstOrNull;
    if (tenant == null) return false;
    _switchingTenant = true;
    Future.microtask(() async {
      try {
        await ref.read(currentTenantProvider.notifier).setTenant(tenant);
        await ref.read(currentTenantUserProvider.future);
      } catch (_) {
        // Stay on the current instance; the message is still shown.
      } finally {
        if (mounted) setState(() => _switchingTenant = false);
      }
    });
    return true;
  }

  void _markReadOnce() {
    if (_markedRead) return;
    _markedRead = true;
    Future.microtask(() => ref.read(messageNotifierProvider.notifier).markRead(widget.messageId));
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(_isManager ? '/settings/messages' : ref.read(effectiveRoleProvider).defaultRoute);
    }
  }

  Future<void> _delete() async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.messagesDeleteConfirm,
      message: context.l10n.messagesDeleteHint,
      confirmText: context.l10n.commonDelete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(messageNotifierProvider.notifier).delete(widget.messageId);
    if (!mounted) return;
    if (ok) {
      context.go('/settings/messages');
    } else {
      ToastHelper.showError(context, context.l10n.messagesDeleteFailed);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(messageRecipientsProvider(widget.messageId));
    ref.invalidate(messageByIdProvider(widget.messageId));
    await ref.read(messageByIdProvider(widget.messageId).future);
  }

  @override
  Widget build(BuildContext context) {
    final messageAsync = ref.watch(messageByIdProvider(widget.messageId));
    final message = messageAsync.valueOrNull;
    // Ionic: manager view only for messages of the current instance.
    final isManager = _isManager &&
        (message == null || message.tenantId == ref.watch(currentTenantIdProvider));
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _back),
        title: Text(l10n.messagesMessage),
        actions: [
          if (isManager && message != null)
            IconButton(
              tooltip: l10n.messagesDeleteMessage,
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: _delete,
            ),
        ],
      ),
      body: messageAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (e, _) => Center(child: Text(l10n.messagesLoadFailed)),
        data: (message) {
          if (message == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.campaign_outlined, size: 48, color: AppColors.medium),
                    const SizedBox(height: AppDimensions.paddingM),
                    Text(
                      l10n.messagesNotAvailable,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          if (_switchTenantIfNeeded(message)) {
            return const Center(child: AppSpinner());
          }
          _markReadOnce();
          final showContent = _showContent ?? !isManager;
          final children = <Widget>[
            if (isManager) _managerHeader(message, showContent),
            if (showContent) _MessageCard(message: message, showTitle: !isManager),
            if (isManager)
              ..._managerOverview(message)
            else
              _EarlierMessages(currentId: message.id),
          ];

          final list = ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            children: children,
          );
          return isManager ? RefreshIndicator.adaptive(onRefresh: _refresh, child: list) : list;
        },
      ),
    );
  }

  Widget _managerHeader(Message message, bool showContent) {
    final theme = Theme.of(context);
    final meta = [
      MessageFormat.dateTime(message.createdAt),
      if (message.senderName != null && message.senderName!.isNotEmpty) message.senderName!,
      showContent ? context.l10n.messagesFlutterHideMessage : context.l10n.messagesFlutterShowMessage,
    ].join(' · ');
    // UX_SETTINGS (WAVE 8): Ionic inset list item (h2.title 600, p meta,
    // chevron-up/down in medium at the end).
    final tile = ListTile(
      title: Text(
        message.title,
        style: ionIsIos(context)
            ? const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
            : theme.textTheme.titleMedium,
      ),
      subtitle: Text(meta),
      trailing: Icon(
        showContent ? Icons.expand_less : Icons.expand_more,
        color: AppColors.medium,
      ),
      onTap: () => setState(() => _showContent = !showContent),
    );
    if (ionIsIos(context)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: IonInsetGroup(children: [tile]),
      );
    }
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: tile,
    );
  }

  List<Widget> _managerOverview(Message message) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final recipientsAsync = ref.watch(messageRecipientsProvider(message.id));
    final groups = ref.watch(groupsMapProvider).valueOrNull ?? const <int, String>{};
    final rows = recipientsAsync.valueOrNull ?? const <MessageRecipient>[];
    final stats = RecipientOverview.from(rows);

    final filtered = switch (_filter) {
      _Filter.read => rows.where((r) => r.isRead).toList(),
      _Filter.open => rows.where((r) => !r.isRead).toList(),
      _Filter.problems => rows.where((r) => r.hasProblem).toList(),
      _Filter.all => rows,
    };

    // Ionic .hint: 0.78rem, line-height 1.4, medium, margin 8/20.
    Widget hint(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.medium),
      ),
    );

    return [
      if (message.isSending) hint(l10n.messagesStillSending),
      if (ionIsIos(context))
        IonListHeader(title: l10n.messagesOverview)
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingS,
            AppDimensions.paddingM,
            AppDimensions.paddingS,
            AppDimensions.paddingS,
          ),
          child: Text(
            l10n.messagesOverview,
            style: theme.textTheme.titleSmall?.copyWith(color: AppColors.medium),
          ),
        ),
      // Ionic .tiles: 2-column grid, gap 8, left-aligned value + label.
      _TileRow(
        left: _Tile(value: '${stats.read} / ${stats.total}', label: l10n.messagesReadInApp),
        right: _Tile(
          value: '${stats.pushDelivered} / ${stats.pushTotal}',
          label: l10n.messagesPushDelivered,
        ),
      ),
      const SizedBox(height: 8),
      _TileRow(
        left: _Tile(value: '${stats.emailDelivered} / ${stats.emailTotal}', label: l10n.messagesEmailDelivered),
        right: _Tile(value: '≈ ${stats.emailOpened}', label: l10n.messagesEmailOpenedApprox),
      ),
      hint(l10n.messagesOpenedEstimate),
      const SizedBox(height: AppDimensions.paddingS),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: AppSegmentedButton<_Filter>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: _Filter.all, label: Text(l10n.messagesAllCount(stats.total))),
            ButtonSegment(value: _Filter.read, label: Text(l10n.messagesReadCount(stats.readAny))),
            ButtonSegment(value: _Filter.open, label: Text(l10n.messagesOpenCount(stats.open))),
            ButtonSegment(value: _Filter.problems, label: Text(l10n.messagesProblemsCount(stats.problems))),
          ],
          selected: {_filter},
          onSelectionChanged: (s) => setState(() => _filter = s.first),
        ),
      ),
      const SizedBox(height: AppDimensions.paddingM),
      if (recipientsAsync.isLoading && rows.isEmpty)
        const Center(child: AppSpinner())
      else if (filtered.isEmpty)
        hint(l10n.messagesNoPeopleView)
      else
        SettingsListSection(
          icons: false,
          children: [
            for (final r in filtered)
              _RecipientRow(
                recipient: r,
                groupName: r.groupId != null ? groups[r.groupId] : null,
              ),
          ],
        ),
    ];
  }
}

class _TileRow extends StatelessWidget {
  const _TileRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 8),
          Expanded(child: right),
        ],
      ),
    );
  }
}

/// Ionic `.tile`: item-background box, radius 10, padding 10/12, value
/// 1.35rem tabular, 0.75rem medium label.
class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 21.6,
              height: 1.15,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: AppColors.medium),
          ),
        ],
      ),
    );
    if (!ios) {
      return Card(margin: EdgeInsets.zero, child: content);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: IonIos.itemBackground(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: content,
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({required this.recipient, this.groupName});

  final MessageRecipient recipient;
  final String? groupName;

  Color _bg(ChipTone tone) => switch (tone) {
    ChipTone.ok => AppColors.success.withValues(alpha: 0.15),
    ChipTone.bad => AppColors.danger.withValues(alpha: 0.15),
    ChipTone.warn => AppColors.warning.withValues(alpha: 0.2),
    ChipTone.neutral => AppColors.medium.withValues(alpha: 0.15),
  };

  Color _fg(ChipTone tone) => switch (tone) {
    ChipTone.ok => AppColors.successDark,
    ChipTone.bad => AppColors.dangerDark,
    ChipTone.warn => AppColors.warningDark,
    ChipTone.neutral => AppColors.medium,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = recipientChips(recipient);
    return Padding(
      padding: ionIsIos(context)
          ? const EdgeInsets.fromLTRB(16, 10, 18, 10)
          : const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: recipient.name.isNotEmpty ? recipient.name : context.l10n.commonUnknown,
                  style: theme.textTheme.titleSmall,
                ),
                if (groupName != null && groupName!.isNotEmpty)
                  TextSpan(
                    text: '  $groupName',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.medium),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final c in chips)
                // Ionic .chip: radius 4, padding 1/7, 0.72rem
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: _bg(c.tone),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    c.text,
                    style: TextStyle(fontSize: 11.5, color: _fg(c.tone)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The formatted message body (server-rendered allowlisted HTML).
class _MessageCard extends StatefulWidget {
  const _MessageCard({required this.message, required this.showTitle});

  final Message message;
  final bool showTitle;

  @override
  State<_MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<_MessageCard> {
  late QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _build();
  }

  @override
  void didUpdateWidget(covariant _MessageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.bodyHtml != widget.message.bodyHtml) {
      _controller.dispose();
      _controller = _build();
    }
  }

  QuillController _build() => QuillController(
    document: QuillUtils.documentFromNotesString(
      widget.message.bodyHtml.isNotEmpty ? widget.message.bodyHtml : widget.message.bodyText,
    ),
    selection: const TextSelection.collapsed(offset: 0),
    readOnly: true,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.message;
    final sender = (m.senderName != null && m.senderName!.isNotEmpty) ? m.senderName! : context.l10n.commonUnknown;
    final ios = ionIsIos(context);
    // UX_SETTINGS (WAVE 8): Ionic .message-card — item background, radius
    // 10, padding 16; h1 1.3rem/700, .from 0.8rem medium (margin 14).
    final body = Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showTitle) ...[
              Text(
                m.title,
                style: ios
                    ? const TextStyle(fontSize: 20.8, fontWeight: FontWeight.w700)
                    : theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.messagesFrom(sender, MessageFormat.dateTime(m.createdAt)),
                style: ios
                    ? const TextStyle(fontSize: 12.8, color: AppColors.medium)
                    : theme.textTheme.bodySmall?.copyWith(color: AppColors.medium),
              ),
              SizedBox(height: ios ? 14 : AppDimensions.paddingM),
            ],
            QuillEditor.basic(
              controller: _controller,
              config: QuillEditorConfig(
                showCursor: false,
                scrollable: false,
                onLaunchUrl: _openLink,
              ),
            ),
          ],
        ),
      );
    if (!ios) {
      return Card(
        margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
        child: body,
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: IonIos.itemBackground(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: body,
    );
  }
}

/// "Frühere Mitteilungen" for recipients.
class _EarlierMessages extends ConsumerWidget {
  const _EarlierMessages({required this.currentId});

  final String currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earlier =
        (ref.watch(receivedMessagesProvider).valueOrNull ?? const <Message>[])
            .where((m) => m.id != currentId)
            .take(5)
            .toList();
    if (earlier.isEmpty) return const SizedBox.shrink();
    // UX_SETTINGS (WAVE 8): list header + inset list of detail items.
    return SettingsListSection(
      title: context.l10n.messagesEarlier,
      icons: false,
      children: [
        for (final m in earlier)
          SettingsListTile(
            title: m.title,
            subtitle: MessageFormat.date(m.createdAt),
            onTap: () => context.push('/messages/${m.id}'),
          ),
      ],
    );
  }
}
