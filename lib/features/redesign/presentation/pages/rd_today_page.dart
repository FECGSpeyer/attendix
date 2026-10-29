import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/message_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../messages/presentation/widgets/notification_bell.dart';
import '../../../parents/data/providers/parents_providers.dart';
import '../widgets/rd_group_switch.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_applicant_today.dart';
import '../widgets/today/rd_leader_today.dart';
import '../widgets/today/rd_parent_today.dart';
import '../widgets/today/rd_player_today.dart';

/// REDESIGN: "Heute" (canvas D1, S1, R1–R4), the start page of the new
/// design for every role.
///
/// * Dirigent, Verantwortlich, Beobachter: next Termin with the answers,
///   hints that need attention, this week.
/// * Helfer: next Termin with "Anwesenheit erfassen", plus the own Zusage.
/// * Spieler, Stimmführer: own Zusage in one tap, Abmelden with reason in
///   two, the next Termine.
/// * Eltern: next Termine of the children.
/// * Bewerber: waiting page instead of tabs.
class RdTodayPage extends ConsumerWidget {
  const RdTodayPage({super.key});

  Future<void> _refresh(WidgetRef ref, Role role) async {
    ref.invalidate(unreadNotificationCountProvider);
    if (role.canSeeAttendanceTab) {
      ref.read(attendanceRefetchCounter.notifier).state++;
      ref.invalidate(realtimeAttendanceListProvider);
    }
    if (role.isAdmin || role.isResponsible) {
      ref.invalidate(pendingPlayersProvider);
      ref.invalidate(criticalPlayersProvider);
      ref.invalidate(dashboardPersonsProvider);
    }
    if (role.isParent) {
      ref.invalidate(childrenAttendancesProvider);
      return;
    }
    if (!role.isConductor) {
      ref.invalidate(currentSelfServicePlayerProvider);
      ref.invalidate(signoutDataProvider);
      await ref.read(signoutDataProvider.future).catchError((_) => const SignoutData());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(effectiveRoleProvider);
    final isApplicant = role.isApplicant || ref.watch(isApplicantProvider);
    if (isApplicant) return const RdApplicantToday();

    final p = context.rd;
    final l10n = context.l10n;
    final firstName = role.isConductor
        ? null
        : ref.watch(currentSelfServicePlayerProvider).valueOrNull?.firstName;
    final dateLine = DateFormat.MMMMEEEEd(currentIntlLocale()).format(DateTime.now());

    return RdPage(
      onRefresh: () => _refresh(ref, role),
      children: [
        Row(
          children: [
            const Flexible(child: Align(alignment: Alignment.centerLeft, child: RdGroupChip())),
            const SizedBox(width: 12),
            const _RdBell(),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          firstName != null && firstName.isNotEmpty
              ? l10n.redesignTodayGreeting(firstName)
              : dateLine,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: p.text2),
        ),
        const SizedBox(height: 2),
        Semantics(
          header: true,
          child: Text(l10n.redesignTabToday, style: RdType.largeTitle(p)),
        ),
        const SizedBox(height: 18),
        if (role.isParent)
          const RdParentToday()
        else if (role.canSeeAttendanceTab)
          RdLeaderToday(role: role)
        else
          RdPlayerToday(role: role),
      ],
    );
  }
}

/// Bell with a dot for unread notifications.
class _RdBell extends ConsumerWidget {
  const _RdBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(userNotificationsRealtimeProvider);
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final l10n = context.l10n;
    return RdCircleButton(
      icon: Icons.notifications_outlined,
      label: unread > 0
          ? l10n.redesignTodayNotificationsUnread(unread)
          : l10n.redesignTodayNotifications,
      dot: unread > 0,
      onPressed: () => NotificationBell.open(context, ref),
    );
  }
}
