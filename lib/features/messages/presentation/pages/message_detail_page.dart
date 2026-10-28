import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/message_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/quill_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/message/message.dart';
import '../message_format.dart';

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

  bool get _isManager {
    final role = ref.watch(effectiveRoleProvider);
    return role.isAdmin || role.isResponsible;
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
      title: 'Mitteilung löschen?',
      message:
          'Die Mitteilung verschwindet auch bei allen Empfängern aus der App. '
          'Bereits versendete E-Mails bleiben bestehen.',
      confirmText: 'Löschen',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(messageNotifierProvider.notifier).delete(widget.messageId);
    if (!mounted) return;
    if (ok) {
      context.go('/settings/messages');
    } else {
      ToastHelper.showError(context, 'Fehler beim Löschen');
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
    final isManager = _isManager;
    final message = messageAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _back),
        title: const Text('Mitteilung'),
        actions: [
          if (isManager && message != null)
            IconButton(
              tooltip: 'Mitteilung löschen',
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: _delete,
            ),
        ],
      ),
      body: messageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Mitteilung konnte nicht geladen werden')),
        data: (message) {
          if (message == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.paddingL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.campaign_outlined, size: 48, color: AppColors.medium),
                    SizedBox(height: AppDimensions.paddingM),
                    Text(
                      'Diese Mitteilung gibt es nicht mehr oder du hast keinen Zugriff darauf.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
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
          return isManager ? RefreshIndicator(onRefresh: _refresh, child: list) : list;
        },
      ),
    );
  }

  Widget _managerHeader(Message message, bool showContent) {
    final theme = Theme.of(context);
    final meta = [
      MessageFormat.dateTime(message.createdAt),
      if (message.senderName != null && message.senderName!.isNotEmpty) message.senderName!,
      showContent ? 'Nachricht ausblenden' : 'Nachricht anzeigen',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: ListTile(
        title: Text(message.title, style: theme.textTheme.titleMedium),
        subtitle: Text(meta),
        trailing: Icon(
          showContent ? Icons.expand_less : Icons.expand_more,
          color: AppColors.medium,
        ),
        onTap: () => setState(() => _showContent = !showContent),
      ),
    );
  }

  List<Widget> _managerOverview(Message message) {
    final theme = Theme.of(context);
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

    Widget hint(String text) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingS,
        vertical: AppDimensions.paddingS,
      ),
      child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.medium)),
    );

    return [
      if (message.isSending) hint('Der Versand läuft noch. Ziehe nach unten, um zu aktualisieren.'),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingS,
          AppDimensions.paddingM,
          AppDimensions.paddingS,
          AppDimensions.paddingS,
        ),
        child: Text(
          'Übersicht',
          style: theme.textTheme.titleSmall?.copyWith(color: AppColors.medium),
        ),
      ),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppDimensions.paddingS,
        crossAxisSpacing: AppDimensions.paddingS,
        childAspectRatio: 2.2,
        children: [
          _Tile(value: '${stats.read} / ${stats.total}', label: 'in der App gelesen'),
          _Tile(
            value: '${stats.pushDelivered} / ${stats.pushTotal}',
            label: 'Push/Telegram zugestellt',
          ),
          _Tile(value: '${stats.emailDelivered} / ${stats.emailTotal}', label: 'E-Mail zugestellt'),
          _Tile(value: '≈ ${stats.emailOpened}', label: 'E-Mail geöffnet (ungefähr)'),
        ],
      ),
      hint(
        '„Geöffnet“ bei E-Mails ist ein Schätzwert: manche Mail-Apps laden Bilder '
        'vorab, andere blockieren sie.',
      ),
      const SizedBox(height: AppDimensions.paddingS),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<_Filter>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: _Filter.all, label: Text('Alle ${stats.total}')),
            ButtonSegment(value: _Filter.read, label: Text('Gelesen ${stats.readAny}')),
            ButtonSegment(value: _Filter.open, label: Text('Offen ${stats.open}')),
            ButtonSegment(value: _Filter.problems, label: Text('Probleme ${stats.problems}')),
          ],
          selected: {_filter},
          onSelectionChanged: (s) => setState(() => _filter = s.first),
        ),
      ),
      const SizedBox(height: AppDimensions.paddingM),
      if (recipientsAsync.isLoading && rows.isEmpty)
        const Center(child: CircularProgressIndicator())
      else if (filtered.isEmpty)
        hint('Keine Personen in dieser Ansicht.')
      else
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < filtered.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _RecipientRow(
                  recipient: filtered[i],
                  groupName: filtered[i].groupId != null ? groups[filtered[i].groupId] : null,
                ),
              ],
            ],
          ),
        ),
    ];
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingS),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.medium),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: recipient.name.isNotEmpty ? recipient.name : 'Unbekannt',
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _bg(c.tone),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    c.text,
                    style: theme.textTheme.labelSmall?.copyWith(color: _fg(c.tone)),
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
    final sender = (m.senderName != null && m.senderName!.isNotEmpty) ? m.senderName! : 'Unbekannt';
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showTitle) ...[
              Text(m.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Von $sender · ${MessageFormat.dateTime(m.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.medium),
              ),
              const SizedBox(height: AppDimensions.paddingM),
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
      ),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingS,
            AppDimensions.paddingM,
            AppDimensions.paddingS,
            AppDimensions.paddingS,
          ),
          child: Text(
            'Frühere Mitteilungen',
            style: theme.textTheme.titleSmall?.copyWith(color: AppColors.medium),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < earlier.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  title: Text(earlier[i].title),
                  subtitle: Text(MessageFormat.date(earlier[i].createdAt)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/messages/${earlier[i].id}'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
