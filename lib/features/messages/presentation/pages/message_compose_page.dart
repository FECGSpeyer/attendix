import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/message_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/tiptap_converter.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/message/message.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Opens the full-screen compose dialog. Returns the new message id when sent.
Future<String?> openMessageCompose(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const MessageComposePage(),
    ),
  );
}

enum _Audience { all, groups }

/// Write and send a Mitteilung (port of Ionic `MessageComposeComponent`).
class MessageComposePage extends ConsumerStatefulWidget {
  const MessageComposePage({super.key});

  @override
  ConsumerState<MessageComposePage> createState() => _MessageComposePageState();
}

class _MessageComposePageState extends ConsumerState<MessageComposePage> {
  final _titleController = TextEditingController();
  late QuillController _quill;

  _Audience _audience = _Audience.all;
  final Set<int> _selectedGroups = {};
  bool _push = true;
  bool _email = true;
  MessageRecipientCounts? _counts;
  bool _countsError = false;
  bool _sending = false;
  int _countsRequest = 0;
  int? _tenantId;

  String get _draftKey => 'message-draft-$_tenantId';

  @override
  void initState() {
    super.initState();
    _tenantId = ref.read(currentTenantIdProvider);
    _quill = QuillController.basic();
    _quill.document.changes.listen((_) => _onContentChange());
    _restoreDraft();
    _loadCounts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quill.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || !mounted) return;
      final draft = jsonDecode(raw) as Map<String, dynamic>;
      _titleController.text = draft['title'] as String? ?? '';
      final ops = draft['ops'];
      if (ops is List && ops.isNotEmpty) {
        final doc = Document.fromJson(ops.cast<Map<String, dynamic>>());
        _quill.dispose();
        setState(() {
          _quill = QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
        });
        _quill.document.changes.listen((_) => _onContentChange());
      } else {
        setState(() {});
      }
    } catch (_) {
      // Drafts are a convenience only.
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _draftKey,
        jsonEncode({
          'title': _titleController.text,
          'ops': _quill.document.toDelta().toJson(),
        }),
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

  void _onContentChange() {
    setState(() {}); // re-evaluate canSend
    _saveDraft();
  }

  Map<String, dynamic> get _content => TiptapConverter.fromDeltaOps(
    _quill.document.toDelta().toJson().cast<Map<String, dynamic>>(),
  );

  List<int>? get _groupIds =>
      _audience == _Audience.groups ? _selectedGroups.toList() : null;

  bool get _canSend =>
      !_sending &&
      _titleController.text.trim().isNotEmpty &&
      TiptapConverter.hasText(_content) &&
      (_push || _email) &&
      (_audience == _Audience.all || _selectedGroups.isNotEmpty) &&
      (_counts?.recipients ?? 0) > 0;

  Future<void> _loadCounts() async {
    final request = ++_countsRequest;
    setState(() => _countsError = false);
    if (_audience == _Audience.groups && _selectedGroups.isEmpty) {
      setState(() => _counts = const MessageRecipientCounts());
      return;
    }
    try {
      final counts = await ref
          .read(messageRepositoryWithTenantProvider)
          .getRecipientCounts(groupIds: _groupIds, push: _push, email: _email);
      if (mounted && request == _countsRequest)
        setState(() => _counts = counts);
    } catch (_) {
      if (mounted && request == _countsRequest)
        setState(() => _countsError = true);
    }
  }

  Future<void> _confirmSend() async {
    final counts = _counts;
    if (!_canSend || counts == null) return;
    final l10n = context.l10n;
    final channels = [
      if (_push) l10n.messagesViaPush(counts.push),
      if (_email) l10n.messagesViaEmail(counts.email),
    ].join(', ');
    final title = _titleController.text.trim();

    final confirmed = await showAppDialog<bool>(
      context: context,
      builder:
          (ctx) => AppAlertDialog(
            title: Text(l10n.messagesSendConfirm),
            content: Text(
              l10n.messagesSendConfirmMessage(title, counts.recipients, channels),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.commonCancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.messagesSend),
              ),
            ],
          ),
    );
    if (confirmed == true) await _send(title);
  }

  Future<void> _send(String title) async {
    if (_sending) return;
    setState(() => _sending = true);
    final id = await ref
        .read(messageNotifierProvider.notifier)
        .send(
          title: title,
          content: _content,
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
    await _clearDraft();
    if (!mounted) return;
    ToastHelper.showSuccess(context, context.l10n.messagesIsSending);
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = ref.watch(groupsProvider).valueOrNull ?? [];
    final l10n = context.l10n;

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingS,
        AppDimensions.paddingL,
        AppDimensions.paddingS,
        AppDimensions.paddingS,
      ),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(color: AppColors.medium),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        leadingWidth: 100,
        title: Text(l10n.messagesNewMessage),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingM,
                  ),
                  child: TextField(
                    controller: _titleController,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l10n.messagesTitle,
                      hintText: l10n.messagesTitlePlaceholder,
                      border: InputBorder.none,
                      counterText: '',
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _saveDraft();
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingM),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    QuillSimpleToolbar(
                      controller: _quill,
                      config: const QuillSimpleToolbarConfig(
                        multiRowsDisplay: false,
                        showBoldButton: true,
                        showItalicButton: true,
                        showUnderLineButton: true,
                        showStrikeThrough: true,
                        showHeaderStyle: true,
                        showListBullets: true,
                        showListNumbers: true,
                        showLink: true,
                        showListCheck: false,
                        showColorButton: false,
                        showBackgroundColorButton: false,
                        showClearFormat: false,
                        showInlineCode: false,
                        showCodeBlock: false,
                        showQuote: false,
                        showIndent: false,
                        showSearchButton: false,
                        showSubscript: false,
                        showSuperscript: false,
                        showFontFamily: false,
                        showFontSize: false,
                        showAlignmentButtons: false,
                        showDirection: false,
                        showSmallButton: false,
                        showUndo: false,
                        showRedo: false,
                      ),
                    ),
                    const Divider(height: 1),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 180),
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingM),
                        child: QuillEditor.basic(
                          controller: _quill,
                          config: QuillEditorConfig(
                            scrollable: false,
                            placeholder: l10n.editorMessagePlaceholder,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              header(l10n.messagesRecipients),
              Card(
                margin: EdgeInsets.zero,
                child: Builder(
                  builder: (context) {
                    void onAudience(_Audience? v) {
                      if (v == null) return;
                      setState(() => _audience = v);
                      _loadCounts();
                    }

                    return Column(
                      children: [
                        RadioListTile<_Audience>(
                          value: _Audience.all,
                          groupValue: _audience,
                          onChanged: onAudience,
                          title: Text(l10n.messagesAllActive),
                          subtitle: Text(l10n.messagesInclMainGroup),
                        ),
                        RadioListTile<_Audience>(
                          value: _Audience.groups,
                          groupValue: _audience,
                          onChanged: onAudience,
                          title: Text(l10n.messagesOnlyGroups),
                        ),
                        if (_audience == _Audience.groups)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppDimensions.paddingM,
                              0,
                              AppDimensions.paddingM,
                              AppDimensions.paddingM,
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final g in groups.where(
                                  (g) => g.id != null,
                                ))
                                  FilterChip(
                                    label: Text(g.name),
                                    selected: _selectedGroups.contains(g.id),
                                    onSelected: (sel) {
                                      setState(() {
                                        if (sel) {
                                          _selectedGroups.add(g.id!);
                                        } else {
                                          _selectedGroups.remove(g.id);
                                        }
                                      });
                                      _loadCounts();
                                    },
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              header(l10n.messagesSendVia),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      value: _push,
                      title: Text(l10n.messagesPushTelegram),
                      subtitle:
                          _counts != null && _push
                              ? Text(l10n.messagesPushCount(_counts!.push))
                              : null,
                      onChanged: (v) {
                        setState(() => _push = v);
                        _loadCounts();
                      },
                    ),
                    SwitchListTile.adaptive(
                      value: _email,
                      title: Text(l10n.messagesEmail),
                      subtitle:
                          _counts != null && _email
                              ? Text(l10n.messagesEmailCount(_counts!.email))
                              : null,
                      onChanged: (v) {
                        setState(() => _email = v);
                        _loadCounts();
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: _buildSummary(theme),
              ),
              FilledButton.icon(
                onPressed: _canSend ? _confirmSend : null,
                icon: const Icon(Icons.send_outlined),
                label: Text(l10n.messagesSend),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingXL),
            ],
          ),
          if (_sending)
            Container(
              color: Colors.black26,
              alignment: Alignment.center,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppSpinner(),
                      const SizedBox(width: AppDimensions.paddingM),
                      Text(l10n.messagesSendingNow),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(ThemeData theme) {
    final l10n = context.l10n;
    if (_countsError) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${l10n.messagesCountsFailed} ',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          TextButton(
            onPressed: _loadCounts,
            child: Text(l10n.messagesRetry),
          ),
        ],
      );
    }
    final counts = _counts;
    if (counts == null) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: AppSpinner(strokeWidth: 2),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: _strongSpans(l10n.messagesRecipientsSummary(counts.recipients))),
        ),
        if (counts.unreachable > 0) ...[
          const SizedBox(height: 4),
          Text(
            l10n.messagesUnreachableSummary(counts.unreachable),
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.medium),
          ),
        ],
      ],
    );
  }
}

/// Renders `<strong>…</strong>` of an Ionic `*Html`-style message as bold spans.
List<TextSpan> _strongSpans(String html) {
  final spans = <TextSpan>[];
  final re = RegExp(r'<strong>(.*?)</strong>');
  var last = 0;
  for (final m in re.allMatches(html)) {
    if (m.start > last) spans.add(TextSpan(text: html.substring(last, m.start)));
    spans.add(
      TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.bold)),
    );
    last = m.end;
  }
  if (last < html.length) spans.add(TextSpan(text: html.substring(last)));
  return spans;
}
