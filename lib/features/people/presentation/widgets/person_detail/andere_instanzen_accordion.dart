import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../l10n/l10n.dart';

/// Provider for other tenants where this person has an account.
/// Note: Cross-tenant queries are intentional here (same pattern as handover
/// duplicate detection). Supabase RLS restricts access at the database level.
final otherTenantsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, appId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final currentTenant = ref.watch(currentTenantProvider);

  if (currentTenant == null) return [];

  // Get all tenants where this user has an entry
  final tenantUsersResponse = await supabase
      .from('tenantUsers')
      .select('tenantId, role, tenant:tenantId(id, longName, shortName)')
      .eq('userId', appId);

  final tenantUsers = (tenantUsersResponse as List)
      .where((tu) {
        final tenant = tu['tenant'] as Map<String, dynamic>?;
        final tenantId = tenant?['id'];
        return tenantId != null && tenantId != currentTenant.id;
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
      // Find the player by appId in the other tenant
      final playerResponse = await supabase
          .from('player')
          .select('id')
          .eq('appId', appId)
          .eq('tenantId', tenantId)
          .isFilter('left', null)
          .maybeSingle();

      if (playerResponse != null) {
        final playerId = playerResponse['id'] as int;

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

    String roleText;
    switch (role) {
      case 1:
        roleText = l10nWithoutContext.commonRolesAdmin;
        break;
      case 2:
        roleText = l10nWithoutContext.commonRolesMember;
        break;
      case 3:
        roleText = l10nWithoutContext.commonRolesViewer;
        break;
      case 4:
        roleText = l10nWithoutContext.commonRolesHelper;
        break;
      case 5:
        roleText = l10nWithoutContext.commonRolesResponsible;
        break;
      default:
        roleText = l10nWithoutContext.commonRolesMember;
    }

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
  });

  final String appId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherTenantsAsync = ref.watch(otherTenantsProvider(appId));

    return otherTenantsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (tenants) {
        if (tenants.isEmpty) return const SizedBox.shrink();

        return _AndereInstanzenCard(tenants: tenants);
      },
    );
  }
}

class _AndereInstanzenCard extends StatefulWidget {
  const _AndereInstanzenCard({required this.tenants});

  final List<Map<String, dynamic>> tenants;

  @override
  State<_AndereInstanzenCard> createState() => _AndereInstanzenCardState();
}

class _AndereInstanzenCardState extends State<_AndereInstanzenCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              context.l10n.personFlutterOtherInstancesCount(widget.tenants.length),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing:
                Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM,
                0,
                AppDimensions.paddingM,
                AppDimensions.paddingM,
              ),
              child: Column(
                children: widget.tenants
                    .map((tenant) => _buildTenantItem(tenant))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTenantItem(Map<String, dynamic> tenant) {
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
      badgeColor = AppColors.medium;
      badgeText = 'N/A';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tenantName, style: const TextStyle(fontSize: 15)),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    role,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
