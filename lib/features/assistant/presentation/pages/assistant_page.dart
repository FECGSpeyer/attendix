import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/assistant_providers.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../data/assistant_command.dart';
import '../../data/assistant_reply.dart';

/// Chat assistant (package 1: questions only). One page for both designs:
/// in the new design it takes the colours of the Beta palette.
///
/// Every answer is a card the app fills itself; the model only picks the
/// command (see assistant_executor.dart), its text is never shown.
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  @override
  void dispose() {
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

  Future<void> _send([String? text]) async {
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
      l10n.assistantSuggestMyRate,
      l10n.assistantSuggestNextEvent,
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
                          ActionChip(
                            label: Text(s),
                            onPressed: chat.busy ? null : () => _send(s),
                          ),
                      ],
                    ),
                  if (!enabled)
                    _Bubble(style: style, child: Text(l10n.assistantNoticeDisabled, style: TextStyle(color: style.text))),
                  for (final m in chat.messages)
                    m.fromUser
                        ? _Bubble(style: style, fromUser: true, child: Text(m.text!, style: TextStyle(color: style.onAccent)))
                        : _Bubble(style: style, child: _ReplyView(reply: m.reply!, style: style, seesOthers: seesOthers)),
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
    final rd = context.rdSkin;
    if (rd != null) {
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return _ChatStyle(
      background: theme.scaffoldBackgroundColor,
      surface: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      accent: cs.primary,
      onAccent: cs.onPrimary,
      text: cs.onSurface,
      muted: cs.onSurfaceVariant,
      line: cs.outlineVariant,
      good: Colors.green.shade600,
      bad: cs.error,
      radius: 16,
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
  });

  final TextEditingController controller;
  final FocusNode focus;
  final _ChatStyle style;
  final bool enabled;
  final Future<void> Function([String?]) onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: style.background,
        border: Border(top: BorderSide(color: style.line)),
      ),
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
                hintText: l10n.assistantInputHint,
                counterText: '',
                filled: true,
                fillColor: style.surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
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

class _ReplyView extends ConsumerWidget {
  const _ReplyView({required this.reply, required this.style, required this.seesOthers});

  final AssistantReply reply;
  final _ChatStyle style;
  final bool seesOthers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final redesign = ref.watch(redesignEnabledProvider);
    final text = TextStyle(color: style.text);
    final muted = TextStyle(color: style.muted, fontSize: 13);
    final title = TextStyle(color: style.text, fontWeight: FontWeight.w700, fontSize: 16);

