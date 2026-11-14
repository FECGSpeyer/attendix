import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/message_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/go_replace.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/services/error_reporter.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Resolver for appointment deep links of reminder mails / Telegram messages
/// (`/open-attendance?id=42&tenantId=7`, Ionic `OpenAttendancePage`).
///
/// Switches to the link's tenant if needed, then routes like a push:
/// Dirigenten/Helfer open the Termin, everyone else their landing page.
/// Without `id` only the tenant is switched (Teams channel tab).
class OpenAttendancePage extends ConsumerStatefulWidget {
  const OpenAttendancePage({super.key, this.attendanceId, this.tenantId});

  final String? attendanceId;
  final String? tenantId;

  @override
  ConsumerState<OpenAttendancePage> createState() => _OpenAttendancePageState();
}

class _OpenAttendancePageState extends ConsumerState<OpenAttendancePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    // F-RAHMEN-17: a link opened in the running app puts this page on top
    // of the tab shell; going back into the shell before it is shown left
    // the Termin blank (old and new shell shared their navigator key). Wait
    // first and navigate with the router captured now.
    final route = ModalRoute.of(context);
    final router = GoRouter.of(context);
    if (!await untilReadyToLeave(route) || !mounted) return;
    final idParam = widget.attendanceId;
    final attendanceId = idParam == null ? null : int.tryParse(idParam);
    if (idParam != null && attendanceId == null) {
      router.go('/login');
      return;
    }

    var tenantId = int.tryParse(widget.tenantId ?? '');
    try {
      final tenants = await ref.read(userTenantsProvider.future);
      // LINK_TERMIN: a link without `tenantId` (duty reminders
      // `/tabs/attendance/:id`) opens the Termin in its own group, not in
      // whichever group happens to be open.
      if (tenantId == null && attendanceId != null) {
        // tenant-read-after-await: the lookup searches the user's groups,
        // not the current one.
        tenantId = await ref
            .read(attendanceRepositoryWithTenantProvider)
            .findTenantIdOfAttendance(
              attendanceId,
              [for (final t in tenants) if (t.id != null) t.id!],
            );
        if (!mounted) return;
      }
      if (tenantId != null && tenantId != ref.read(currentTenantIdProvider)) {
        final tenant = tenants.where((t) => t.id == tenantId).firstOrNull;
        if (tenant != null && mounted) {
          await ref.read(currentTenantProvider.notifier).setTenant(tenant);
        }
      }
    } catch (_) {
      // Fall back to the current tenant.
    }
    if (!mounted) return;

    Role role = Role.none;
    try {
      final tenantUser = await ref.read(currentTenantUserProvider.future);
      role = tenantUser?.roleEnum ?? Role.none;
    } catch (_) {}
    if (!mounted) return;

    if (ref.read(currentTenantProvider) == null) {
      router.go('/tenants');
      return;
    }
    if (attendanceId != null) {
      // INTEGRATION: opening a Termin via a mail/Telegram link marks its
      // notification-center entries read (Ionic, best-effort).
      try {
        // tenant-read-after-await: the link deliberately switched to its
        // tenant above; the notifications must be marked in that tenant.
        final repo = ref.read(userNotificationRepositoryWithTenantProvider);
        if (repo.hasTenantId) await repo.markReadByAttendance(attendanceId);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'open_attendance_page');
      }
      if (!mounted) return;
      // LOGIC_SELF: Ionic navigateToAttendance — only ADMIN, RESPONSIBLE,
      // HELPER and VOICE_LEADER_HELPER open the Termin detail (not VIEWER).
      if (role.canAddAttendance) {
        router.go(RedesignRoutes.betaTarget('/attendance/$attendanceId'));
        return;
      }
      // Parents land on their portal, everybody else on "Meine Termine";
      // both open this Termin's action sheet (Ionic pendingAttendanceId).
      ref.read(pendingAttendanceIdProvider.notifier).state = attendanceId;
      router.go(role.isParent ? '/parents' : RedesignRoutes.betaTarget('/signout'));
      return;
    }
    router.go(role.defaultRoute);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: AppSpinner()));
  }
}
