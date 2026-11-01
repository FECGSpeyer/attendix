import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/services/tracking/tracking_event.dart';
import '../../../../../core/services/tracking/tracking_service.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../data/repositories/sign_in_out_repository.dart' show SignInType;
import '../../../../../l10n/l10n.dart';
import '../../../../parents/data/providers/parents_providers.dart';
import '../../../data/providers/rd_today_providers.dart';
import '../event/rd_signout_sheet.dart' show showRdReasonSheet;
import '../rd_widgets.dart';
import 'rd_today_common.dart';

/// REDESIGN: "Heute" of Eltern (canvas R2): the next Termine with the
/// answer of each child, answered right here per child (UX E1, same writes
/// as the parents page). More (plan, all Termine) stays on the parents page.
class RdParentToday extends ConsumerWidget {
  const RdParentToday({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(childrenAttendancesProvider);
    final children = ref.watch(parentChildrenProvider);

    if (!async.hasValue || !children.hasValue) {
      if (async.hasError || children.hasError) {
        return RdInfoCard(
          text: l10n.redesignTodayLoadFailed,
          icon: Icons.error_outline,
          action: RdOutlineButton(
            label: l10n.redesignCommonRetry,
            onPressed: () => ref.invalidate(parentChildrenProvider),
          ),
        );
      }
      return RdInfoCard(text: l10n.redesignTodayLoading, loading: true);
    }
    if (children.value!.isEmpty) {
      return RdInfoCard(text: l10n.redesignTodayNoChildren, icon: Icons.info_outline);
    }

    final upcoming = ref.watch(upcomingParentAttendancesProvider).take(3).toList();
    final next = upcoming.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next == null)
          RdInfoCard(text: l10n.redesignTodayNoUpcoming, icon: Icons.event_available_outlined)
        else
          RdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final start = rdStartOf(next.date, next.startTime);
                    final countdown = rdCountdown(l10n, start, hasTime: next.startTime?.isNotEmpty ?? false);
                    return Row(
                      children: [
                        Expanded(
                          child: RdEyebrow(
                            '${l10n.redesignTodayNextEvent}'
                            '${start == null ? '' : ' · ${rdRelativeDay(l10n, start)}'}',
                          ),
                        ),
                        if (countdown != null) RdPill(countdown, tone: RdTone.primary),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Semantics(header: true, child: Text(next.displayTitle, style: RdType.cardTitle(p))),
                Builder(
                  builder: (context) {
                    final meta = [
                      EventListUtils.timeRange(next.startTime, next.endTime),
                      next.place ?? '',
                    ].where((s) => s.isNotEmpty).join(' · ');
                    if (meta.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(meta, style: RdType.meta(p, size: 15)),
                    );
                  },
                ),
                const SizedBox(height: 12),
                for (final child in next.childAttendances) RdChildAnswerRow(group: next, child: child),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: RdLinkButton(label: l10n.redesignTodayMore, onPressed: () => context.go('/parents')),
                ),
              ],
            ),
          ),
        if (upcoming.length > 1) ...[
          const SizedBox(height: 24),
          RdSectionHeader(
            l10n.redesignTodayUpNext,
            action: RdLinkButton(label: l10n.redesignCommonAll, onPressed: () => context.go('/parents')),
          ),
          RdGroupedList(
            children: [
              for (final g in upcoming.skip(1))
                RdEventRow(
                  date: g.date,
                  title: g.displayTitle,
                  meta: rdChildrenLine(l10n, g),
                  trailing:
                      g.allChildrenResponded
                          ? RdPill(l10n.redesignTodayAnswered, tone: RdTone.present)
                          : RdPill(l10n.redesignTodayOpenCount(rdOpenChildren(g))),
                  onTap: () => context.go('/parents'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Children of [g] without an answer yet.
int rdOpenChildren(ParentAttendanceGroup g) => g.childAttendances.where((c) => c.status.isNeutral).length;

/// "Mia ✓ · Ben offen" (UX E1); a single child shows only the time.
String rdChildrenLine(AppLocalizations l10n, ParentAttendanceGroup g) {
  final time = EventListUtils.timeRange(g.startTime, g.endTime);
  if (g.childAttendances.length < 2) return time;
  return g.childAttendances
      .map(
        (c) =>
            c.status.isNeutral
                ? l10n.redesignTodayChildOpen(c.childFirstName)
                : '${c.childFirstName} ${c.status.countsAsPresent ? '✓' : '✕'}',
      )
      .join(' · ');
}

/// One child of the next Termin: open → "Ist dabei" / "Kann nicht",
/// answered → status plus "Doch absagen" / "Doch dabei".
class RdChildAnswerRow extends ConsumerWidget {
  const RdChildAnswerRow({super.key, required this.group, required this.child, this.readOnly = false});

  final ParentAttendanceGroup group;
  final ChildPersonAttendance child;

  /// Past Termine: the status only, no answers.
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final busy = ref.watch(parentSignInOutNotifierProvider).isLoading;
    final id = child.id;
    final status = child.status;
    final canAnswer = id != null && !busy;

    final name = Row(
      children: [
        RdInitials(rdInitialsOf(child.childName), size: 32),
        const SizedBox(width: 10),
        Expanded(child: Text(child.childFirstName, style: RdType.body(p))),
      ],
    );

    if (readOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [Expanded(child: name), rdOwnStatusPill(l10n, status)]),
      );
    }

    // Open: both answers as equal buttons under the name, so they fit side
    // by side on a phone instead of wrapping into two rows.
    if (status.isNeutral) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            name,
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Row(
                children: [
                  // Same answer buttons as the Termine of Spieler.
                  Expanded(
                    child: RdOutlineButton(
                      label: l10n.redesignTodayChildYes,
                      icon: Icons.check,
                      color: p.present,
                      height: 44,
                      onPressed: canAnswer ? () => _signIn(context, ref) : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RdOutlineButton(
                      label: l10n.redesignTodayChildNo,
                      height: 44,
                      onPressed: canAnswer ? () => _signOut(context, ref) : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final yes = status == AttendanceStatus.present;
    final type = ref.watch(rdAttendanceTypeProvider(group.typeId));
    final lateAllowed = type?.availableStatuses == null || type!.availableStatuses!.contains(AttendanceStatus.late);
    // Same changes as the old parents page: a Zusage unless already "Dabei"
    // (after "verspätet" / "kommt später" too), and the reason sheet (absent
    // or late) unless already absent without a late option. After a Zusage
    // it reads "Doch absagen", after an Absage "Ändern" (other reason, or
    // late after all).
    final links = [
      if (canAnswer && !yes) RdTextLink(label: l10n.redesignTodayYesAfterAll, onTap: () => _signIn(context, ref)),
      if (canAnswer && (status != AttendanceStatus.absent || lateAllowed))
        RdTextLink(
          label: status.countsAsPresent ? l10n.redesignTodayNoAfterAll : l10n.redesignTodayChangeAnswer,
          onTap: () => _signOut(context, ref),
        ),
    ];
    final pill =
        yes
            ? RdPill(l10n.redesignTodayChildIn, tone: RdTone.present, icon: Icons.check)
            : rdOwnStatusPill(l10n, status);
    final answer =
        links.length < 2
            ? Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.end,
              children: [pill, ...links],
            )
            : Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [pill, Wrap(spacing: 4, alignment: WrapAlignment.end, children: links)],
            );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: name),
          const SizedBox(width: 8),
          Flexible(flex: 2, child: Align(alignment: Alignment.centerRight, child: answer)),
        ],
      ),
    );
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final id = child.id;
    if (id == null) return;
    final notifier = ref.read(parentSignInOutNotifierProvider.notifier);
    final ok = await notifier.signInAll([(id, SignInType.fromStatus(child.status))]);
    if (!context.mounted) return;
    if (ok) {
      ref.read(trackingServiceProvider).track(TrackingEvent.parentSignIn, properties: {'count': 1});
    } else {
      _failed(context);
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final id = child.id;
    if (id == null) return;
    final tenant = ref.read(currentTenantProvider);
    final type = ref.read(rdAttendanceTypeProvider(group.typeId));
    final lateAllowed = type?.availableStatuses == null || type!.availableStatuses!.contains(AttendanceStatus.late);
    final choice = await showRdReasonSheet(
      context,
      title: '${child.childFirstName} · ${group.displayTitle}',
      meta: EventListUtils.timeRange(group.startTime, group.endTime),
      absenceReasons: EventListUtils.absenceReasonsOf(tenant?.absenceReasons),
      lateReasons: EventListUtils.lateReasonsOf(tenant?.lateReasons),
      allowLate: lateAllowed,
      ownReasonFirst: group.isRunning,
    );
    if (choice == null || !context.mounted) return;
    await ref.read(parentSignInOutNotifierProvider.notifier).signOut([id], choice.reason, isLateComing: choice.isLate);
    if (!context.mounted) return;
    if (ref.read(parentSignInOutNotifierProvider).hasError) {
      _failed(context);
    } else {
      ref
          .read(trackingServiceProvider)
          .track(TrackingEvent.parentSignOut, properties: {'count': 1, 'isLate': choice.isLate});
    }
  }

  void _failed(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.l10n.redesignTodayChildFailed)));
  }
}
