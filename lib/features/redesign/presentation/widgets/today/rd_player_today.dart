import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/debug_providers.dart' show effectiveRoleProvider;
import '../../../../../core/providers/self_service_providers.dart';
import '../../../../../core/providers/signout_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/router/redesign_routes.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../self_service/presentation/pages/signout_page.dart'
    show signoutEventActions;
import '../../../../self_service/presentation/widgets/self_service_event_actions.dart';
import '../../../data/providers/rd_today_providers.dart'
    show rdDeadlineLabel, rdDeadlineUrgent, rdNotMemberInfo, rdOpenDeadline, rdSignoutDataProvider, rdStartOf, rdTodayFocus;
import '../event/rd_own_event_cards.dart' show RdStatusBox;
import '../event/rd_signout_sheet.dart';
import '../rd_widgets.dart';
import 'rd_today_common.dart';
import 'rd_duty_section.dart';

/// REDESIGN: "Heute" of Spieler and Stimmführer (canvas S1, R1): the own
/// answer for the next Termin in one tap, Abmelden with a reason in two,
/// then the next Termine.
class RdPlayerToday extends ConsumerWidget {
  const RdPlayerToday({super.key, required this.role});

  final Role role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final data = ref.watch(rdSignoutDataProvider).valueOrNull;
    final tenant = ref.watch(currentTenantProvider);
    final player = ref.watch(currentSelfServicePlayerProvider).valueOrNull;
    // Without the Termin of the card above (the next own one).
    final focus = data == null ? null : rdTodayFocus(data);
    final next = data?.allUpcoming.where((a) => !identical(a, focus)).take(4).toList() ??
        const <CrossTenantPersonAttendance>[];
    final actions = signoutEventActions(context, ref, tenant: tenant, player: player);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RdOwnAnswerSection(showHeader: false),
        const SizedBox(height: 24),
        RdSectionHeader(
          l10n.redesignTodayUpNext,
          action: RdLinkButton(
            label: l10n.redesignCommonAll,
            onPressed: () => context.go(RedesignRoutes.events),
          ),
        ),
        if (data == null)
          const SizedBox.shrink()
        else if (next.isEmpty)
          RdInfoCard(text: l10n.redesignTodayNothingElse)
        else
          RdGroupedList(
            children: [
              for (final att in next)
                RdEventRow(
                  date: att.date,
                  title: att.eventTitle,
                  meta: actions.isOwn(att)
                      ? att.eventMeta()
                      : [att.eventMeta(), rdNotMemberInfo(tenant)]
                          .where((s) => s.isNotEmpty)
                          .join('\n'),
                  trailing: actions.isOwn(att) ? rdOwnStatusPill(l10n, att.status) : null,
                  onTap: () => att.id != null && actions.isOwn(att)
                      ? context.push(RedesignRoutes.ownEvent(att.id!))
                      : actions.presentActions(context, att),
                ),
            ],
          ),
        // "Bitte bestätigen" and "Offene Dienste" (Dienstplan of "Meine Termine").
        const RdDutySection(),
        if (role.canSeeVoiceLeaderSettings) ...[
          const SizedBox(height: 24),
          RdGroupedList(
            children: [
              RdListRow(
                leading: RdRowIcon(Icons.groups_2_outlined),
                title: l10n.redesignTodayMySection,
                subtitle: l10n.redesignTodayMySectionHint,
                onTap: () => context.push('/settings/voice-leader?from=heute'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The own Termin row for [attendanceId] in [data]: the viewer is part of
/// that Termin of the group [tenantId] (helpers and leads who also play).
CrossTenantPersonAttendance? rdOwnEntryFor(SignoutData? data, int? attendanceId, int? tenantId) {
  if (data == null || attendanceId == null) return null;
  for (final a in data.allUpcoming) {
    if (a.isMember && a.id != null && a.attendanceId == attendanceId && a.tenantId == tenantId) return a;
  }
  return null;
}

/// One line with the own answer on a card or page that shows the whole
/// Termin (Heute of helpers, the leads' Termin page): "Du · Du bist dabei"
/// and "Ändern", which opens the own Termin page with the answer buttons.
class RdOwnAnswerRow extends StatelessWidget {
  const RdOwnAnswerRow({super.key, required this.attendance, this.label});

  final CrossTenantPersonAttendance attendance;

  /// Word in front of the answer; default "Du".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final status = attendance.status;
    final (String text, Color color) = switch (status) {
      AttendanceStatus.present => (l10n.redesignTodayYouAreIn, p.present),
      AttendanceStatus.late || AttendanceStatus.lateExcused => (l10n.redesignOwnComingLater, p.late),
      AttendanceStatus.excused => (l10n.redesignTodayYouAreOut, p.excused),
      AttendanceStatus.absent => (l10n.redesignStatusAbsent, p.absent),
      _ => (l10n.rdTextYouNoAnswer, p.text2),
    };
    final open = status == AttendanceStatus.neutral;
    final action = open ? l10n.rdTextYouAnswer : l10n.redesignTodayChangeAnswer;
    return Semantics(
      button: true,
      label: '${label ?? l10n.rdTeamTaskYou}: $text. $action',
      excludeSemantics: true,
      child: Material(
        color: p.soft,
        borderRadius: BorderRadius.circular(p.buttonRadius),
        child: InkWell(
          key: const Key('rd-own-answer-row'),
          borderRadius: BorderRadius.circular(p.buttonRadius),
          onTap: () => context.push(RedesignRoutes.ownEvent(attendance.id!)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Text(
                    label ?? l10n.rdTeamTaskYou,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.text),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
                    ),
                  ),
                  Text(action, style: TextStyle(fontSize: 15, color: p.link)),
                  Icon(Icons.chevron_right, size: 18, color: p.link),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Own answer for the next Termin (Spieler; Helfer below their Termin card).
class RdOwnAnswerSection extends ConsumerStatefulWidget {
  const RdOwnAnswerSection({
    super.key,
    this.showHeader = true,
    this.attendance,
    this.showEvent = true,
    this.onNote,
  });

  /// "Deine Zusage" above the card (Helfer).
  final bool showHeader;

  /// "Notiz an die Leitung" below the buttons.
  final VoidCallback? onNote;

  /// The Termin to answer; null: the next one (Heute).
  final CrossTenantPersonAttendance? attendance;

  /// Eyebrow, title and time in the card (not on the Termin's own page,
  /// which shows them above; there the card has no "Mehr zum Termin").
  final bool showEvent;

  @override
  ConsumerState<RdOwnAnswerSection> createState() => _RdOwnAnswerSectionState();
}

class _RdOwnAnswerSectionState extends ConsumerState<RdOwnAnswerSection> {
  /// Reason chips of "Abmelden" are open.
  bool _choosingReason = false;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOutWith(
    SelfServiceEventActions actions,
    CrossTenantPersonAttendance att,
    String reason,
  ) async {
    await actions.submitSignout(context, att, reason, isLate: false);
    if (mounted) setState(() => _choosingReason = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dataAsync = ref.watch(rdSignoutDataProvider);
    final playerAsync = ref.watch(currentSelfServicePlayerProvider);
    final player = playerAsync.valueOrNull;
    final tenant = ref.watch(currentTenantProvider);

    final Widget body;
    final data = dataAsync.valueOrNull;
    final given = widget.attendance;
    if (given != null) {
      return _card(
        context,
        given,
        signoutEventActions(context, ref, tenant: tenant, player: player),
      );
    }
    // Right after sign-in the own person is still loading: wait instead of
    // saying "not a member" for a moment.
    if (data == null || (player == null && playerAsync.isLoading)) {
      body = data == null && dataAsync.hasError
          ? RdInfoCard(
              text: l10n.redesignTodayLoadFailed,
              icon: Icons.error_outline,
              action: RdOutlineButton(
                label: l10n.redesignCommonRetry,
                onPressed: () => ref.invalidate(signoutDataProvider),
              ),
            )
          : RdInfoCard(text: l10n.redesignTodayLoading, loading: true);
    } else if (player == null) {
      // Helfer without an own member entry.
      if (widget.showHeader) return const SizedBox.shrink();
      body = RdInfoCard(text: l10n.redesignTodayNoMember, icon: Icons.info_outline);
    } else if (rdTodayFocus(data) case final focus?) {
      body = _card(
        context,
        focus,
        signoutEventActions(context, ref, tenant: tenant, player: player),
      );
    } else {
      body = RdInfoCard(
        text: l10n.redesignTodayNoUpcoming,
        icon: Icons.event_available_outlined,
      );
    }

    if (!widget.showHeader) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [RdSectionHeader(l10n.redesignTodayYourAnswer), body],
    );
  }

  Widget _card(
    BuildContext context,
    CrossTenantPersonAttendance att,
    SelfServiceEventActions actions,
  ) {
    final p = context.rd;
    final l10n = context.l10n;
    final qa = actions.quickActions(att, anyLate: true);
    final start = EventListUtils.parse(att.date);
    final startTime = att.startTime ?? att.attendanceType?.startTime;
    final hasTime = startTime?.isNotEmpty ?? false;
    final startAt = rdStartOf(att.date, startTime);
    final countdown = rdCountdown(l10n, startAt, hasTime: hasTime);
    final meta = att.eventMeta();
    final busy = _busy || ref.watch(signoutNotifierProvider).isLoading;
    // UX S5: the deadline shows while answering is still possible, not only
    // once it has passed.
    final openDeadline = qa != null && qa.canSignin && !qa.present ? rdOpenDeadline(att.deadline) : null;

    // Answered: the own answer first, the other answers below it (the same
    // on Heute and on the Termin's page). A requested Dienst is a question.
    final answered = qa != null &&
        !att.isDutyRequested &&
        (qa.present || qa.late || qa.excused || att.status == AttendanceStatus.absent);

    final String question;
    if (qa == null) {
      question = l10n.redesignTodayNotPart;
    } else if (att.isDutyRequested) {
      question = l10n.redesignTodayDutyQuestion;
    } else {
      question = l10n.redesignTodayQuestion;
    }

    return RdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showEvent) ...[
            Row(
              children: [
                Expanded(
                  child: RdEyebrow(
                    '${l10n.redesignTodayNextEvent}'
                    '${start == null ? '' : ' · ${rdRelativeDay(l10n, start)}'}',
                  ),
                ),
                if (countdown != null) RdPill(countdown, tone: RdTone.primary),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text(att.eventTitle, style: RdType.cardTitle(p)),
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(meta, style: RdType.meta(p, size: 15)),
            ],
            const SizedBox(height: 16),
          ] else if (countdown != null) ...[
            RdPill(countdown, tone: RdTone.primary),
            const SizedBox(height: 10),
          ],
          if (answered)
            _answerBox(context, att, qa)
          else ...[
            Text(question, style: RdType.body(p).copyWith(fontWeight: FontWeight.w600)),
            // Ionic: hint of the instance below Termine without the person.
            if (qa == null && !att.isMember) ...[
              const SizedBox(height: 4),
              Text(rdNotMemberInfo(ref.watch(currentTenantProvider)), style: RdType.meta(p)),
            ],
            if (att.notes != null && att.notes!.isNotEmpty && qa != null) ...[
              const SizedBox(height: 4),
              Text(att.notes!, style: RdType.meta(p)),
            ],
          ],
          if (qa != null && !qa.canSignin && !qa.present && att.deadline != null) ...[
            SizedBox(height: answered ? 8 : 4),
            Text(
              EventListUtils.deadlineText(att.deadline),
              style: RdType.meta(p, size: 13).copyWith(color: p.absent),
            ),
          ],
          if (openDeadline != null) ...[
            const SizedBox(height: 6),
            _DeadlineHint(deadline: openDeadline),
          ],
          const SizedBox(height: 12),
          if (qa != null && _choosingReason)
            ..._reasonChips(context, att, actions, busy)
          else if (qa != null && answered)
            ..._changeButtons(context, att, actions, qa, busy)
          else if (qa != null)
            ..._askButtons(context, att, actions, qa, busy),
          if (widget.onNote != null) _noteLink(context),
          if (widget.showEvent) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: RdLinkButton(
                label: l10n.redesignTodayMore,
                onPressed: () {
                  // Who may open the Termin of the group (helpers, leads)
                  // gets its one page: all answers, with the own one on top.
                  final leads =
                      att.attendanceId != null &&
                      att.tenantId == ref.read(currentTenantProvider)?.id &&
                      ref.read(effectiveRoleProvider).canAddAttendance;
                  if (leads) {
                    context.push(RedesignRoutes.event(att.attendanceId!));
                  } else if (att.id != null) {
                    context.push(RedesignRoutes.ownEvent(att.id!));
                  } else {
                    actions.presentActions(context, att, hideQuickActions: qa != null);
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _noteLink(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: RdLinkButton(
          key: const Key('rd-own-note'),
          label: context.l10n.redesignOwnNoteToLeaders,
          onPressed: widget.onNote!,
        ),
      );

  /// The own answer on a soft field in its colour, with the reason or time
  /// given ("Du kommst später" / "ca. 20:00").
  Widget _answerBox(BuildContext context, CrossTenantPersonAttendance att, QuickActions qa) {
    final l10n = context.l10n;
    final note = (att.notes ?? '').trim();
    final ({String label, String? detail, RdTone tone, IconData icon}) look;
    if (qa.present) {
      look = (label: l10n.redesignTodayYouAreIn, detail: null, tone: RdTone.present, icon: Icons.check);
    } else if (qa.late) {
      look = (
        label: l10n.redesignOwnComingLater,
        detail: note.isEmpty ? null : note,
        tone: RdTone.late,
        icon: Icons.schedule,
      );
    } else if (qa.excused) {
      look = (
        label: l10n.redesignTodayYouAreOut,
        detail: note.isEmpty ? null : l10n.redesignTodayReasonIs(note),
        tone: RdTone.excused,
        icon: Icons.event_busy_outlined,
      );
    } else {
      // Recorded as absent by the leads.
      look = (label: l10n.redesignStatusAbsent, detail: null, tone: RdTone.absent, icon: Icons.close);
    }
    return RdStatusBox(
      key: const Key('rd-own-status'),
      label: look.label,
      detail: look.detail,
      tone: look.tone,
      icon: look.icon,
    );
  }

  /// "Antwort ändern": the answers other than the own one, as equal calm
  /// buttons with the words of the first answer. An answer that is not
  /// possible has no button (deadline over: the line above says so).
  List<Widget> _changeButtons(
    BuildContext context,
    CrossTenantPersonAttendance att,
    SelfServiceEventActions actions,
    QuickActions qa,
    bool busy,
  ) {
    final p = context.rd;
    final l10n = context.l10n;
    // "A": recorded as absent by the leads, only a Zusage changes that.
    final recorded = att.text == 'A';
    final canYes = !qa.present && qa.canSignin;
    // Back to coming (also later) only while the deadline is open.
    final canLate = !qa.late && qa.allowLate && !recorded && (qa.present || qa.canSignin);
    final canNo = !qa.excused && qa.allowExcuse && !recorded;
    final buttons = <Widget>[
      if (canYes)
        RdOutlineButton(
          key: const Key('rd-own-signin'),
          label: l10n.redesignTodayYes,
          onPressed: busy ? null : () => _run(() => actions.handleSigninWithFields(context, att)),
        ),
      if (canLate)
        RdOutlineButton(
          key: const Key('rd-own-late'),
          label: l10n.redesignOwnComeLater,
          onPressed: busy ? null : () => _run(() => showRdSignoutSheet(context, att: att, actions: actions, late: true)),
        ),
      if (canNo)
        RdOutlineButton(
          key: const Key('rd-own-signout'),
          label: l10n.redesignTodayNo,
          onPressed: busy ? null : () => setState(() => _choosingReason = true),
        ),
    ];
    return [
      // Nothing to choose because this kind of Termin has no Abmelden.
      if (qa.present && !qa.allowExcuse && !qa.allowLate)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(l10n.redesignTodayNoSignOut, style: RdType.meta(p, size: 13)),
        ),
      if (buttons.isNotEmpty) ...[
        Text(l10n.redesignTodayChangeTo, style: RdType.meta(p, size: 13)),
        const SizedBox(height: 6),
        // Small phones: one below the other, so "Komme später" is not cut.
        LayoutBuilder(
          builder: (context, box) => box.maxWidth < 280
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      buttons[i],
                    ],
                  ],
                )
              : Row(
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: buttons[i]),
                    ],
                  ],
                ),
        ),
      ],
    ];
  }

  /// "Warum kannst du nicht?": the reasons of the group as chips.
  List<Widget> _reasonChips(
    BuildContext context,
    CrossTenantPersonAttendance att,
    SelfServiceEventActions actions,
    bool busy,
  ) {
    final p = context.rd;
    final l10n = context.l10n;
    return [
      Text(l10n.redesignTodayWhyNot, style: RdType.meta(p)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final reason in actions.absenceReasons)
            RdChoiceChip(
              label: reason,
              selected: false,
              onTap: busy ? null : () => _run(() => _signOutWith(actions, att, reason)),
            ),
          RdChoiceChip(
            label: l10n.redesignTodayOtherReason,
            selected: false,
            onTap: busy
                ? null
                : () => _run(() async {
                      await showRdSignoutSheet(context, att: att, actions: actions);
                      if (mounted) setState(() => _choosingReason = false);
                    }),
          ),
        ],
      ),
      const SizedBox(height: 8),
      RdLinkButton(
        label: l10n.redesignCommonCancel,
        onPressed: () => setState(() => _choosingReason = false),
      ),
    ];
  }

  /// Not answered yet: "Bin dabei" as the one main button, "Kann nicht"
  /// next to it, "Ich komme später …" below.
  List<Widget> _askButtons(
    BuildContext context,
    CrossTenantPersonAttendance att,
    SelfServiceEventActions actions,
    QuickActions qa,
    bool busy,
  ) {
    final p = context.rd;
    final l10n = context.l10n;
    final canSignOut = qa.allowExcuse && !qa.blocked;
    return [
      Row(
        children: [
          Expanded(
            child: RdPrimaryButton(
              label: l10n.redesignTodayYes,
              icon: Icons.check,
              onPressed: qa.canSignin && !busy ? () => _run(() => actions.handleSigninWithFields(context, att)) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RdOutlineButton(
              label: l10n.redesignTodayNo,
              icon: Icons.close,
              color: p.absent,
              onPressed: canSignOut && !busy ? () => setState(() => _choosingReason = true) : null,
            ),
          ),
        ],
      ),
      if (qa.allowLate && !qa.blocked)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: RdLinkButton(
            label: l10n.redesignTodayLater,
            onPressed: busy
                ? () {}
                : () => _run(() => showRdSignoutSheet(context, att: att, actions: actions, late: true)),
          ),
        ),
    ];
  }
}

/// "Antwort bis Fr 2.11., 18:00"; red in the last 24 hours.
class _DeadlineHint extends StatelessWidget {
  const _DeadlineHint({required this.deadline});

  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final color = rdDeadlineUrgent(deadline) ? p.absent : p.text2;
    return Row(
      children: [
        Icon(Icons.schedule, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            context.l10n.redesignTodayDeadline(rdDeadlineLabel(deadline)),
            style: RdType.meta(p, size: 13).copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
