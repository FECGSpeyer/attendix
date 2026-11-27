import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/assistant_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../data/models/auto_message/auto_message.dart' show textToDoc;
import '../../../../l10n/l10n.dart';
import '../../../messages/presentation/pages/message_compose_page.dart' show MessageComposePreset, openMessageCompose;
import '../../../people/person_create_prefill.dart';
import '../../data/assistant_command.dart';
import '../../data/assistant_logic.dart' show assistantMaxChanges;
import '../../data/assistant_reply.dart';
import '../assistant_voice.dart';
import '../../../../core/utils/toast_helper.dart';

part 'assistant_reply_previews.dart';
part 'assistant_reply_view.dart';
part 'assistant_reply_widgets.dart';

/// Chat assistant. One page for both designs: in the new design it takes
/// the colours of the Beta palette.
///
/// Every answer is a card the app fills itself; the model only picks the
/// command (see assistant_executor.dart), its text is never shown. Changes
/// (package 2) show a preview with "Speichern" / "Abbrechen" first and
/// "Rückgängig" after saving.
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  /// Speech input is on (the words go into the input field).
  bool _listening = false;
  AssistantVoice? _voice;

  @override
  void dispose() {
    if (_listening) _voice?.stop();
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Mic button: listen and write the words into the field; tapping again
  /// stops. Nothing is sent by itself.
  Future<void> _toggleVoice() async {
    final AssistantVoice voice = _voice ?? ref.read<AssistantVoice>(assistantVoiceProvider);
    _voice = voice;
    if (_listening) {
      await voice.stop();
      return;
    }
    final before = _controller.text.trim();
    setState(() => _listening = true);
    final ok = await voice.start(
      language: ref.read(localeProvider).languageCode,
      onText: (words) {
        if (!mounted) return;
        final text = before.isEmpty ? words : '$before $words';
        _controller.value = TextEditingValue(
          text: text.length > assistantMaxTextLength ? text.substring(0, assistantMaxTextLength) : text,
          selection: TextSelection.collapsed(
              offset: text.length > assistantMaxTextLength ? assistantMaxTextLength : text.length),
        );
      },
      onEnd: () {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!ok && mounted) {
      setState(() => _listening = false);
      ToastHelper.showWarning(context, context.l10n.assistantVoiceUnavailable, beta: LegacySnackBar.plain);
    }
  }

  Future<void> _send([String? text]) async {
    if (_listening) await _voice?.stop();
    final value = (text ?? _controller.text).trim();
    if (value.isEmpty) return;
    _controller.clear();
    _scrollToEnd();
    await ref.read(assistantChatNotifierProvider.notifier).send(value);
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chat = ref.watch(assistantChatNotifierProvider);
    final enabled = ref.watch(assistantEnabledProvider);
    final role = ref.watch(currentRoleProvider);
    final seesOthers = role.isConductor || role.isHelperRole;
    final style = _ChatStyle.of(context);
    ref.listen(assistantChatNotifierProvider, (_, __) => _scrollToEnd());

    final suggestions = [
      if (!role.isParent) l10n.assistantSuggestMyRate,
      l10n.assistantSuggestNextEvent,
      if (role.isParent) l10n.assistantSuggestChildren else l10n.assistantSuggestSignOut,
      l10n.assistantSuggestSongs,
      if (seesOthers) l10n.assistantSuggestWhoComes,
      if (seesOthers) l10n.assistantSuggestBirthdays,
      l10n.assistantSuggestHelp,
    ];

    return Scaffold(
      backgroundColor: style.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 20, color: style.accent),
            const SizedBox(width: 8),
            Flexible(child: Text(l10n.assistantTitle)),
          ],
        ),
        actions: [
          if (chat.messages.isNotEmpty)
            IconButton(
              tooltip: l10n.assistantClear,
              icon: const Icon(Icons.refresh),
              onPressed: chat.busy ? null : () => ref.read(assistantChatNotifierProvider.notifier).clear(),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  _Bubble(style: style, child: Text(l10n.assistantIntro, style: TextStyle(color: style.text))),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 6, bottom: 10),
                    child: Text(l10n.assistantPrivacy, style: TextStyle(color: style.muted, fontSize: 12)),
                  ),
                  if (chat.messages.isEmpty && enabled)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in suggestions)
                          ActionChip(label: Text(s), onPressed: chat.busy ? null : () => _send(s)),
                      ],
                    ),
                  if (!enabled)
                    _Bubble(
                      style: style,
                      child: Text(l10n.assistantNoticeDisabled, style: TextStyle(color: style.text)),
                    ),
                  for (final (i, m) in chat.messages.indexed)
                    m.fromUser
                        ? _Bubble(
                          style: style,
                          fromUser: true,
                          child: Text(m.text!, style: TextStyle(color: style.onAccent)),
                        )
                        : _Bubble(
                          style: style,
                          child: _ReplyView(
                            reply: m.reply!,
                            index: i,
                            busy: chat.busy,
                            style: style,
                            seesOthers: seesOthers,
                          ),
                        ),
                  if (chat.busy)
                    _Bubble(
                      style: style,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: style.accent),
                          ),
                          const SizedBox(width: 10),
                          Text(l10n.assistantThinking, style: TextStyle(color: style.muted)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _InputBar(
              controller: _controller,
              focus: _focus,
              style: style,
              enabled: enabled && !chat.busy,
              onSend: _send,
              listening: _listening,
              onMic: _toggleVoice,
            ),
          ],
        ),
      ),
    );
  }
}

