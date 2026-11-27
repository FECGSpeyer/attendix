import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/auto_message_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/auto_message/auto_message.dart';
import '../../../../data/repositories/base_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../redesign/presentation/widgets/today/rd_today_common.dart';
import '../auto_message_texts.dart';

/// Opens the answer dialog for a Termin message. Returns the new state
/// ('pending' | 'accepted') when sent, null when cancelled.
Future<String?> openAttendanceResponse(
  BuildContext context, {
  required String messageId,
  required String termin,
  required String kind,
}) {
  return Navigator.of(context, rootNavigator: true).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AttendanceResponsePage(messageId: messageId, termin: termin, kind: kind),
    ),
  );
}

/// A member answers a Termin message: add a reason or say "I was there".
/// Port of Ionic `AttendanceResponseModalComponent` (4.18).
class AttendanceResponsePage extends ConsumerStatefulWidget {
  const AttendanceResponsePage({
    super.key,
    required this.messageId,
    required this.termin,
    required this.kind,
  });

  final String messageId;
  final String termin;

  /// 'reason' | 'was_present'
  final String kind;

  @override
  ConsumerState<AttendanceResponsePage> createState() => _AttendanceResponsePageState();
}

class _AttendanceResponsePageState extends ConsumerState<AttendanceResponsePage> {
  late String _kind = widget.kind;
  String _reason = 'sick';
  final _textController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    final l10n = context.l10n;
    try {
      final state = await ref
          .read(autoMessageRepositoryWithTenantProvider)
          .submitResponse(
            messageId: widget.messageId,
            kind: _kind,
            reasonCode: _kind == 'reason' ? _reason : null,
            text: _kind == 'reason' ? _textController.text.trim() : '',
          );
      if (mounted) Navigator.of(context).pop(state);
    } catch (e) {
      final code = e is RepositoryException ? e.message : '';
      if (mounted) {
        ToastHelper.showError(
          context,
          code == 'expired'
              ? l10n.autoMessagesRespExpired
              : code == 'alreadyDecided'
              ? l10n.autoMessagesRespAlreadyDecided
              : l10n.autoMessagesRespFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return RdPage(
      children: [
        RdBackLink(label: l10n.commonCancel, onTap: _sending ? () {} : () => Navigator.of(context).pop()),
        const SizedBox(height: 4),
        Semantics(header: true, child: Text(l10n.autoMessagesRespTitle, style: RdType.title(p))),
        const SizedBox(height: 4),
        Text(widget.termin, style: RdType.meta(p, size: 15)),
        const SizedBox(height: 16),
        RdSegmented<String>(
          values: const ['reason', 'was_present'],
          selected: _kind,
          labelOf: (v) => v == 'reason' ? l10n.autoMessagesRespHadReason : l10n.autoMessagesRespWasThere,
          onChanged: (v) => setState(() => _kind = v),
        ),
        const SizedBox(height: 20),
        if (_kind == 'reason') ...[
          RdGroupLabel(l10n.autoMessagesRespReason),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in autoMessageResponseReasons)
                RdChoiceChip(
                  label: l10n.autoMessageReason(r),
                  selected: _reason == r,
                  onTap: () => setState(() => _reason = r),
                ),
            ],
          ),
          const SizedBox(height: 16),
          RdCard(
            padding: EdgeInsets.zero,
            child: RdFieldRow(
              label: l10n.autoMessagesRespText,
              child: TextField(
                key: const Key('rd-response-text'),
                controller: _textController,
                maxLength: 500,
                minLines: 3,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: p.text),
                decoration: rdInputDecoration(p, '').copyWith(counterText: ''),
              ),
            ),
          ),
          const SizedBox(height: 12),
          RdInfoCard(text: l10n.autoMessagesRespHint, icon: Icons.info_outline),
        ] else
          RdInfoCard(text: l10n.autoMessagesRespWasThereHint, icon: Icons.info_outline),
        const SizedBox(height: 20),
        RdPrimaryButton(label: l10n.autoMessagesRespSend, loading: _sending, onPressed: _sending ? null : _send),
      ],
    );
  }
}
