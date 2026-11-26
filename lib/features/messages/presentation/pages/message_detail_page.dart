import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/auto_message_providers.dart';
import '../../../../core/providers/debug_providers.dart' show effectiveRoleProvider;
import '../../../../core/providers/message_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/quill_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/auto_message/auto_message.dart';
import '../../../../data/models/message/message.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../message_format.dart';
import '../widgets/message_termin_section.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/services/native/native_file_service.dart';
import '../../../redesign/presentation/widgets/event/rd_event_head.dart' show rdEventMeta;
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../redesign/presentation/widgets/today/rd_today_common.dart' show RdInfoCard;

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

  /// PARITY_UEBERSICHT: Ionic load() shows one red toast "Mitteilung konnte
  /// nicht geladen werden" when any part of loading fails (message, instance
  /// switch, recipients, earlier messages); reset on pull-to-refresh.
  bool _loadErrorShown = false;

  void _showLoadError() {
    if (_loadErrorShown || !mounted) return;
    _loadErrorShown = true;
    ToastHelper.showError(context, context.l10n.messagesLoadFailed);
  }

  static bool _failed(AsyncValue<Object?>? value) =>
      value != null && value.hasError && !value.isLoading;

  /// Toast on every load that ends in an error, also error → reload → error.
  void _listenLoadError<T>(ProviderListenable<AsyncValue<T>> provider) {
    ref.listen<AsyncValue<T>>(provider, (prev, next) {
      if (_failed(next) && (prev == null || prev.isLoading || !prev.hasError)) {
        _showLoadError();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // ref.listen only reports changes: an error state that already exists
    // when the page opens (e.g. a cached failed load) is reported once here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messageAsync = ref.read(messageByIdProvider(widget.messageId));
      final message = messageAsync.valueOrNull;
      var failed = _failed(messageAsync);
      if (message != null) {
        final role = ref.read(effectiveRoleProvider);
        final isManager = (role.isAdmin || role.isResponsible) &&
            message.tenantId == ref.read(currentTenantIdProvider);
        failed = failed ||
            _failed(isManager
                ? ref.read(messageRecipientsProvider(message.id))
                : ref.read(receivedMessagesProvider));
      }
      if (failed) _showLoadError();
    });
  }

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
        _showLoadError();
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
    if (ok && context.canPop()) {
      context.pop();
    } else if (ok) {
      context.go('/settings/messages');
    } else {
      ToastHelper.showError(context, context.l10n.messagesDeleteFailed);
    }
  }

  Future<void> _refresh() async {
    _loadErrorShown = false;
    ref.invalidate(messageRecipientsProvider(widget.messageId));
    ref.invalidate(messageByIdProvider(widget.messageId));
    await ref.read(messageByIdProvider(widget.messageId).future);
  }

  @override
  Widget build(BuildContext context) {
    final messageAsync = ref.watch(messageByIdProvider(widget.messageId));
    final message = messageAsync.valueOrNull;
    // Manager view only for messages of the current instance.
    final isManager = _isManager &&
        (message == null || message.tenantId == ref.watch(currentTenantIdProvider));
    _listenLoadError(messageByIdProvider(widget.messageId));
    if (message != null) {
      if (isManager) {
        _listenLoadError(messageRecipientsProvider(message.id));
      } else {
        _listenLoadError(receivedMessagesProvider);
      }
    }

    return _buildBeta(messageAsync, isManager);
  }

  /// REDESIGN (canvas K1 "Mitteilung"): page type "Detailseite". Title and
  /// sender on top; managers get "Nachricht anzeigen" / "Zum Termin" as
  /// buttons, the delivery overview and the recipients, deleting under
  /// "•••"; members the message, the Termin answer and earlier messages.
  /// Loading, instance switch and marking as read are the same as above.
  Widget _buildBeta(AsyncValue<Message?> messageAsync, bool isManager) {
    final p = context.rd;
    final l10n = context.l10n;
    final message = messageAsync.valueOrNull;
    final top = Row(
      children: [
        Expanded(child: RdBackLink(label: isManager ? l10n.messagesMessages : l10n.commonBack, onTap: _back)),
        if (isManager && message != null)
          RdCircleButton(
            key: const Key('rd-message-more'),
            icon: Icons.more_horiz,
            label: l10n.redesignManageListMore,
            onPressed: _betaMore,
          ),
      ],
    );

    final List<Widget> body;
    // Like `when` in the classic branch: a reload (e.g. after an instance
    // switch) shows loading instead of acting on the previous message.
    if (messageAsync.isLoading && (message == null || messageAsync.isReloading)) {
      body = [RdInfoCard(text: l10n.redesignTodayLoading, loading: true)];
    } else if (messageAsync.hasError && !messageAsync.isLoading) {
      // A failed reload keeps the previous message in `valueOrNull`; like
      // `when`, show the error instead of acting on that stale message.
      body = [
        RdInfoCard(
          icon: Icons.cloud_off_outlined,
          text: l10n.messagesLoadFailed,
          action: RdOutlineButton(label: l10n.redesignCommonRetry, onPressed: _refresh),
        ),
      ];
    } else if (message == null) {
      body = [RdInfoCard(icon: Icons.campaign_outlined, text: l10n.messagesNotAvailable)];
    } else if (_switchTenantIfNeeded(message)) {
      body = [RdInfoCard(text: l10n.redesignTodayLoading, loading: true)];
    } else {
      _markReadOnce();
      final showContent = _showContent ?? !isManager;
      final autoInfo = ref.watch(messageAutoInfoProvider(message.id)).valueOrNull;
      final ownInfo = isManager ? null : ref.watch(ownRecipientAutoInfoProvider(message.id)).valueOrNull;
      final display = personalizeMessage(message, autoInfo, ownInfo);
      final sender =
          (message.senderName != null && message.senderName!.isNotEmpty) ? message.senderName! : l10n.commonUnknown;
      final attendanceId = autoInfo?.attendanceId;
      body = [
        Semantics(header: true, child: Text(display.title, style: RdType.title(p))),
        const SizedBox(height: 6),
        Text(l10n.messagesFrom(sender, rdMessageWhen(message.createdAt)), style: RdType.meta(p, size: 15)),
        if (isManager) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: RdOutlineButton(
                  key: const Key('rd-message-toggle'),
                  icon: showContent ? Icons.expand_less : Icons.expand_more,
                  label: showContent ? l10n.messagesFlutterHideMessage : l10n.messagesFlutterShowMessage,
                  onPressed: () => setState(() => _showContent = !showContent),
                ),
              ),
              if (attendanceId != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: RdOutlineButton(
                    icon: Icons.event_outlined,
                    label: l10n.autoMessagesOpenTermin,
                    onPressed: () => context.push(RedesignRoutes.event(attendanceId)),
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 18),
        if (showContent)
          _MessageCard(message: message, html: display.html),
        if (!isManager && attendanceId != null)
          MessageTerminSection(messageId: message.id, info: autoInfo!, recipient: ownInfo),
        if (isManager) ..._betaOverview(message) else _EarlierMessages(currentId: message.id),
      ];
    }

    return RdPage(
      onRefresh: isManager && message != null ? _refresh : null,
      children: [top, const SizedBox(height: 4), ...body],
    );
  }

  Future<void> _betaMore() async {
    final l10n = context.l10n;
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        AppActionSheetAction(
          value: 'delete',
          icon: AppIcons.deleteOutline,
          label: l10n.messagesDeleteMessage,
          destructive: true,
        ),
      ],
    );
    if (action == 'delete' && mounted) await _delete();
  }

  List<Widget> _betaOverview(Message message) {
    final p = context.rd;
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

    Widget tiles(_RdTile left, _RdTile right) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Expanded(child: left), const SizedBox(width: 10), Expanded(child: right)],
      ),
    );

    return [
      if (message.isSending) ...[
        RdInfoCard(icon: Icons.schedule_send_outlined, text: l10n.messagesStillSending),
        const SizedBox(height: 18),
      ],
      RdSectionHeader(l10n.redesignMessagesDelivery),
      tiles(
        _RdTile(value: '${stats.read} / ${stats.total}', label: l10n.messagesReadInApp),
        _RdTile(value: '${stats.pushDelivered} / ${stats.pushTotal}', label: l10n.messagesPushDelivered),
      ),
      const SizedBox(height: 10),
      tiles(
        _RdTile(value: '${stats.emailDelivered} / ${stats.emailTotal}', label: l10n.messagesEmailDelivered),
        _RdTile(value: '≈ ${stats.emailOpened}', label: l10n.messagesEmailOpenedApprox),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Text(l10n.messagesOpenedEstimate, style: RdType.meta(p, size: 13)),
      ),
      const SizedBox(height: 22),
      RdSectionHeader(l10n.messagesRecipients),
      // Four filters with counts do not fit a segment on a phone: chips.
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in _Filter.values)
            RdChoiceChip(
              label: switch (f) {
                _Filter.all => l10n.messagesAllCount(stats.total),
                _Filter.read => l10n.messagesReadCount(stats.readAny),
                _Filter.open => l10n.messagesOpenCount(stats.open),
                _Filter.problems => l10n.messagesProblemsCount(stats.problems),
              },
              selected: _filter == f,
              onTap: () => setState(() => _filter = f),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (recipientsAsync.isLoading && rows.isEmpty)
        RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
      else if (filtered.isEmpty)
        RdInfoCard(text: l10n.messagesNoPeopleView)
      else
        RdGroupedList(
          children: [
            for (final r in filtered)
              _RdRecipientRow(recipient: r, groupName: r.groupId != null ? groups[r.groupId] : null),
          ],
        ),
    ];
  }
}