/// Colours of the chat in the old (Ionic) and the new design.
class _ChatStyle {
  const _ChatStyle({
    required this.background,
    required this.surface,
    required this.accent,
    required this.onAccent,
    required this.text,
    required this.muted,
    required this.line,
    required this.good,
    required this.bad,
    required this.radius,
  });

  factory _ChatStyle.of(BuildContext context) {
    final rd = context.rd;
    return _ChatStyle(
      background: rd.bg,
      surface: rd.surface,
      accent: rd.primary,
      onAccent: rd.onPrimary,
      text: rd.text,
      muted: rd.text2,
      line: rd.line,
      good: rd.present,
      bad: rd.absent,
      radius: rd.cardRadius,
    );
  }

  final Color background;
  final Color surface;
  final Color accent;
  final Color onAccent;
  final Color text;
  final Color muted;
  final Color line;
  final Color good;
  final Color bad;
  final double radius;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.style, required this.child, this.fromUser = false});

  final _ChatStyle style;
  final Widget child;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    final r = Radius.circular(style.radius);
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (fromUser ? 0.8 : 0.92)),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: fromUser ? style.accent : style.surface,
            borderRadius: BorderRadius.only(
              topLeft: r,
              topRight: r,
              bottomLeft: fromUser ? r : const Radius.circular(4),
              bottomRight: fromUser ? const Radius.circular(4) : r,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focus,
    required this.style,
    required this.enabled,
    required this.onSend,
    required this.listening,
    required this.onMic,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final _ChatStyle style;
  final bool enabled;
  final Future<void> Function([String?]) onSend;
  final bool listening;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: style.background, border: Border(top: BorderSide(color: style.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              maxLength: assistantMaxTextLength,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: listening ? l10n.assistantVoiceListening : l10n.assistantInputHint,
                counterText: '',
                filled: true,
                fillColor: style.surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: listening ? l10n.assistantVoiceStop : l10n.assistantVoiceStart,
            isSelected: listening,
            style: IconButton.styleFrom(
              foregroundColor: listening ? style.onAccent : style.accent,
              backgroundColor: listening ? style.bad : null,
            ),
            onPressed: enabled ? onMic : null,
            icon: Icon(listening ? Icons.stop : Icons.mic_none),
          ),
          IconButton.filled(
            tooltip: l10n.assistantSend,
            style: IconButton.styleFrom(backgroundColor: style.accent, foregroundColor: style.onAccent),
            onPressed: enabled ? () => onSend() : null,
            icon: const Icon(Icons.arrow_upward),
          ),
        ],
      ),
    );
  }
}

String _day(DateTime d) => DateFormat(dateFmt()).format(d);

String _weekdayDate(DateTime d) => DateFormat.yMMMMEEEEd(currentIntlLocale()).format(d);

/// HH:mm of a time column ("19:30:00" → "19:30").
String _time(String t) => t.length >= 5 ? t.substring(0, 5) : t;
