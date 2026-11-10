import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/auto_message_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/auto_message/auto_message.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../settings/presentation/widgets/settings_list.dart';
import '../auto_message_texts.dart';
import 'attendance_response_page.dart';

/// Members on a Termin message (Ionic 4.18 message-detail `termin-card`):
/// the Termin with the own status, the own answer and the buttons
/// "Grund nachtragen" / "Ich war doch da" (7 days after the Termin).
class MessageTerminSection extends ConsumerStatefulWidget {
  const MessageTerminSection({
    super.key,
    required this.messageId,
    required this.info,
    required this.recipient,
  });

  final String messageId;
  final MessageAutoInfo info;

  /// The member's own recipient row (null while loading / not a recipient).
  final RecipientAutoInfo? recipient;

  @override
  ConsumerState<MessageTerminSection> createState() => _MessageTerminSectionState();
}

class _MessageTerminSectionState extends ConsumerState<MessageTerminSection> {
  AutoMessageTerminInfo? _termin;
  int? _status;
  AttendanceResponse? _ownResponse;
  bool _loaded = false;
  String? _loadedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(covariant MessageTerminSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLoad();
  }

  void _maybeLoad() {
    final key = '${widget.messageId}:${widget.recipient?.personAttendanceId}';
    if (_loadedFor == key) return;
    _loadedFor = key;
    _load();
  }

  Future<void> _load() async {
    final attendanceId = widget.info.attendanceId;
    if (attendanceId == null) return;
    final repo = ref.read(autoMessageRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return;
    final paId = widget.recipient?.personAttendanceId;
    try {
      final atts = await repo.getAttendanceInfo([attendanceId]);
      final status = paId != null ? await repo.getPersonAttendanceStatus(paId) : null;
      final own = paId != null ? await repo.getOwnResponse(paId) : null;
      if (!mounted) return;
      setState(() {
        _termin = atts.firstOrNull;
        _status = status;
        _ownResponse = own;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  bool get _canRespond {
    final termin = _termin;
    if (termin == null || !widget.info.allowResponses) return false;
    if (widget.recipient?.personAttendanceId == null) return false;
    final until = autoMessageResponseUntil(termin.date);
    if (until == null) return false;
    final open = !DateTime.now().isAfter(until);
    return open && (_ownResponse == null || _ownResponse!.isPending);
  }

  Future<void> _respond(String kind, String label) async {
    final state = await openAttendanceResponse(
      context,
      messageId: widget.messageId,
      termin: label,
      kind: kind,
    );
    if (state == null || !mounted) return;
    ToastHelper.showSuccess(
      context,
      state == 'accepted'
          ? context.l10n.autoMessagesRespDoneInstant
          : context.l10n.autoMessagesRespDone,
    );
    _loadedFor = null;
    _maybeLoad();
  }

  @override
  Widget build(BuildContext context) {
    final termin = _termin;
    if (!_loaded || termin == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const [];
    final typeName = types.where((t) => t.id == termin.typeId).firstOrNull?.name ?? '';
    final label = [
      (termin.typeInfo?.isNotEmpty ?? false) ? termin.typeInfo! : typeName,
      formatTerminDate(termin.date),
    ].where((s) => s.isNotEmpty).join(' · ');
    final ios = ionIsIos(context);
    final cardColor = ios ? IonIos.itemBackground(context) : Theme.of(context).cardColor;
    final own = _ownResponse;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .termin-card
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (_status != null) _StatusPill(status: _status!),
            ],
          ),
        ),
        // .response-note
        if (own != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:
                  own.isPending
                      ? AppColors.warning.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  own.state == 'rejected' ? AppIcons.cancelOutlined : AppIcons.checkCircleOutline,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    [
                      l10n.autoMessageResponseState(own.state),
                      if (own.reasonCode != null) l10n.autoMessageReason(own.reasonCode),
                      if (own.wasPresent) l10n.autoMessagesRespWasThere,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 14.4),
                  ),
                ),
              ],
            ),
          ),
        // .respond-actions
        if (_canRespond)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => _respond('reason', label),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: IonButtonLabel(
                    own != null ? l10n.autoMessagesRespChange : l10n.autoMessagesRespAddReason,
                  ),
                ),
                if (own == null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => _respond('was_present', label),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: IonButtonLabel(l10n.autoMessagesRespWasThere),
                  ),
                  AutoMessageHint(l10n.autoMessagesRespWasThereShort, center: true),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Ionic `.status.s<n>` pill.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final int status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      1 => (AppColors.success.withValues(alpha: 0.16), AppColors.successDark),
      2 || 5 => (AppColors.primary.withValues(alpha: 0.14), AppColors.primary),
      3 => (AppColors.warning.withValues(alpha: 0.2), AppColors.warningDark),
      4 => (AppColors.danger.withValues(alpha: 0.14), AppColors.dangerDark),
      _ => (AppColors.medium.withValues(alpha: 0.15), AppColors.medium),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        context.l10n.autoMessageStatus(status),
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
