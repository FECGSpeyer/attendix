import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../data/providers/rd_today_providers.dart' show rdSignoutDataProvider;
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../l10n/l10n.dart';
import '../../../self_service/presentation/pages/signout_page.dart' show signoutEventActions;
import '../../../self_service/presentation/widgets/self_service_event_actions.dart';
import '../../data/providers/rd_phase_tick_provider.dart';
import '../../data/rd_event_phase.dart';
import '../widgets/event/rd_event_head.dart';
import '../widgets/event/rd_event_now.dart';
import '../widgets/event/rd_event_sections.dart' show RdSectionLabel;
import '../widgets/event/rd_own_event_cards.dart';
import '../widgets/event/rd_signout_sheet.dart';
import '../widgets/event/rd_own_program.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import '../widgets/today/rd_player_today.dart' show RdOwnAnswerSection;

/// The own Termin with [id] (person_attendances id) in [data], or null.
CrossTenantPersonAttendance? rdFindOwnEvent(SignoutData data, String id) {
  for (final a in [...data.allUpcoming, ...data.past]) {
    if (a.id == id) return a;
  }
  return null;
}

/// Whether [att] is one of the past Termine of [data].
bool rdIsPastOwnEvent(SignoutData data, CrossTenantPersonAttendance att) =>
    data.past.any((a) => a.id == att.id);

/// Entries of the Termin action sheet that the answer card does not
/// already offer as buttons, split into "Mehr" (answer) and infos.
///
/// A [past] Termin has no answer card; like the past rows of "Meine
/// Termine" only an excused one keeps its answer actions (Ionic opens the
/// action sheet there and nowhere else).
/// [onCard]: what the card at the top offers instead (default: the answer
/// card's "Bin dabei" / "Komme später" / "Kann nicht").
({List<SelfServiceActionType> answer, List<SelfServiceActionType> info}) rdOwnEventActions(
  SelfServiceEventActions actions,
  CrossTenantPersonAttendance att, {
  bool past = false,
  Set<SelfServiceActionType>? onCard,
}) {
  const infoTypes = {
    SelfServiceActionType.showPlan,
    SelfServiceActionType.showDescription,
    SelfServiceActionType.openAttachment,
    SelfServiceActionType.openNavigation,
    SelfServiceActionType.openFiles,
  };
  const cardTypes = {
    SelfServiceActionType.signIn,
    SelfServiceActionType.undoSignout,
    SelfServiceActionType.signOut,
    SelfServiceActionType.enterLate,
  };
  final hasCard = !past && actions.quickActions(att, anyLate: true) != null;
  final shown = hasCard ? (onCard ?? cardTypes) : const <SelfServiceActionType>{};
  final canAnswer = !past || att.isExcusedStatus;
  final all = actions.buildActions(att).map((a) => a.type).toList();
  return (
    answer: [
      if (canAnswer)
        for (final t in all)
          if (!infoTypes.contains(t) && !shown.contains(t)) t,
    ],
    info: [for (final t in all) if (infoTypes.contains(t)) t],
  );
}

/// REDESIGN: an own Termin for Spieler (concept "Termin-Bereich neu",
/// S1–S3): the same head as the Leitung's page; a card at the top that
/// follows the phase (before: "Du bist eingeplant" with "Abmelden" and
/// "Komme später"; running: "Jetzt im Ablauf" with "Deine Noten öffnen";
/// afterwards: "Deine Anwesenheit"), the Programm, the shared Ablauf and
/// the infos as rows. Every action runs through
/// [SelfServiceEventActions.runAction] like in "Meine Termine".
class RdOwnEventPage extends ConsumerWidget {
  const RdOwnEventPage({super.key, required this.personAttendanceId, this.now});

  final String personAttendanceId;

  /// For tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(rdSignoutDataProvider);
    final data = async.valueOrNull;
    final att = data == null ? null : rdFindOwnEvent(data, personAttendanceId);