/// The formatted message body (server-rendered allowlisted HTML).
class _MessageCard extends StatefulWidget {
  const _MessageCard({
    required this.message,
    required this.html,
  });

  final Message message;

  /// HTML with the placeholders filled.
  final String html;

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
    if (oldWidget.html != widget.html) {
      _controller.dispose();
      _controller = _build();
    }
  }

  QuillController _build() => QuillController(
    document: QuillUtils.documentFromNotesString(
      widget.html.isNotEmpty ? widget.html : widget.message.bodyText,
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
    await NativeFileService.openLinkInApp(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: RdCard(
        child: QuillEditor.basic(
          controller: _controller,
          config: QuillEditorConfig(showCursor: false, scrollable: false, onLaunchUrl: _openLink),
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdGroupLabel(context.l10n.messagesEarlier),
          RdGroupedList(
            children: [
              for (final m in earlier)
                RdListRow(
                  title: m.title,
                  subtitle: m.createdAt == null ? null : rdEventMeta(m.createdAt!.toLocal()),
                  onTap: () => context.push('/messages/${m.id}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Di 21. Okt · 22:00" (Beta date of a message).
String rdMessageWhen(DateTime? d) {
  if (d == null) return '';
  final local = d.toLocal();
  final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return rdEventMeta(local, timeRange: time);
}

/// REDESIGN: one number of the delivery overview.
class _RdTile extends StatelessWidget {
  const _RdTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    return RdCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: p.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: 2, style: RdType.meta(p, size: 12)),
        ],
      ),
    );
  }
}

/// REDESIGN: a recipient with initials, register and the status pills.
class _RdRecipientRow extends StatelessWidget {
  const _RdRecipientRow({required this.recipient, this.groupName});

  final MessageRecipient recipient;
  final String? groupName;

  static RdTone? _tone(ChipTone tone) => switch (tone) {
    ChipTone.ok => RdTone.present,
    ChipTone.bad => RdTone.absent,
    ChipTone.warn => RdTone.late,
    ChipTone.neutral => null,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final name = recipient.name.isNotEmpty ? recipient.name : context.l10n.commonUnknown;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RdInitials(rdInitialsOf(name), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.text)),
                if (groupName != null && groupName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(groupName!, style: RdType.meta(p, size: 13)),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [for (final c in recipientChips(recipient)) RdPill(c.text, tone: _tone(c.tone))],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
