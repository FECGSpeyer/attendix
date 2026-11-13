import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/redesign_routes.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../parents/data/providers/parents_providers.dart';
import '../event/rd_parent_event_card.dart' show RdParentEventCard, showRdParentEventSheet;
import '../rd_widgets.dart';
import 'rd_parent_today.dart' show RdChildrenNextCard;
import 'rd_today_common.dart';

/// U9b "Meine Kinder" on Heute: an account with its own role (Mitglied,
/// Helfer, Leitung) that is also linked as Elternteil answers for its
/// children below its own content, like the Eltern Heute. Renders nothing
/// without linked children.
class RdMyChildrenToday extends ConsumerWidget {
  const RdMyChildrenToday({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasChildrenBesideRoleProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final async = ref.watch(childrenAttendancesProvider);
    final upcoming = ref.watch(upcomingParentAttendancesProvider);
    final next = upcoming.firstOrNull;
    return Padding(
      key: const Key('rd-my-children-today'),
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdSectionHeader(
            l10n.parentRegisterMyChildren,
            action: upcoming.length > 1
                ? RdLinkButton(label: l10n.redesignCommonAll, onPressed: () => context.go(RedesignRoutes.events))
                : null,
          ),
          if (async.hasError)
            RdInfoCard(
              text: l10n.redesignTodayLoadFailed,
              icon: Icons.error_outline,
              action: RdOutlineButton(
                label: l10n.redesignCommonRetry,
                onPressed: () => ref.invalidate(childrenAttendancesProvider),
              ),
            )
          else if (!async.hasValue)
            RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
          else if (next == null)
            RdInfoCard(text: l10n.parentRegisterMyChildrenNoUpcoming, icon: Icons.event_available_outlined)
          else
            RdChildrenNextCard(
              group: next,
              onMore: () => showRdParentEventSheet(context, next.attendanceId),
            ),
        ],
      ),
    );
  }
}

/// U9b "Meine Kinder" on Termine (Kommend): the children's next Termine as
/// in the Eltern list, three at first. Renders nothing without linked
/// children or without upcoming Termine of them.
class RdMyChildrenEvents extends ConsumerStatefulWidget {
  const RdMyChildrenEvents({super.key});

  @override
  ConsumerState<RdMyChildrenEvents> createState() => _RdMyChildrenEventsState();
}

class _RdMyChildrenEventsState extends ConsumerState<RdMyChildrenEvents> {
  static const _first = 3;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(hasChildrenBesideRoleProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final upcoming = ref.watch(upcomingParentAttendancesProvider);
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final shown = _all ? upcoming : upcoming.take(_first).toList();
    return Padding(
      key: const Key('rd-my-children-events'),
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdSectionHeader(
            l10n.parentRegisterMyChildren,
            action: upcoming.length > _first
                ? RdLinkButton(
                    label: _all
                        ? l10n.parentRegisterMyChildrenShowLess
                        : l10n.parentRegisterMyChildrenShowAll(upcoming.length),
                    onPressed: () => setState(() => _all = !_all),
                  )
                : null,
          ),
          for (final g in shown) ...[
            RdParentEventCard(group: g),
            if (g != shown.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
