import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/message_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/tiptap_converter.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/message/message.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/rd_widgets.dart';

/// Tiptap document of a plain text (one paragraph per line), the format
/// the send-message Edge Function renders.
Map<String, dynamic> rdPlainTextDoc(String text) =>
    TiptapConverter.fromDeltaOps([
      {'insert': '${text.trimRight()}\n'},
    ]);

/// REDESIGN: Verwaltung › Mitteilung schreiben (canvas "MitteilungNeu"):
/// recipients as chips (alle / Register), subject and plain text, push and
/// e-mail. Sends through the same send-message Edge Function as the old
/// compose page; the live recipient count comes from its dry run.
class RdMessageComposePage extends ConsumerStatefulWidget {
  const RdMessageComposePage({super.key});

  @override
  ConsumerState<RdMessageComposePage> createState() => _RdMessageComposePageState();
}

class _RdMessageComposePageState extends ConsumerState<RdMessageComposePage> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final Set<int> _groups = {};
  bool _onlyGroups = false;
  bool _push = true;
  bool _email = false;
  bool _sending = false;
  MessageRecipientCounts? _counts;
  bool _countsFailed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _subject.addListener(() => setState(() {}));
    _body.addListener(() => setState(() {}));
    _loadCounts();
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  List<int>? get _groupIds => _onlyGroups ? _groups.toList() : null;

  bool get _complete =>
      _subject.text.trim().isNotEmpty && _body.text.trim().isNotEmpty && (_push || _email);

  bool get _canSend =>
      !_sending && _complete && (!_onlyGroups || _groups.isNotEmpty) && (_counts?.recipients ?? 0) > 0;

  Future<void> _loadCounts() async {
    final request = ++_request;
    setState(() => _countsFailed = false);
    if (_onlyGroups && _groups.isEmpty) {
      setState(() => _counts = const MessageRecipientCounts());
      return;
    }
    try {
      final counts = await ref
          .read(messageRepositoryWithTenantProvider)
          .getRecipientCounts(groupIds: _groupIds, push: _push, email: _email);
      if (mounted && request == _request) setState(() => _counts = counts);
    } catch (_) {
      if (mounted && request == _request) setState(() => _countsFailed = true);
    }
  }

  void _change(VoidCallback change) {
    setState(change);
    unawaited(_loadCounts());
  }

  Future<void> _send() async {
    if (!_canSend) {
      if (!_complete) ToastHelper.showError(context, context.l10n.redesignComposeMissing);
      return;
    }
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    setState(() => _sending = true);
    final id = await ref.read(messageNotifierProvider.notifier).send(
          title: _subject.text.trim(),
          content: rdPlainTextDoc(_body.text),
          groupIds: _groupIds,
          push: _push,
          email: _email,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (id == null) {
      ToastHelper.showError(context, context.l10n.messagesSendFailed);
      return;
    }
    ToastHelper.showSuccess(context, context.l10n.messagesIsSending);
    context.canPop() ? context.pop() : context.go(RedesignRoutes.manage);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final groups = ref.watch(groupsProvider).valueOrNull ?? const [];
    final counts = _counts;

    InputDecoration field(String label) => InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );

    return RdPage(
      children: [
        Row(
          children: [
            RdTextLink(
              label: l10n.redesignCommonCancel,
              onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.manage),
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l10n.messagesMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text),
                ),
              ),
            ),
            _sending
                ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary))
                : Opacity(
                    opacity: _canSend ? 1 : 0.45,
                    child: RdTextLink(label: l10n.redesignComposeSend, onTap: _send),
                  ),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.redesignComposeTitle, style: RdType.largeTitle(p)),
        const SizedBox(height: 16),
        RdGroupLabel(l10n.redesignComposeTo),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RdChoiceChip(
              label: l10n.messagesAllActive,
              selected: !_onlyGroups,
              onTap: () => _change(() => _onlyGroups = false),
            ),
            RdChoiceChip(
              label: l10n.redesignComposeGroups,
              selected: _onlyGroups,
              onTap: () => _change(() => _onlyGroups = true),
            ),
          ],
        ),
        if (_onlyGroups) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in groups)
                if (g.id != null)
                  FilterChip(
                    label: Text(g.name),
                    selected: _groups.contains(g.id),
                    selectedColor: p.soft,
                    checkmarkColor: p.softText,
                    onSelected: (on) => _change(() => on ? _groups.add(g.id!) : _groups.remove(g.id)),
                  ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _countsFailed
                ? l10n.messagesCountsFailed
                : counts == null
                    ? ''
                    : [
                        l10n.messagesAllCount(counts.recipients),
                        if (_push) '${l10n.messagesPush}: ${counts.push}',
                        if (_email) '${l10n.messagesEmail}: ${counts.email}',
                      ].join(' · '),
            style: RdType.meta(p, size: 13),
          ),
        ),
        const SizedBox(height: 16),
        RdGroupedList(
          children: [
            TextField(
              controller: _subject,
              textInputAction: TextInputAction.next,
              decoration: field(l10n.redesignComposeSubject),
            ),
            TextField(
              controller: _body,
              minLines: 6,
              maxLines: 14,
              keyboardType: TextInputType.multiline,
              decoration: field(l10n.redesignComposeBody),
            ),
          ],
        ),
        const SizedBox(height: 16),
        RdGroupLabel(l10n.messagesSendVia),
        RdGroupedList(
          children: [
            RdListRow(
              title: l10n.messagesPush,
              showChevron: false,
              trailing: Switch.adaptive(
                value: _push,
                activeTrackColor: p.primary,
                onChanged: (v) => _change(() => _push = v),
              ),
              onTap: () => _change(() => _push = !_push),
            ),
            RdListRow(
              title: l10n.messagesEmail,
              showChevron: false,
              trailing: Switch.adaptive(
                value: _email,
                activeTrackColor: p.primary,
                onChanged: (v) => _change(() => _email = v),
              ),
              onTap: () => _change(() => _email = !_email),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(l10n.redesignComposeHint, style: RdType.meta(p, size: 13)),
        ),
      ],
    );
  }
}
