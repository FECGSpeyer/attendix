import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../people/presentation/pages/person_detail_page.dart'
    show personProvider, personAttendanceStatsProvider, personHistoryProvider;
import '../../../people/presentation/widgets/person_detail/person_detail.dart'
    show HistorieAccordion, UpcomingAppointmentsAccordion, upcomingAttendancesProvider;
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: "Verlauf" of a person (from "Alle Termine ansehen"): the
/// coming Termine and the whole history of the old person page, with its
/// status changes, in the new design.
class RdPersonHistoryPage extends ConsumerStatefulWidget {
  const RdPersonHistoryPage({super.key, required this.personId});

  final int personId;

  @override
  ConsumerState<RdPersonHistoryPage> createState() => _RdPersonHistoryPageState();
}

class _RdPersonHistoryPageState extends ConsumerState<RdPersonHistoryPage> {
  bool _showHistory = true;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final id = widget.personId;
    final person = ref.watch(personProvider(id)).valueOrNull;
    // Same rights as the history of the old person page.
    final role = ref.watch(currentRoleProvider);
    final hasLeft = person?.left != null;
    final canEdit = (role.isAdmin || role.isResponsible) && !hasLeft;
    final name = person == null ? '' : '${person.firstName} ${person.lastName}'.trim();

    return RdPage(
      // The old sections bring their own 16 px side margins.
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 32),
      onRefresh: () async {
        ref.invalidate(personHistoryProvider(id));
        ref.invalidate(personAttendanceStatsProvider(id));
        ref.invalidate(upcomingAttendancesProvider(id));
      },
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RdBackLink(
                label: name.isEmpty ? l10n.redesignTabMembers : name,
                onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.person(id)),
              ),
              const SizedBox(height: 4),
              Semantics(header: true, child: Text(l10n.redesignPersonHistory, style: RdType.title(p))),
              if (person == null) ...[
                const SizedBox(height: 12),
                RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
              ],
            ],
          ),
        ),
        if (person != null) ...[
          UpcomingAppointmentsAccordion(personId: id, initiallyExpanded: true),
          HistorieAccordion(
            isExpanded: _showHistory,
            onToggle: () => setState(() => _showHistory = !_showHistory),
            historyAsync: ref.watch(personHistoryProvider(id)),
            statsAsync: ref.watch(personAttendanceStatsProvider(id)),
            personId: id,
            canEdit: canEdit,
            hasLeft: hasLeft,
          ),
        ],
      ],
    );
  }
}
