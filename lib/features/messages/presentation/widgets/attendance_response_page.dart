import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auto_message_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/auto_message/auto_message.dart';
import '../../../../data/repositories/base_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../settings/presentation/widgets/settings_list.dart';
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
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ToolbarButtonGroup(
            children: [
              TextButton(
                onPressed: _sending ? null : () => Navigator.of(context).pop(),
                child: IonButtonLabel(l10n.commonCancel),
              ),
            ],
          ),
        ),
        leadingWidth: useIosLook(context) ? 150 : 100,
        title: Text(l10n.autoMessagesRespTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              widget.termin,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.medium),
            ),
          ),
          IonSegment<String>(
            items: [
              IonSegmentItem(value: 'reason', label: Text(l10n.autoMessagesRespHadReason)),
              IonSegmentItem(value: 'was_present', label: Text(l10n.autoMessagesRespWasThere)),
            ],
            value: _kind,
            onChanged: (v) => setState(() => _kind = v),
          ),
          const SizedBox(height: 12),
          if (_kind == 'reason') ...[
            IonListHeader(title: l10n.autoMessagesRespReason),
            AutoMessageChipWrap(
              children: [
                for (final r in autoMessageResponseReasons)
                  AutoMessageChip(
                    label: l10n.autoMessageReason(r),
                    selected: _reason == r,
                    onTap: () => setState(() => _reason = r),
                  ),
              ],
            ),
            SettingsListSection(
              icons: false,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _textController,
                    maxLength: 500,
                    minLines: 3,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l10n.autoMessagesRespText,
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            AutoMessageHint(l10n.autoMessagesRespHint),
          ] else
            AutoMessageHint(l10n.autoMessagesRespWasThereHint),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child:
                _sending
                    ? const SizedBox(width: 20, height: 20, child: AppSpinner(strokeWidth: 2))
                    : IonButtonLabel(l10n.autoMessagesRespSend),
          ),
        ],
      ),
    );
  }
}
