import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../parents/data/providers/parents_providers.dart';
import '../../../data/providers/rd_today_providers.dart';
import '../rd_widgets.dart';
import 'rd_today_common.dart';

/// REDESIGN: "Heute" of Eltern (canvas R2): the next Termine with the
/// answer of each child. Zu- und Absagen stay on the parents page.
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
                Builder(builder: (context) {
                  final start = rdStartOf(next.date, next.startTime);
                  final countdown = rdCountdown(
                    l10n,
                    start,
                    hasTime: next.startTime?.isNotEmpty ?? false,
                  );
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
                }),
                const SizedBox(height: 8),
                Semantics(
                  header: true,
                  child: Text(next.displayTitle, style: RdType.cardTitle(p)),
                ),
                Builder(builder: (context) {
                  final meta = [
                    EventListUtils.timeRange(next.startTime, next.endTime),
                    next.place ?? '',
                  ].where((s) => s.isNotEmpty).join(' · ');
                  if (meta.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(meta, style: RdType.meta(p, size: 15)),
                  );
                }),
                const SizedBox(height: 12),
                for (final child in next.childAttendances)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        RdInitials(rdInitialsOf(child.childName), size: 32),
                        const SizedBox(width: 10),
                        Expanded(child: Text(child.childFirstName, style: RdType.body(p))),
                        rdOwnStatusPill(l10n, child.status),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: RdPrimaryButton(
                    label: l10n.redesignTodayAnswerChildren,
                    icon: Icons.how_to_reg_outlined,
                    onPressed: () => context.go('/parents'),
                  ),
                ),
              ],
            ),
          ),
        if (upcoming.length > 1) ...[
          const SizedBox(height: 24),
          RdSectionHeader(
            l10n.redesignTodayUpNext,
            action: RdLinkButton(
              label: l10n.redesignCommonAll,
              onPressed: () => context.go('/parents'),
            ),
          ),
          RdGroupedList(
            children: [
              for (final g in upcoming.skip(1))
                RdEventRow(
                  date: g.date,
                  title: g.displayTitle,
                  meta: EventListUtils.timeRange(g.startTime, g.endTime),
                  trailing: g.allChildrenResponded
                      ? RdPill(l10n.redesignTodayAnswered, tone: RdTone.present)
                      : RdPill(l10n.redesignStatusOpen),
                  onTap: () => context.go('/parents'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
