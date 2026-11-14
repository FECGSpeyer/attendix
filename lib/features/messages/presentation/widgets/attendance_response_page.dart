import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auto_message_providers.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/auto_message/auto_message.dart';
import '../../../../data/repositories/base_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/dialogs/ion_modal.dart' show showIonModal;
import '../../../../shared/widgets/layout/ion_form_items.dart';
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../redesign/presentation/widgets/today/rd_today_common.dart';
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
  final beta = ProviderScope.containerOf(context, listen: false).read(redesignEnabledProvider);
  if (!beta) {
    // TER-29: Ionic default `ion-modal` – full screen on phones, from 768px
    // a centred card.
    return showIonModal<String>(
      context,
      builder: (_) => AttendanceResponsePage(messageId: messageId, termin: termin, kind: kind),
    );
  }
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

  /// Beta (redesign) layout: same fields, Beta building blocks.
  Widget _buildBeta(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    if (context.rdSkin != null) return _buildBeta(context);
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
                // TER-29: `ion-textarea labelPlacement="stacked"`.
                IonStackedInputItem(
                  lines: false,
                  label: l10n.autoMessagesRespText,
                  controller: _textController,
                  textarea: true,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
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
