import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/enums.dart';
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
import '../../../data/providers/rd_today_providers.dart' show rdNotMemberInfo, rdSignoutDataProvider, rdStartOf, rdTodayFocus;
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
                onTap: () => context.push('/settings/voice-leader'),
              ),
            ],
          ),
        ],
      ],
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
  });

  /// "Deine Zusage" above the card (Helfer).
  final bool showHeader;

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
    final player = ref.watch(currentSelfServicePlayerProvider).valueOrNull;
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
    if (data == null) {
      body = dataAsync.hasError
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
    final qa = actions.quickActions(att);
    final start = EventListUtils.parse(att.date);
    final startTime = att.startTime ?? att.attendanceType?.startTime;
    final hasTime = startTime?.isNotEmpty ?? false;
    final startAt = rdStartOf(att.date, startTime);
    final countdown = rdCountdown(l10n, startAt, hasTime: hasTime);
    final meta = att.eventMeta();
    final busy = _busy || ref.watch(signoutNotifierProvider).isLoading;

    String question;
    if (qa == null) {
      question = l10n.redesignTodayNotPart;
    } else if (att.isDutyRequested) {
      question = l10n.redesignTodayDutyQuestion;
    } else if (qa.present) {
      question = l10n.redesignTodayAnsweredYes;
    } else if (qa.late) {
      question = l10n.redesignTodayAnsweredLater;
    } else if (qa.excused || att.status == AttendanceStatus.absent) {
      question = l10n.redesignTodayAnsweredNo;
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
          Text(question, style: RdType.body(p).copyWith(fontWeight: FontWeight.w600)),
          // Ionic: hint of the instance below Termine without the person.
          if (qa == null && !att.isMember) ...[
            const SizedBox(height: 4),
            Text(rdNotMemberInfo(ref.watch(currentTenantProvider)), style: RdType.meta(p)),
          ],
          if (att.notes != null && att.notes!.isNotEmpty && qa != null && !qa.present) ...[
            const SizedBox(height: 4),
            Text(att.notes!, style: RdType.meta(p)),
          ],
          if (qa != null && !qa.canSignin && !qa.present && att.deadline != null) ...[
            const SizedBox(height: 4),
            Text(
              EventListUtils.deadlineText(att.deadline),
              style: RdType.meta(p, size: 13).copyWith(color: p.absent),
            ),
          ],
          const SizedBox(height: 12),
          if (qa != null) ..._answerButtons(context, att, actions, qa, busy),
          if (widget.showEvent) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: RdLinkButton(
                label: l10n.redesignTodayMore,
                onPressed: () => att.id != null
                    ? context.push(RedesignRoutes.ownEvent(att.id!))
                    : actions.presentActions(context, att, hideQuickActions: qa != null),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _answerButtons(
    BuildContext context,
    CrossTenantPersonAttendance att,
    SelfServiceEventActions actions,
    QuickActions qa,
    bool busy,
  ) {
    final p = context.rd;
    final l10n = context.l10n;
    final canSignOut = qa.allowExcuse && !qa.blocked;

    if (_choosingReason) {
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

    final yes = qa.present
        ? _AnsweredBox(label: l10n.redesignTodayYesDone, icon: Icons.check, tone: RdTone.present)
        : RdPrimaryButton(
            label: qa.excused || qa.late ? l10n.redesignTodayYesAfterAll : l10n.redesignTodayYes,
            icon: Icons.check,
            onPressed: qa.canSignin && !busy
                ? () => _run(() => actions.handleSigninWithFields(context, att))
                : null,
          );
    final no = qa.excused
        ? _AnsweredBox(label: l10n.redesignTodayNoDone, icon: Icons.close, tone: RdTone.excused)
        : qa.late
            ? _AnsweredBox(label: l10n.redesignStatusLater, icon: Icons.schedule, tone: RdTone.late)
            : RdOutlineButton(
                label: qa.present ? l10n.redesignTodayNoAfterAll : l10n.redesignTodayNo,
                icon: Icons.close,
                color: p.absent,
                onPressed: canSignOut && !busy ? () => setState(() => _choosingReason = true) : null,
              );

    return [
      Row(
        children: [
          Expanded(child: yes),
          const SizedBox(width: 10),
          Expanded(child: no),
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

/// Chosen answer shown in place of its button ("Zugesagt ✓").
class _AnsweredBox extends StatelessWidget {
  const _AnsweredBox({required this.label, required this.icon, required this.tone});

  final String label;
  final IconData icon;
  final RdTone tone;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final fg = p.toneColor(tone);
    return Semantics(
      label: label,
      selected: true,
      excludeSemantics: true,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: p.toneSoft(tone),
          borderRadius: BorderRadius.circular(p.buttonRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
