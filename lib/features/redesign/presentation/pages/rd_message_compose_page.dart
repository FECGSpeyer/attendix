import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/message_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/tiptap_converter.dart';
import '../../../../core/theme/redesign/rd_palette.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/message/message.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../messages/presentation/widgets/message_editor_toolbar.dart';
import '../widgets/rd_widgets.dart';

/// Tiptap document of a plain text (one paragraph per line), the format
/// the send-message Edge Function renders.
Map<String, dynamic> rdPlainTextDoc(String text) =>
    TiptapConverter.fromDeltaOps([
      {'insert': '${text.trimRight()}\n'},
    ]);

/// REDESIGN: Mitteilungen › "+" (canvas "MitteilungNeu", K1 "Mitteilung
/// schreiben"): recipients as chips (alle / Register), subject and
/// formatted text, push and e-mail. Like the old compose page it keeps a
/// draft (same key), shows who is unreachable and asks before sending.
/// Sends through the same send-message Edge Function; the live recipient
/// count comes from its dry run. Pops with the new message id.
class RdMessageComposePage extends ConsumerStatefulWidget {
  const RdMessageComposePage({super.key});

  @override
  ConsumerState<RdMessageComposePage> createState() => _RdMessageComposePageState();
}

class _RdMessageComposePageState extends ConsumerState<RdMessageComposePage> {
  final _subject = TextEditingController();
  QuillController _body = QuillController.basic();
  StreamSubscription<Object?>? _bodyChanges;
  final Set<int> _groups = {};
  bool _onlyGroups = false;
  bool _push = true;
  bool _email = true; // like the old compose page
  bool _sending = false;
  MessageRecipientCounts? _counts;
  bool _countsFailed = false;
  int _request = 0;
  int? _tenantId;

  /// Same draft as the old compose page (one draft per group).
  String get _draftKey => 'message-draft-$_tenantId';

  @override
  void initState() {
    super.initState();
    _tenantId = ref.read(currentTenantIdProvider);
    _subject.addListener(_onChange);
    _listenBody();
    _restoreDraft();
    _loadCounts();
  }

  @override
  void dispose() {
    _bodyChanges?.cancel();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _listenBody() {
    _bodyChanges?.cancel();
    _bodyChanges = _body.document.changes.listen((_) => _onChange());
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    unawaited(_saveDraft());
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || !mounted) return;
      final draft = jsonDecode(raw) as Map<String, dynamic>;
      final ops = draft['ops'];
      if (ops is List && ops.isNotEmpty) {
        final old = _body;
        _body = QuillController(
          document: Document.fromJson(ops.cast<Map<String, dynamic>>()),
          selection: const TextSelection.collapsed(offset: 0),
        );
        _listenBody();
        old.dispose();
      }
      _subject.text = draft['title'] as String? ?? '';
      setState(() {});
    } catch (_) {
      // Drafts are a convenience only.
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _draftKey,
        jsonEncode({'title': _subject.text, 'ops': _body.document.toDelta().toJson()}),
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {
      // ignore
    }
  }

  Map<String, dynamic> get _content =>
      TiptapConverter.fromDeltaOps(_body.document.toDelta().toJson().cast<Map<String, dynamic>>());

  List<int>? get _groupIds => _onlyGroups ? _groups.toList() : null;

  bool get _complete =>
      _subject.text.trim().isNotEmpty && TiptapConverter.hasText(_content) && (_push || _email);

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
    final counts = _counts!;
    final l10n = context.l10n;
    final title = _subject.text.trim();
    final channels = [
      if (_push) l10n.messagesViaPush(counts.push),
      if (_email) l10n.messagesViaEmail(counts.email),
    ].join(', ');
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(l10n.messagesSendConfirm),
        content: Text(l10n.messagesSendConfirmMessage(title, counts.recipients, channels)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.commonCancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.messagesSend)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sending = true);
    final id = await ref.read(messageNotifierProvider.notifier).send(
          title: title,
          content: _content,
          groupIds: _groupIds,
          push: _push,
          email: _email,
        );
    // Sent: the draft goes, also if the page is gone by now.
    if (id != null) await _clearDraft();
    if (!mounted) return;
    setState(() => _sending = false);
    if (id == null) {
      ToastHelper.showError(context, context.l10n.messagesSendFailed);
      return;
    }
    ToastHelper.showSuccess(context, context.l10n.messagesIsSending);
    context.canPop() ? context.pop(id) : context.go('/messages/$id');
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
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );

    // No leaving while sending: the result (and the draft) belong here.
    return PopScope(
      canPop: !_sending,
      child: _page(context, p, l10n, groups, counts, field),
    );
  }

  Widget _page(
    BuildContext context,
    RdPalette p,
    AppLocalizations l10n,
    List<Group> groups,
    MessageRecipientCounts? counts,
    InputDecoration Function(String) field,
  ) {
    return RdPage(
      children: [
        Row(
          children: [
            Opacity(
              opacity: _sending ? 0.45 : 1,
              child: RdTextLink(
                label: l10n.redesignCommonCancel,
                onTap: () {
                  if (_sending) return;
                  context.canPop() ? context.pop() : context.go(RedesignRoutes.manage);
                },
              ),
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
        if (!_onlyGroups)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(l10n.messagesInclMainGroup, style: RdType.meta(p, size: 13)),
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
                        l10n.commonPersons(counts.recipients),
                        if (_push) '${l10n.messagesPush} ${counts.push}',
                        if (_email) '${l10n.messagesEmail} ${counts.email}',
                      ].join(' · '),
            style: RdType.meta(p, size: 13),
          ),
        ),
        if (!_countsFailed && (counts?.unreachable ?? 0) > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              l10n.messagesUnreachableSummary(counts!.unreachable),
              style: RdType.meta(p, size: 13).copyWith(color: p.absent),
            ),
          ),
        const SizedBox(height: 16),
        RdGroupedList(
          children: [
            TextField(
              controller: _subject,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: field(l10n.redesignComposeSubject),
            ),
            MessageEditorToolbar(controller: _body),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 160),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: QuillEditor.basic(
                  controller: _body,
                  config: QuillEditorConfig(scrollable: false, placeholder: l10n.redesignComposeBody),
                ),
              ),
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
