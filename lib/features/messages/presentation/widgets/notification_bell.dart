import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/layout/sheet_drag.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/message_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/ionic_route_mapper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/models/user_notification/user_notification.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../bell_logic.dart';

part 'notification_center_sheet.dart';

/// Notification bell for page app bars (port of Ionic `NotificationBellComponent`).
///
/// Shows the unread count of the current instance and opens the notification
/// center (current instance / all instances) as a bottom sheet.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  /// REDESIGN: opens the notification centre from another button (the
  /// bell on "Heute" of the new design).
  static Future<void> open(BuildContext context, WidgetRef ref) =>
      const NotificationBell()._open(context, ref);

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    var allTenants = false;
    List<UserNotification> list;
    try {
      list = await ref.read(userNotificationsProvider(false).future);
      if (list.isEmpty) {
        // Fall back to the all-instances view so notifications from other
        // instances are still visible.
        allTenants = true;
        list = await ref.read(userNotificationsProvider(true).future);
      }
    } catch (_) {
      list = const [];
    }
    ref.invalidate(unreadNotificationCountProvider);
    if (!context.mounted) return;
    final target = await showModalBottomSheet<_BellTarget>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.rd.bg,
      builder:
          (_) => AppDraggableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 1.0,
            builder:
                (context, scrollController) => _NotificationCenter(
                  initialAllTenants: allTenants,
                  scrollController: scrollController,
                ),
          ),
    );
    if (target != null && context.mounted) {
      await _navigate(context, ref, target.notification);
    }
  }

  /// Opens the target of a tapped notification (switches instance if needed).
  Future<void> _navigate(BuildContext context, WidgetRef ref, UserNotification n) async {
    final router = GoRouter.of(context);
    final isMessage = n.type == 'message' && n.messageId != null;
    // Ionic onTap: entries without a target (criticals / birthdays) only
    // close the sheet; route and Termin entries switch the instance only
    // when data.tenantId is set.
    if (!isMessage && n.route == null && n.attendanceId == null) return;
    final explicitTenant = int.tryParse(n.data['tenantId']?.toString() ?? '');
    // A Termin id only exists in its own instance: in "Alle Instanzen" an
    // entry of another instance without data.tenantId still has to switch to
    // the row's instance, otherwise the Termin is not found.
    final int? targetTenant = isMessage || (n.route == null && n.attendanceId != null)
        ? n.targetTenantId
        : explicitTenant;
    if (targetTenant != null && targetTenant != ref.read(currentTenantIdProvider)) {
      final tenants = await ref.read(userTenantsProvider.future);
      Tenant? tenant;
      for (final t in tenants) {
        if (t.id == targetTenant) tenant = t;
      }
      if (tenant == null) return;
      await ref.read(currentTenantProvider.notifier).setTenant(tenant);
    }

    final messageId = n.messageId;
    if (n.type == 'message' && messageId != null) {
      router.push('/messages/$messageId');
      return;
    }

    final route = n.route;
    if (route != null) {
      // Ionic routes are prefixed with /tabs; only navigate when the route
      // exists in this app.
      // In the new design (Beta) Termine open on their new pages.
      final path = RedesignRoutes.betaTarget(mapIonicRoute(route));
      try {
        if (router.configuration.findMatch(Uri.parse(path)).isNotEmpty) {
          router.push(path);
        }
      } catch (_) {
        // Unknown route: nothing to open.
      }
      return;
    }

    final attendanceId = n.attendanceId;
    if (attendanceId == null) return; // criticals / birthday: nothing to open

    final tenantUser = await ref.read(currentTenantUserProvider.future);
    final role = tenantUser?.roleEnum;
    if (role != null &&
        (role.isAdmin || role.isResponsible || role.isHelper || role.isVoiceLeaderHelper)) {
      router.push(RedesignRoutes.betaTarget('/attendance/$attendanceId'));
    } else if (role != null && role.isParent) {
      // LOGIC_SELF: the parents portal opens the Termin's action sheet
      // (Ionic navigateToAttendance sets pendingAttendanceId for PARENT too).
      ref.read(pendingAttendanceIdProvider.notifier).state = attendanceId;
      router.go('/parents');
    } else {
      // INTEGRATION: Ionic navigateToAttendance – "Meine Termine" opens the
      // Termin's action sheet via the pending attendance id.
      ref.read(pendingAttendanceIdProvider.notifier).state = attendanceId;
      router.go(RedesignRoutes.betaTarget('/signout'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(userNotificationsRealtimeProvider);
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    return IconButton(
      tooltip: context.l10n.bellTitle,
      onPressed: () => _open(context, ref),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.danger,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: Icon(AppIcons.notificationsOutlined),
      ),
    );
  }
}
