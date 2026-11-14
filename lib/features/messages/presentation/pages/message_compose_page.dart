import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/message_providers.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/tiptap_converter.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/message/message.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/message_editor_toolbar.dart';
import '../../../redesign/presentation/pages/rd_message_compose_page.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import '../../../planning/presentation/widgets/ion_items.dart' show IonChip;
import '../../../settings/presentation/widgets/settings_list.dart';
import '../../../../shared/widgets/dialogs/ion_modal.dart' show showIonModal;
import '../../../../shared/widgets/layout/ion_form_items.dart';
import '../../../../shared/widgets/layout/ionic_md.dart' show IonMd;

/// Opens the full-screen compose dialog. Returns the new message id when sent.
/// [preset]: fixed recipients and prefilled text (Ionic 4.18
/// "Unentschuldigte anschreiben").
///
/// REDESIGN: with the Beta on, the Beta form ([RdMessageComposePage]) opens.
Future<String?> openMessageCompose(BuildContext context, {MessageComposePreset? preset}) {
  final beta = ProviderScope.containerOf(context, listen: false).read(redesignEnabledProvider);
  if (!beta) {
    // EIB-01: Ionic `modalController.create({ component })` without
    // `presentingElement` – full screen on phones, from 768px a centred
    // 600px card.
    return showIonModal<String>(
      context,
      builder: (_) => MessageComposePage(preset: preset),
    );
  }
  return Navigator.of(context, rootNavigator: true).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => beta ? RdMessageComposePage(preset: preset) : MessageComposePage(preset: preset),
    ),
  );
}

/// Preset mode of the compose dialog (Ionic MessageComposeComponent inputs
/// playerIds / attendanceId / allowResponses / recipientsLabel /
/// presetTitle / presetContent): fixed recipients, prefilled text, linked
/// to the Termin so recipients can answer. No draft is saved.
class MessageComposePreset {
  const MessageComposePreset({
    required this.playerIds,
    required this.recipientsLabel,
    required this.title,
    required this.content,
    this.attendanceId,
    this.allowResponses = false,
  });

  final List<int> playerIds;
  final String recipientsLabel;
  final String title;

  /// Tiptap document.
  final Map<String, dynamic> content;
  final int? attendanceId;
  final bool allowResponses;
}

enum _Audience { all, groups }

/// Write and send a Mitteilung (port of Ionic `MessageComposeComponent`).
class MessageComposePage extends ConsumerStatefulWidget {
  const MessageComposePage({super.key, this.preset});

  final MessageComposePreset? preset;

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

  MessageComposePreset? get _preset => widget.preset;
  bool get _isPreset => _preset?.playerIds.isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    _tenantId = ref.read(currentTenantIdProvider);
    if (_isPreset) {
      _titleController.text = _preset!.title;
      _quill = QuillController(
        document: Document.fromJson(TiptapConverter.toDeltaOps(_preset!.content)),
        selection: const TextSelection.collapsed(offset: 0),
      );
      _quill.document.changes.listen((_) => _onContentChange());
      _loadCounts();
      return;
    }
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
    if (_isPreset) return;
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
    if (_isPreset) return; // keep the user's normal draft
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

  List<int>? get _groupIds => !_isPreset && _audience == _Audience.groups
      ? _selectedGroups.toList()
      : null;

  bool get _canSend =>
      !_sending &&
      _titleController.text.trim().isNotEmpty &&
      TiptapConverter.hasText(_content) &&
      (_push || _email) &&
      (_isPreset || _audience == _Audience.all || _selectedGroups.isNotEmpty) &&
      (_counts?.recipients ?? 0) > 0;

