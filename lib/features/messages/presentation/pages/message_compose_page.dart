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
import '../message_format.dart';

/// Opens the full-screen compose dialog. Returns the new message id when sent.
Future<String?> openMessageCompose(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<String>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const MessageComposePage()),
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
        jsonEncode({'title': _titleController.text, 'ops': _quill.document.toDelta().toJson()}),
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

  Map<String, dynamic> get _content =>
      TiptapConverter.fromDeltaOps(_quill.document.toDelta().toJson().cast<Map<String, dynamic>>());

  List<int>? get _groupIds => _audience == _Audience.groups ? _selectedGroups.toList() : null;

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
      if (mounted && request == _countsRequest) setState(() => _counts = counts);
    } catch (_) {
      if (mounted && request == _countsRequest) setState(() => _countsError = true);
    }
  }

  Future<void> _confirmSend() async {
    final counts = _counts;
    if (!_canSend || counts == null) return;
    final channels = [
      if (_push) '${counts.push} per Push/Telegram',
      if (_email) '${counts.email} per E-Mail',
    ].join(', ');
    final title = _titleController.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Mitteilung senden?'),
            content: Text(
              '„$title“ geht an ${MessageFormat.persons(counts.recipients)} ($channels). '
              'Das kann nicht rückgängig gemacht werden.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Senden'),
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
        .send(title: title, content: _content, groupIds: _groupIds, push: _push, email: _email);
    if (!mounted) return;
    setState(() => _sending = false);
    if (id == null) {
      ToastHelper.showError(context, 'Fehler beim Versenden, bitte versuche es erneut.');
      return;
    }
    await _clearDraft();
    if (!mounted) return;
    ToastHelper.showSuccess(context, 'Mitteilung wird versendet');
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = ref.watch(groupsProvider).valueOrNull ?? [];

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingS,
        AppDimensions.paddingL,
        AppDimensions.paddingS,
        AppDimensions.paddingS,
      ),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: AppColors.medium)),
    );

    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        leadingWidth: 100,
        title: const Text('Neue Mitteilung'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
                  child: TextField(
                    controller: _titleController,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Titel',
                      hintText: 'z. B. Probe am Samstag fällt aus',
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
                          config: const QuillEditorConfig(
                            scrollable: false,
                            placeholder: 'Nachricht …',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              header('Empfänger'),
              Card(
                margin: EdgeInsets.zero,
                child: RadioGroup<_Audience>(
                  groupValue: _audience,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _audience = v);
                    _loadCounts();
                  },
                  child: Column(
                    children: [
                      const RadioListTile<_Audience>(
                        value: _Audience.all,
                        title: Text('Alle aktiven Mitglieder'),
                        subtitle: Text('inkl. Hauptgruppe'),
                      ),
                      const RadioListTile<_Audience>(
                        value: _Audience.groups,
                        title: Text('Nur bestimmte Gruppen'),
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
                              for (final g in groups.where((g) => g.id != null))
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
                  ),
                ),
              ),
              header('Versand über'),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _push,
                      title: const Text('Push / Telegram'),
                      subtitle:
                          _counts != null && _push
                              ? Text(
                                _counts!.push == 1
                                    ? '1 Person hat Mitteilungen aktiviert'
                                    : '${_counts!.push} Personen haben Mitteilungen aktiviert',
                              )
                              : null,
                      onChanged: (v) {
                        setState(() => _push = v);
                        _loadCounts();
                      },
                    ),
                    SwitchListTile(
                      value: _email,
                      title: const Text('E-Mail'),
                      subtitle:
                          _counts != null && _email
                              ? Text(
                                _counts!.email == 1
                                    ? '1 Person hat eine E-Mail-Adresse'
                                    : '${_counts!.email} Personen haben eine E-Mail-Adresse',
                              )
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
                label: const Text('Senden'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: AppDimensions.paddingXL),
            ],
          ),
          if (_sending)
            Container(
              color: Colors.black26,
              alignment: Alignment.center,
              child: const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppDimensions.paddingL),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: AppDimensions.paddingM),
                      Text('Wird versendet …'),
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
    if (_countsError) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Die Empfänger konnten nicht geladen werden. ',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          TextButton(onPressed: _loadCounts, child: const Text('Erneut versuchen')),
        ],
      );
    }
    final counts = _counts;
    if (counts == null) {
      return const Center(
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: MessageFormat.persons(counts.recipients),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' erhalten diese Mitteilung.'),
            ],
          ),
        ),
        if (counts.unreachable > 0) ...[
          const SizedBox(height: 4),
          Text(
            counts.unreachable == 1
                ? '1 Person ist über keinen Kanal erreichbar und sieht die Mitteilung nur, wenn sie die App öffnen.'
                : '${counts.unreachable} Personen sind über keinen Kanal erreichbar und sehen die Mitteilung nur, wenn sie die App öffnen.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.medium),
          ),
        ],
      ],
    );
  }
}
