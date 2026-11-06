import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../l10n/l10n.dart';
import '../../data/providers/rd_events_providers.dart';
import '../widgets/rd_split_view.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;
import 'rd_event_page.dart';
import 'rd_events_page.dart';

/// REDESIGN: "Termine" on wide screens (canvas "Beta: Desktop-UX", A).
///
/// The right column is never empty: until a Termin is chosen on the left,
/// the next upcoming Termin is open there. Roles that do not open the
/// Termin page from the list (Mitglieder, Eltern) keep the list alone.
class RdEventsSplitHome extends ConsumerWidget {
  const RdEventsSplitHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(effectiveRoleProvider);
    if (role.isParent || !role.canSeeAttendanceTab || !role.canAddAttendance) {
      return const RdEventsPage();
    }
    final async = ref.watch(realtimeAttendanceListProvider);
    final all = async.valueOrNull;
    final types = ref.watch(attendanceTypesProvider).valueOrNull ?? const <AttendanceType>[];
    final next = all == null ? null : rdUpcoming(all, types: types).where((a) => a.id != null).firstOrNull?.id;
    final l10n = context.l10n;
    return RdSplitView(
      list: const RdEventsPage(),
      detail: next == null ? null : RdEventPage(key: ValueKey('rd-event-$next'), attendanceId: next),
      selectedId: next,
      emptyText: l10n.redesignSplitEventsEmpty,
      empty: RdPage(
        children: [
          if (all != null)
            RdInfoCard(text: l10n.redesignTodayNoUpcoming, icon: Icons.event_available_outlined)
          else if (async.hasError && !async.isLoading)
            RdInfoCard(
              text: l10n.redesignTodayLoadFailed,
              icon: Icons.cloud_off_outlined,
              action: RdOutlineButton(
                label: l10n.redesignCommonRetry,
                onPressed: () => ref.invalidate(realtimeAttendanceListProvider),
              ),
            )
          else
            RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
        ],
      ),
    );
  }
}
