import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/cross_tenant_person_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/services/cross_tenant_service.dart';
import '../../../../../data/repositories/user_registration_repository.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/l10n.dart';
import '../ion/ion_widgets.dart';

/// Provider for other tenants where this person has an account.
/// Note: Cross-tenant queries are intentional here (same pattern as handover
/// duplicate detection). Supabase RLS restricts access at the database level.
final otherTenantsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, appId) async {
  ref.watch(currentAuthUserIdProvider); // SOL_FIX15: reload per account
  final supabase = ref.watch(supabaseClientProvider);
  final currentTenant = ref.watch(currentTenantProvider);

  if (currentTenant == null) return [];

  // Ionic getTenantsFromUser: only tenants linked to the current one via an
  // organisation, and not those where the account is only "Beobachter".
  final linkedIds = (await ref.watch(linkedTenantIdsProvider.future)).toSet();

  // Get all tenants where this user has an entry
  final tenantUsersResponse = await supabase
      .from('tenantUsers')
      .select('tenantId, role, tenant:tenantId(id, longName, shortName)')
      .eq('userId', appId);

  final tenantUsers = (tenantUsersResponse as List)
      .where((tu) {
        final tenant = tu['tenant'] as Map<String, dynamic>?;
        final tenantId = tenant?['id'];
        return tenantId != null &&
            tenantId != currentTenant.id &&
            linkedIds.contains(tenantId) &&
            tu['role'] != Role.viewer.value;
      })
      .toList();

  final results = <Map<String, dynamic>>[];

  for (final tu in tenantUsers) {
    final tenant = tu['tenant'] as Map<String, dynamic>?;
    if (tenant == null) continue;

    final tenantId = tenant['id'] as int;
    final tenantName = tenant['longName']?.toString() ??
        tenant['shortName']?.toString() ??
        l10nWithoutContext.commonUnknown;
    final role = tu['role'] as int? ?? 99;

    // Find the player record in that tenant
    int? percentage;
    try {
      // Ionic getPersonIdFromTenant: not pending, prefer the active row.
      final playerRows = await supabase
          .from('player')
          .select('id, left, pending')
          .eq('appId', appId)
          .eq('tenantId', tenantId)
          .eq('pending', false);
      final playerId = CrossTenantService.pickPersonIdForTenant(
          (playerRows as List).cast<Map<String, dynamic>>());

      if (playerId != null) {

        // Get attendance stats
        final now = DateTime.now().toIso8601String().substring(0, 10);
        final attendanceResponse = await supabase
            .from('person_attendances')
            .select('status, attendance:attendance_id!inner(date, tenantId)')
            .eq('person_id', playerId)
            .eq('attendance.tenantId', tenantId);

        final attendances = (attendanceResponse as List).where((a) {
          final attendance = a['attendance'] as Map<String, dynamic>?;
          final date = attendance?['date']?.toString();
          return date != null && date.compareTo(now) <= 0;
        }).toList();

        final total = attendances.length;
        final attended = attendances.where((a) {
          final status = a['status'];
          if (status is int) {
            return AttendanceStatus.fromValue(status).countsAsPresent;
          }
          return false;
        }).length;

        percentage = total > 0 ? (attended / total * 100).round() : null;
      }
    } catch (_) {
      // Ignore errors for individual tenants
    }

    // Ionic Utils.getRoleText
    final roleText = UserRegistrationRepository.roleText(Role.fromValue(role));

    results.add({
      'tenantName': tenantName,
      'role': roleText,
      'percentage': percentage,
    });
  }

  return results;
});

/// Accordion showing person's membership in other tenants.
class AndereInstanzenAccordion extends ConsumerWidget {
  const AndereInstanzenAccordion({
    super.key,
    required this.appId,
    this.isExpanded,
    this.onToggle,
  });

  final String appId;

  /// UX_PEOPLE: expansion controlled by the page (Ionic accordion group with
  /// Allgemein/Account/Zusatzfelder: only one open at a time).
  final bool? isExpanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherTenantsAsync = ref.watch(otherTenantsProvider(appId));

    return otherTenantsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (tenants) {
        if (tenants.isEmpty) return const SizedBox.shrink();

        return _AndereInstanzenCard(
          tenants: tenants,
          isExpanded: isExpanded,
          onToggle: onToggle,
        );
      },
    );
  }
}

class _AndereInstanzenCard extends StatefulWidget {
  const _AndereInstanzenCard({
    required this.tenants,
    this.isExpanded,
    this.onToggle,
  });

  final List<Map<String, dynamic>> tenants;
  final bool? isExpanded;
  final VoidCallback? onToggle;

  @override
  State<_AndereInstanzenCard> createState() => _AndereInstanzenCardState();
}

class _AndereInstanzenCardState extends State<_AndereInstanzenCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return IonAccordion(
      // Ionic: 'person.otherInstances'
      title: context.l10n.personOtherInstances,
      expanded: widget.isExpanded ?? _isExpanded,
      onToggle: widget.onToggle ?? () => setState(() => _isExpanded = !_isExpanded),
      child: Padding(
              padding: EdgeInsets.zero,
              child: Column(
                children: widget.tenants
                    .map((tenant) => _buildTenantItem(context, tenant))
                    .toList(),
              ),
            ),
    );
  }

  Widget _buildTenantItem(BuildContext context, Map<String, dynamic> tenant) {
    final tenantName = tenant['tenantName'] as String;
    final role = tenant['role'] as String;
    final percentage = tenant['percentage'] as int?;

    Color badgeColor;
    String badgeText;
    if (percentage != null) {
      badgeColor = percentage >= 75
          ? AppColors.success
          : percentage >= 50
              ? AppColors.warning
              : AppColors.danger;
      badgeText = '$percentage%';
    } else {
      // Ionic: translate('person.notAvailable') in warning color.
      badgeColor = AppColors.warning;
      badgeText = context.l10n.personNotAvailable;
    }

    // Ionic: ion-item lines="none" with h2 name, p role, badge
    return IonItem(
      lines: false,
      end: [IonBadge(text: badgeText, color: badgeColor)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tenantName, style: IonText.h2(context)),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(role, style: IonText.p(context)),
          ),
        ],
      ),
    );
  }
}