    final children = <Widget>[
      RdBackLink(
        label: l10n.redesignTabEvents,
        onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.events),
      ),
      const SizedBox(height: 4),
    ];

    if (att == null) {
      children.add(data == null && !async.hasError
          ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
          : RdInfoCard(
              text: async.hasError ? l10n.redesignTodayLoadFailed : l10n.redesignOwnNotFound,
              icon: Icons.event_busy_outlined,
              action: RdOutlineButton(
                label: l10n.redesignCommonRetry,
                onPressed: () => ref.invalidate(signoutDataProvider),
              ),
            ));
      return RdPage(children: children);
    }

    final tenant = ref.watch(currentTenantProvider);
    final player = ref.watch(currentSelfServicePlayerProvider).valueOrNull;
    final actions = signoutEventActions(context, ref, tenant: tenant, player: player);
    final type = att.attendanceType;
    final day = EventListUtils.parse(att.date);
    final startTime = att.startTime ?? type?.startTime;
    final endTime = att.endTime ?? type?.endTime;
    final span = rdEventSpan(
      day: day,
      startTime: startTime,
      endTime: endTime,
      durationDays: att.effectiveDurationDays,
    );
    // Head and top card follow the phase without new data.
    if (span != null && now == null) ref.watch(rdPhaseTickProvider((start: span.start, end: span.end)));
    final phase = rdEventPhase(span, now: now);
    final running = phase == RdEventPhase.running;
    // Over once its end time has passed, not only from the next day on; a
    // Termin until 01:00 still runs after midnight although the list
    // already counts it as past.
    final ended = !running && (rdIsPastOwnEvent(data!, att) || phase == RdEventPhase.after);
    final own = actions.isOwn(att);
    final qa = actions.quickActions(att, anyLate: true);
    final plan = !ended && att.hasPlan ? rdPlanFromJson(att.plan) : null;
    final nowSlot = plan != null && running ? rdCurrentPlanSlot(day, plan, now: now) : null;
    // Already "kommt später" (also set by the leads): nothing more to announce.
    final canLate = qa != null && qa.allowLate && !qa.blocked && !qa.late;
    // "Jetzt im Ablauf" only offers "Ich komme später"; everything else of
    // the answer card stays under "Mehr".
    final nowCard = own && nowSlot != null;
    final split = rdOwnEventActions(
      actions,
      att,
      past: ended,
      onCard: nowCard ? {if (canLate) SelfServiceActionType.enterLate} : null,
    );
    final noteLink = own && !ended && !nowCard && split.answer.contains(SelfServiceActionType.editNote);
    final answerRows = [
      for (final t in split.answer)
        if (!(noteLink && t == SelfServiceActionType.editNote)) t,
    ];
    final infoRows = [
      for (final t in split.info)
        if (!(plan != null && t == SelfServiceActionType.showPlan) &&
            !(ended && t == SelfServiceActionType.openNavigation))
          t,
    ];

    Future<void> run(SelfServiceActionType type) async {
      switch (type) {
        case SelfServiceActionType.signOut:
          await showRdSignoutSheet(context, att: att, actions: actions);
        case SelfServiceActionType.enterLate:
          await showRdSignoutSheet(context, att: att, actions: actions, late: true);
        default:
          await actions.runAction(context, att, type);
      }
    }

    RdListRow row(SelfServiceActionType type) => RdListRow(
          leading: RdRowIcon(type.icon),
          title: type.label(l10n),
          subtitle: type == SelfServiceActionType.openNavigation ? att.place : null,
          onTap: () => run(type),
        );

    final planBlock = plan == null
        ? const <Widget>[]
        : [
            const SizedBox(height: 24),
            RdSectionLabel(
              // Like the leads' page: the Termin's time stands in the head.
              l10n.redesignEventPlanSection,
              actionLabel: running ? l10n.redesignOwnPlanLive : l10n.redesignOwnPlanAll,
              actionIcon: Icons.chevron_right,
              onAction: () => run(SelfServiceActionType.showPlan),
            ),
            RdPlanTimeline(key: const Key('rd-own-plan'), day: day, plan: plan, limit: running ? null : 3, now: now),
          ];
    final program = att.attendanceId == null
        ? null
        : RdOwnProgramSection(
            tenantId: att.tenantId,
            attendanceId: att.attendanceId!,
            personId: att.personId,
            highlight: att.highlight,
            past: ended,
          );

    children.addAll([
      RdEventHead(
        title: att.eventTitle,
        phase: phase,
        span: span,
        typeName: type?.name,
        typeHighlight: att.highlight,
        timeRange: EventListUtils.timeRange(startTime, endTime),
        place: att.place ?? '',
        durationDays: att.effectiveDurationDays,
        now: now,
      ),
      const SizedBox(height: 18),
      if (ended && own && att.isMember)
        RdOwnAttendanceCard(attendance: att, now: now)
      else if (nowCard)
        RdOwnNowCard(
          attendance: att,
          plan: plan!,
          now: now,
          onLate: canLate ? () => run(SelfServiceActionType.enterLate) : null,
        )
      else if (!ended && own)
        RdOwnAnswerSection(
          key: ValueKey('rd-own-answer-${att.id}'),
          attendance: att,
          showHeader: false,
          showEvent: false,
          onNote: noteLink ? () => run(SelfServiceActionType.editNote) : null,
        ),
      // Läuft (S2): the Ablauf first, it is what members look at now.
      if (running) ...planBlock,
      if (program != null) program,
      if (!running) ...planBlock,
      if (answerRows.isNotEmpty) ...[
        const SizedBox(height: 24),
        RdGroupLabel(l10n.redesignOwnMore),
        RdGroupedList(children: [for (final t in answerRows) row(t)]),
      ],
      if (infoRows.isNotEmpty) ...[
        const SizedBox(height: 24),
        RdGroupLabel(l10n.redesignOwnInfos),
        RdGroupedList(children: [for (final t in infoRows) row(t)]),
      ],
    ]);

    return RdPage(
      onRefresh: () async {
        ref.invalidate(signoutDataProvider);
        await ref.read(rdSignoutDataProvider.future).catchError((_) => const SignoutData());
      },
      children: children,
    );
  }
}
