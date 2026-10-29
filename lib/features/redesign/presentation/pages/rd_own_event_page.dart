import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../data/providers/rd_today_providers.dart' show rdSignoutDataProvider;
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../l10n/l10n.dart';
import '../../../self_service/presentation/pages/signout_page.dart' show signoutEventActions;
import '../../../self_service/presentation/widgets/self_service_event_actions.dart';
import '../widgets/event/rd_signout_sheet.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import '../widgets/today/rd_player_today.dart' show RdOwnAnswerSection;
import '../../data/rd_dates.dart';

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
({List<SelfServiceActionType> answer, List<SelfServiceActionType> info}) rdOwnEventActions(
  SelfServiceEventActions actions,
  CrossTenantPersonAttendance att, {
  bool past = false,
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
  final hasCard = !past && actions.quickActions(att) != null;
  final canAnswer = !past || att.isExcusedStatus;
  final all = actions.buildActions(att).map((a) => a.type).toList();
  return (
    answer: [
      if (canAnswer)
        for (final t in all)
          if (!infoTypes.contains(t) && !(hasCard && cardTypes.contains(t))) t,
    ],
    info: [for (final t in all) if (infoTypes.contains(t)) t],
  );
}

/// REDESIGN: an own Termin for Spieler (canvas S3): the answer card, more
/// answer options, and the infos (Ablaufplan, Beschreibung, Anhang, Route,
/// Dateien) as rows instead of the action sheet. Every action runs through
/// [SelfServiceEventActions.runAction] like in "Meine Termine".
class RdOwnEventPage extends ConsumerWidget {
  const RdOwnEventPage({super.key, required this.personAttendanceId});

  final String personAttendanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
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
    final past = rdIsPastOwnEvent(data!, att);
    final split = rdOwnEventActions(actions, att, past: past);
    final typeName = att.attendanceType?.name ?? '';
    final start = EventListUtils.parse(att.date);
    final locale = currentIntlLocale();
    final days = att.effectiveDurationDays ?? 1;
    final date = start == null
        ? ''
        : days > 1
            ? '${DateFormat.MMMMEEEEd(locale).format(start)} – '
                '${DateFormat.MMMMEEEEd(locale).format(rdAddDays(start, days - 1))}'
            : DateFormat.MMMMEEEEd(locale).format(start);
    final time = [att.startTime ?? '', att.endTime ?? ''].where((s) => s.isNotEmpty).join(' – ');
    final meta = [date, time].where((s) => s.isNotEmpty).join(' · ');

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

    children.addAll([
      if (typeName.isNotEmpty && typeName != att.eventTitle)
        Align(
          alignment: Alignment.centerLeft,
          child: RdPill(typeName, tone: att.highlight ? RdTone.excused : RdTone.primary),
        ),
      const SizedBox(height: 8),
      Semantics(header: true, child: Text(att.eventTitle, style: RdType.title(p))),
      if (meta.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(meta, style: RdType.meta(p, size: 15)),
      ],
      const SizedBox(height: 18),
      if (actions.isOwn(att) && !past)
        RdOwnAnswerSection(
          key: ValueKey('rd-own-answer-${att.id}'),
          attendance: att,
          showHeader: false,
          showEvent: false,
        ),
      if (split.answer.isNotEmpty) ...[
        const SizedBox(height: 24),
        RdGroupLabel(l10n.redesignOwnMore),
        RdGroupedList(children: [for (final t in split.answer) row(t)]),
      ],
      if (split.info.isNotEmpty) ...[
        const SizedBox(height: 24),
        RdGroupLabel(l10n.redesignOwnInfos),
        RdGroupedList(children: [for (final t in split.info) row(t)]),
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
