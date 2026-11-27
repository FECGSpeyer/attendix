import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/redesign_routes.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../l10n/l10n.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../../team_org_utils.dart';
import '../../../attendance/presentation/widgets/attendance_date_change.dart';
import '../../../../core/providers/attendance_providers.dart' show attendancesProvider, upcomingAttendancesProvider;
import 'agenda_picker_sheet.dart';
import 'quick_create_attendance.dart';
import 'tasks_tab.dart' show TeamOrgBadge, TeamOrgListSkeleton, priorityColor;
import '../../../../shared/widgets/adaptive/adaptive.dart';

part 'topics_tab_leader.dart';
part 'topics_tab_member.dart';

/// Tab "Themen": leadership reviews suggestions, plans the next Termin and
/// keeps the Themenspeicher; members suggest topics and see their suggestions.
class TopicsTab extends ConsumerWidget {
  const TopicsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLeader = ref.watch(isTeamLeaderProvider);
    if (isLeader) return const _LeaderTopics();
    if (ref.watch(inTeamCircleProvider)) return const _MemberTopics();
    // Ionic `.topic-empty` (chatbubbles icon, grey text).
    return ListView(children: [
      IonEmptyState(
        icon: AppIcons.forumOutlined,
        iconSize: 48,
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 16),
        text: context.l10n.teamOrgLeadersPlan,
      ),
    ]);
  }
}

/// ASTRA_SIGNOUT_TOPICS: caches refreshed after "Datum ändern" in the
/// Themen tab (Ionic `loadLeader` reloads the upcoming Termine).
void refreshAfterTopicsDateChange(ProviderContainer container) {
  container.invalidate(upcomingProtocolAttendancesProvider);
  container.invalidate(planAttendancesProvider);
  container.invalidate(orgPlansProvider);
  container.invalidate(attendancesProvider);
  container.invalidate(upcomingAttendancesProvider);
}