  Future<void> _loadCounts() async {
    final request = ++_countsRequest;
    setState(() => _countsError = false);
    if (!_isPreset && _audience == _Audience.groups && _selectedGroups.isEmpty) {
      setState(() => _counts = const MessageRecipientCounts());
      return;
    }
    try {
      final counts = await ref
          .read(messageRepositoryWithTenantProvider)
          .getRecipientCounts(
            groupIds: _groupIds,
            push: _push,
            email: _email,
            playerIds: _preset?.playerIds,
          );
      if (mounted && request == _countsRequest) {
        setState(() => _counts = counts);
      }
    } catch (_) {
      if (mounted && request == _countsRequest) {
        setState(() => _countsError = true);
      }
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
              TextButton(
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
    // EIB-14 / EIB-19: Ionic `loadingController` "Wird gesendet…".
    final loading = showIonLoading(context, message: context.l10n.messagesSendingNow);
    final id = await ref
        .read(messageNotifierProvider.notifier)
        .send(
          title: title,
          content: _content,
          groupIds: _groupIds,
          push: _push,
          email: _email,
          playerIds: _preset?.playerIds,
          attendanceId: _preset?.attendanceId,
          allowResponses: _preset?.allowResponses ?? false,
        );
    loading.dismiss();
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

    // UX_SETTINGS (WAVE 8): message-compose.component.html — inset lists
    // with ion-list-header labels on the light page (iOS).
    Widget header(String text) => ionIsIos(context)
        ? Padding(
            padding: const EdgeInsets.only(top: 16),
            child: IonListHeader(title: text),
          )
        // EIB-14: md `ion-list-header` (45px, label 14.4 semibold in
        // medium-tint) instead of a Material subtitle.
        : ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 45),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: kMdSettingsHeaderFontSize,
                    fontWeight: FontWeight.w600,
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFFA2A4AB)
                        : const Color(0xFF737478),
                  ),
                ),
              ),
            ),
          );

    return Scaffold(
      appBar: AppBar(
        // IOS_PAGES3: iOS → the start ion-button in a Liquid Glass capsule
        leading: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ToolbarButtonGroup(children: [
            TextButton(
              onPressed: _sending ? null : () => Navigator.of(context).pop(),
              child: IonButtonLabel(l10n.commonCancel),
            ),
          ]),
        ),
        leadingWidth: useIosLook(context) ? 150 : 100,
        title: Text(l10n.messagesNewMessage),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.all(ionListMargin(context)),
            children: [
              // EIB-15: `ion-input labelPlacement="stacked"` – the label
              // always above, the placeholder visible.
              _ComposeBox(
                child: IonStackedInputItem(
                  lines: false,
                  label: l10n.messagesTitle,
                  placeholder: l10n.messagesTitlePlaceholder,
                  controller: _titleController,
                  maxLength: 200,
                  onChanged: (_) {
                    setState(() {});
                    _saveDraft();
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.paddingM),
              _ComposeBox(
                child: Column(
                  children: [
                    MessageEditorToolbar(controller: _quill),
                    // The classic toolbar draws its own bottom border.
                    if (context.rdSkin != null) const Divider(height: 1),
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
              if (_isPreset)
                _ComposeBox(
                  child: ListTile(
                    leading: Icon(AppIcons.peopleOutline),
                    title: Text(_preset!.recipientsLabel),
                  ),
                )
              else
              _ComposeBox(
                child: Builder(
                  builder: (context) {
                    void onAudience(_Audience? v) {
                      if (v == null) return;
                      setState(() => _audience = v);
                      _loadCounts();
                    }

                    return Column(
                      children: [
                        IonRadioItem<_Audience>(
                          labelEnd: true,
                          value: _Audience.all,
                          groupValue: _audience,
                          onChanged: onAudience,
                          title: Text(l10n.messagesAllActive),
                          subtitle: Text(l10n.messagesInclMainGroup),
                        ),
                        IonRadioItem<_Audience>(
                          labelEnd: true,
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
                                  if (context.rdSkin != null)
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
                                    )
                                  else
                                    // ion-chip: outline medium, selected
                                    // solid primary tint – no checkmark.
                                    IonChip(
                                      label: g.name,
                                      outline: !_selectedGroups.contains(g.id),
                                      color: _selectedGroups.contains(g.id)
                                          ? AppColors.primary
                                          : AppColors.medium,
                                      onTap: () {
                                        setState(() {
                                          if (!_selectedGroups.remove(g.id)) {
                                            _selectedGroups.add(g.id!);
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
              _ComposeBox(
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
              // Ionic .summary: margin 0 20px, 0.85rem medium-shade.
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 16),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 13.6,
                    height: 1.4,
                    color: Color(0xFF808289),
                  ),
                  child: _buildSummary(theme),
                ),
              ),
              // `.actions { margin: 1rem 16px 2rem }` + `ion-button
              // expand="block"` with `send-outline` at the start.
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: IonButton(
                  expand: true,
                  icon: AppIcons.sendOutlined,
                  label: l10n.messagesSend,
                  onPressed: _canSend ? _confirmSend : null,
                ),
              ),
            ],
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
          // EIB-14: inline `<a>` in the primary colour.
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _loadCounts,
              child: Text(
                l10n.messagesRetry,
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
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

/// Ionic `ion-list [inset]` box: iOS item group (radius 24, item
/// background); md: the Material card.
class _ComposeBox extends StatelessWidget {
  const _ComposeBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!ionIsIos(context)) {
      // EIB-17: md-ion-list-inset item group – radius 16, item background,
      // no shadow (not a Material card).
      final b = Theme.of(context).brightness;
      return ClipRRect(
        borderRadius: BorderRadius.circular(IonMd.groupRadius),
        child: Material(color: IonMd.itemBackground(b), child: child),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(IonIos.groupRadius),
      child: Material(
        color: IonIos.itemBackground(context),
        child: ionIosListTileTheme(context, child: child),
      ),
    );
  }
}