    Widget link(String label, String location) => Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: style.accent, padding: EdgeInsets.zero),
            onPressed: () => context.push(location),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(label),
          ),
        );

    String eventLocation(int id) => RedesignRoutes.betaTarget('/attendance/$id');

    switch (reply) {
      case NoticeReply(:final notice, :final subject):
        final s = subject ?? '';
        return Text(
          switch (notice) {
            AssistantNotice.notUnderstood => l10n.assistantNoticeNotUnderstood,
            AssistantNotice.changeLater => l10n.assistantNoticeChangeLater,
            AssistantNotice.noRights => l10n.assistantNoticeNoRights,
            AssistantNotice.noOwnPerson => l10n.assistantNoticeNoOwnPerson,
            AssistantNotice.disabled => l10n.assistantNoticeDisabled,
            AssistantNotice.limit => l10n.assistantNoticeLimit,
            AssistantNotice.tooLong => l10n.assistantNoticeTooLong(assistantMaxTextLength),
            AssistantNotice.failed => l10n.assistantNoticeFailed,
            AssistantNotice.personNotFound => l10n.assistantNoticePersonNotFound(s),
            AssistantNotice.groupNotFound => l10n.assistantNoticeGroupNotFound(s),
            AssistantNotice.noEvent => l10n.assistantNoticeNoEvent,
            AssistantNotice.noData => l10n.assistantNoticeNoData,
            AssistantNotice.songNotFound => l10n.assistantNoticeSongNotFound(s),
            AssistantNotice.noHelp => l10n.assistantNoticeNoHelp,
            AssistantNotice.noBirthdays => l10n.assistantNoticeNoBirthdays,
          },
          style: text,
        );

      case ChoiceReply(:final query, :final options):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.assistantChoiceWhich(query), style: text),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in options)
                  ActionChip(
                    label: Text(o.label),
                    onPressed: () => ref.read(assistantChatNotifierProvider.notifier).choose(o.label, o.command),
                  ),
              ],
            ),
          ],
        );

      case RateReply r:
        final percent = r.rate.percent ?? 0;
        final color = percent >= 75 ? style.good : (percent >= 50 ? Colors.orange.shade700 : style.bad);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.isMe
                  ? l10n.assistantRateMe
                  : r.subjectName == null
                      ? l10n.assistantRateAll
                      : l10n.assistantRateOf(r.subjectName!),
              style: title,
            ),
            Text(l10n.assistantRateRange(_day(r.range.from), _day(r.range.to)), style: muted),
            if (r.typeName != null) Text(l10n.assistantRateOnlyType(r.typeName!), style: muted),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('$percent %', style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(width: 14),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 10,
                      color: color,
                      backgroundColor: style.line,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(l10n.assistantRateDetail(r.rate.attended, r.rate.total), style: muted),
            if (r.lowest.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.assistantRateLowest, style: text.copyWith(fontWeight: FontWeight.w600)),
              for (final p in r.lowest)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(p.name, style: text)),
                      Text('${p.percent} %', style: muted),
                    ],
                  ),
                ),
            ],
            if (r.personId != null && !r.isMe && seesOthers)
              link(l10n.assistantRateOpenPerson,
                  redesign ? RedesignRoutes.person(r.personId!) : '/people/${r.personId}'),
          ],
        );

      case EventReply e:
        Widget cell(String s, {Color? color, bool bold = false}) => SizedBox(
              width: 58,
              child: Text(s,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: color ?? style.text, fontWeight: bold ? FontWeight.w600 : null)),
            );
        Widget head(IconData icon, String label, Color color) => SizedBox(
              width: 58,
              child: Align(
                alignment: Alignment.centerRight,
                child: Tooltip(
                  message: label,
                  child: Semantics(label: label, child: Icon(icon, size: 18, color: color)),
                ),
              ),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.title, style: title),
            Text(
              e.startTime == null
                  ? _weekdayDate(e.date)
                  : '${_weekdayDate(e.date)} · ${l10n.assistantEventTime(_time(e.startTime!))}',
              style: muted,
            ),
            const SizedBox(height: 10),
            // Column heads as icons (any language fits), named for screen
            // readers and on long press.
            Row(
              children: [
                const Expanded(child: SizedBox()),
                head(Icons.check_circle, l10n.assistantEventPresent, style.good),
                head(Icons.cancel, l10n.assistantEventAbsent, style.bad),
                head(Icons.help, l10n.assistantEventOpen, style.muted),
              ],
            ),
            for (final g in e.groups)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(g.name, style: text, overflow: TextOverflow.ellipsis)),
                    cell('${g.present}'),
                    cell('${g.absent}'),
                    cell('${g.open}'),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            if (e.open.isEmpty)
              Text(l10n.assistantEventAllAnswered, style: muted)
            else ...[
              Text(l10n.assistantEventOpenNames, style: text.copyWith(fontWeight: FontWeight.w600)),
              Text(e.open.join(', '), style: muted),
            ],
            if (e.absent.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(l10n.assistantEventAbsentNames, style: text.copyWith(fontWeight: FontWeight.w600)),
              Text(e.absent.join(', '), style: muted),
            ],
            link(l10n.assistantEventOpenEvent, eventLocation(e.attendanceId)),
          ],
        );

      case NextEventReply n:
        final times = [
          if (n.startTime != null) _time(n.startTime!),
          if (n.endTime != null) _time(n.endTime!),
        ].join(' – ');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.assistantNextTitle, style: muted),
            Text(n.title, style: title),
            const SizedBox(height: 4),
            Text(_weekdayDate(n.date), style: text),
            if (times.isNotEmpty) Text(l10n.assistantEventTime(times), style: text),
            if ((n.place ?? '').isNotEmpty)
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 16, color: style.muted),
                  const SizedBox(width: 4),
                  Flexible(child: Text(n.place!, style: muted)),
                ],
              ),
            if (seesOthers || redesign) link(l10n.assistantEventOpenEvent, eventLocation(n.attendanceId)),
          ],
        );

      case BirthdaysReply b:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.assistantBirthdaysTitle, style: title),
            Text(l10n.assistantRateRange(_day(b.range.from), _day(b.range.to)), style: muted),
            const SizedBox(height: 8),
            for (final p in b.people)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Text('🎂 ', style: text),
                    Expanded(child: Text(p.name, style: text)),
                    Text('${DateFormat(dateFmt(DateFmtKind.dayMonth)).format(p.date)} · ${l10n.assistantBirthdaysAge(p.age)}',
                        style: muted),
                  ],
                ),
              ),
          ],
        );

      case SongReply s:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.number == null ? s.name : '${s.number}. ${s.name}', style: title),
            const SizedBox(height: 4),
            Text(
              s.lastSung == null ? l10n.assistantSongNever : l10n.assistantSongLastSung(_weekdayDate(s.lastSung!)),
              style: text,
            ),
            link(l10n.assistantSongOpen, redesign ? RedesignRoutes.work(s.songId) : '/settings/songs/${s.songId}'),
          ],
        );

      case HelpReply h:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.assistantHelpTitle, style: title),
            for (final a in h.articles) link(a.title, '/settings/help/article/${a.id}'),
          ],
        );
    }
  }
}
