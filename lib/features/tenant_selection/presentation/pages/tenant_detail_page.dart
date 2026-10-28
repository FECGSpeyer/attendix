import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Page showing tenant details and danger zone (delete)
class TenantDetailPage extends ConsumerWidget {
  const TenantDetailPage({super.key, required this.tenantId});

  final int tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(userTenantsProvider);

    return tenantsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: AppSpinner()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.tenantSelectFlutterDetailsTitle)),
        body: Center(child: Text(context.l10n.tenantSelectFlutterDetailsLoadFailed)),
      ),
      data: (tenants) {
        final tenant = tenants.where((t) => t.id == tenantId).firstOrNull;
        if (tenant == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.tenantSelectFlutterDetailsTitle)),
            body: Center(child: Text(context.l10n.tenantSelectFlutterNotFound)),
          );
        }

        final role = Role.fromValue(tenant.role ?? 99);

        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.tenantSelectFlutterDetailsTitle),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            children: [
              _TenantHeader(tenant: tenant),
              const SizedBox(height: AppDimensions.paddingL),
              _TenantInfoSection(tenant: tenant, tenantId: tenantId, role: role),
              if (role.isAdmin) ...[
                const SizedBox(height: AppDimensions.paddingXL),
                _DangerZone(tenant: tenant),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TenantHeader extends StatelessWidget {
  const _TenantHeader({required this.tenant});

  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    final displayName = tenant.name;
    final initials = StringUtils.getTenantInitials(tenant.shortName, tenant.longName);

    final typeLabel = switch (tenant.type) {
      'choir' => context.l10n.registerTypeChoir,
      'orchestra' => context.l10n.registerTypeOrchestra,
      _ => context.l10n.commonGroupLabelGroup,
    };

    return Column(
      children: [
        const SizedBox(height: AppDimensions.paddingM),
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.primaryLight,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.paddingM),
        Text(
          displayName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        if (tenant.description != null) ...[
          const SizedBox(height: AppDimensions.paddingXS),
          Text(
            tenant.description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.medium,
                ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppDimensions.paddingXS),
        Text(
          typeLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _TenantInfoSection extends ConsumerWidget {
  const _TenantInfoSection({
    required this.tenant,
    required this.tenantId,
    required this.role,
  });

  final Tenant tenant;
  final int tenantId;
  final Role role;

  String _roleName(Role role, AppLocalizations l10n) {
    return switch (role) {
      Role.admin => l10n.rolesAdministrator,
      Role.responsible => l10n.rolesResponsible,
      Role.helper => l10n.rolesHelper,
      Role.viewer => l10n.rolesViewer,
      Role.player => l10n.rolesMember,
      Role.voiceLeader => l10n.rolesVoiceLeader,
      Role.voiceLeaderHelper => l10n.rolesVoiceLeaderHelper,
      Role.parent => l10n.rolesParent,
      Role.applicant => l10n.rolesApplicant,
      Role.none => l10n.tenantSelectFlutterNoRole,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberCountAsync = ref.watch(tenantMemberCountProvider(tenantId));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingXS,
              ),
              child: Text(
                context.l10n.tenantSelectFlutterInfo,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.medium,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            _InfoRow(
              icon: Icons.people,
              label: context.l10n.tabsMembers,
              value: memberCountAsync.when(
                data: (count) => '$count',
                loading: () => '...',
                error: (_, __) => '-',
              ),
            ),
            if (tenant.createdAt != null)
              _InfoRow(
                icon: Icons.calendar_today,
                label: context.l10n.tenantSelectFlutterCreatedAt,
                value: DateFormat(dateFmt()).format(tenant.createdAt!),
              ),
            if (tenant.region != null && tenant.region!.isNotEmpty)
              _InfoRow(
                icon: Icons.location_on,
                label: context.l10n.tenantSelectFlutterRegion,
                value: tenant.region!,
              ),
            _InfoRow(
              icon: Icons.badge,
              label: context.l10n.tenantSelectFlutterYourRole,
              value: _roleName(role, context.l10n),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: AppColors.medium),
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _DangerZone extends ConsumerWidget {
  const _DangerZone({required this.tenant});

  final Tenant tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingS,
            vertical: AppDimensions.paddingXS,
          ),
          child: Text(
            context.l10n.tenantSelectFlutterDangerZone,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3)),
          ),
          child: ListTile(
            leading: Icon(Icons.delete_forever, color: AppColors.danger),
            title: Text(
              context.l10n.tenantSelectFlutterDeleteTenant,
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              context.l10n.tenantSelectFlutterDeleteTenantHint,
              style: TextStyle(fontSize: 13, color: AppColors.medium),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.medium),
            onTap: () => _showDeleteTenantDialog(context, ref, tenant),
          ),
        ),
      ],
    );
  }
}

/// Show safety dialog for deleting a tenant instance
Future<void> _showDeleteTenantDialog(
  BuildContext context,
  WidgetRef ref,
  Tenant tenant,
) async {
  final tenantName = tenant.name;
  final controller = TextEditingController();

  try {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final matches = controller.text.trim() == tenantName;
            return AppAlertDialog(
              title: Text(context.l10n.tenantSelectFlutterDeleteTenant),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${context.l10n.peopleCannotUndoExcl} ${context.l10n.tenantSelectFlutterDeleteAllData}',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  const SizedBox(height: 16),
                  Text(context.l10n.tenantSelectFlutterEnterNameToConfirm),
                  const SizedBox(height: 8),
                  Text(
                    tenantName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: context.l10n.orgNamePh,
                    ),
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.l10n.commonCancel),
                ),
                ElevatedButton(
                  onPressed: matches ? () => Navigator.of(context).pop(true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.danger.withValues(alpha: 0.5),
                    disabledForegroundColor: Colors.white,
                  ),
                  child: Text(context.l10n.registerDeleteConfirm),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final id = tenant.id;
      if (id == null) return;
      await deleteTenant(ref, id);
      if (context.mounted) {
        ToastHelper.showSuccess(context, context.l10n.tenantSelectFlutterDeleted);
        context.go('/tenants');
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(context, context.l10n.svcDeleteFailed);
      }
    }
  } finally {
    controller.dispose();
  }
}
