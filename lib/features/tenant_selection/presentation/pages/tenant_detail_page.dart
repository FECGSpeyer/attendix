import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/components/components.dart';

/// Page showing tenant details and danger zone (delete)
class TenantDetailPage extends ConsumerWidget {
  const TenantDetailPage({super.key, required this.tenantId});

  final int tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(userTenantsProvider);
    final p = context.rd;
    final l10n = context.l10n;
    final back = RdBackLink(
      label: l10n.redesignMeGroups,
      onTap: () => context.canPop() ? context.pop() : context.go('/tenants'),
    );
    final list = tenantsAsync.valueOrNull;
    if (list == null) {
      return RdPage(
        onRefresh: () async {
          try {
            final _ = await ref.refresh(userTenantsProvider.future);
          } catch (_) {}
        },
        children: [
          back,
          const SizedBox(height: 24),
          if (tenantsAsync.hasError)
            Text(l10n.redesignGroupsLoadFailed, style: RdType.body(p))
          else
            const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    final tenant = list.where((t) => t.id == tenantId).firstOrNull;
    if (tenant == null) {
      return RdPage(
        children: [
          back,
          const SizedBox(height: 24),
          Text(l10n.redesignTenantsNotFound, style: RdType.body(p)),
        ],
      );
    }
    final role = Role.fromValue(tenant.role ?? 99);
    final kind = switch (tenant.type) {
      'choir' => l10n.registerTypeChoir,
      'orchestra' => l10n.registerTypeOrchestra,
      _ => l10n.redesignTenantsTypeGeneral,
    };
    final members = ref.watch(tenantMemberCountProvider(tenantId));
    final name = tenant.longName.isNotEmpty ? tenant.longName : tenant.shortName;
    return RdPage(
      children: [
        back,
        const SizedBox(height: 8),
        Row(
          children: [
            RdInitials(
              rdInitialsOf(tenant.shortName.isNotEmpty ? tenant.shortName : name),
              size: 64,
              square: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(name, style: RdType.cardTitle(p))),
                  if ((tenant.description ?? '').isNotEmpty)
                    Text(tenant.description!, style: RdType.meta(p, size: 14)),
                  const SizedBox(height: 6),
                  RdPill(kind),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        RdGroupedList(
          children: [
            RdListRow(title: l10n.redesignTenantsRole, value: _roleName(role, l10n), showChevron: false),
            RdListRow(
              title: l10n.redesignTenantsMembers,
              value: members.when(data: (c) => '$c', loading: () => '…', error: (_, __) => '–'),
              showChevron: false,
            ),
            if ((tenant.region ?? '').isNotEmpty)
              RdListRow(title: l10n.redesignTenantsRegion, value: tenant.region!, showChevron: false),
            if (tenant.createdAt != null)
              RdListRow(
                title: l10n.redesignTenantsCreated,
                value: DateFormat(dateFmt()).format(tenant.createdAt!),
                showChevron: false,
              ),
          ],
        ),
        if (role.isAdmin) ...[
          const SizedBox(height: 28),
          RdGroupedList(
            children: [
              RdListRow(
                leading: RdRowIcon(Icons.delete_outline, color: p.absent, background: p.absentSoft),
                title: l10n.redesignTenantsDelete,
                titleColor: p.absent,
                showChevron: false,
                onTap: () => _showDeleteTenantDialog(context, ref, tenant),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _roleName(Role role, AppLocalizations l10n) => switch (role) {
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
              title: Text(context.l10n.redesignTenantsDeleteTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.redesignTenantsDeleteMessage(tenantName)),
                  const SizedBox(height: 8),
                  Text(
                    tenantName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: context.l10n.redesignTenantsDeleteNamePh,
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
        ToastHelper.showSuccess(
          context,
          context.l10n.redesignTenantsDeleteDone,
        );
        context.go('/tenants');
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(
          context,
          context.l10n.redesignTenantsDeleteFailed,
        );
      }
    }
  } finally {
    controller.dispose();
  }
}
