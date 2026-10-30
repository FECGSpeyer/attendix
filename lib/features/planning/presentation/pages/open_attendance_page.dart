import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/message_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
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
    final idParam = widget.attendanceId;
    final attendanceId = idParam == null ? null : int.tryParse(idParam);
    if (idParam != null && attendanceId == null) {
      if (mounted) context.go('/login');
      return;
    }

    final tenantId = int.tryParse(widget.tenantId ?? '');
    try {
      if (tenantId != null && tenantId != ref.read(currentTenantIdProvider)) {
        final tenants = await ref.read(userTenantsProvider.future);
        final tenant = tenants.where((t) => t.id == tenantId).firstOrNull;
        if (tenant != null) {
          await ref.read(currentTenantProvider.notifier).setTenant(tenant);
        }
      }
    } catch (_) {
      // Fall back to the current tenant.
    }

    Role role = Role.none;
    try {
      final tenantUser = await ref.read(currentTenantUserProvider.future);
      role = tenantUser?.roleEnum ?? Role.none;
    } catch (_) {}
    if (!mounted) return;

    if (ref.read(currentTenantProvider) == null) {
      context.go('/tenants');
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
        context.go(RedesignRoutes.betaTarget('/attendance/$attendanceId'));
        return;
      }
      // Parents land on their portal, everybody else on "Meine Termine";
      // both open this Termin's action sheet (Ionic pendingAttendanceId).
      ref.read(pendingAttendanceIdProvider.notifier).state = attendanceId;
      context.go(role.isParent ? '/parents' : RedesignRoutes.betaTarget('/signout'));
      return;
    }
    context.go(role.defaultRoute);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: AppSpinner()));
  }
}
