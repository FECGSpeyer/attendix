import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/organisation/organisation.dart';
import '../../../planning/presentation/widgets/plan_field_dialogs.dart';
import '../widgets/org_song_sync_section.dart'; // SETTINGS2
import '../../../../l10n/l10n.dart';
import '../widgets/org_link_dialogs.dart'; // UX_SETTINGS
import '../../../../core/utils/error_message.dart';

/// Organisation settings (Ionic `OrgSettingsPage`, route `/settings/org-settings`).
class OrgSettingsPage extends ConsumerWidget {
  const OrgSettingsPage({super.key});

  Future<void> _rename(BuildContext context, WidgetRef ref, Organisation org) async {
    final name = await showPlanTextPrompt(
      context,
      title: context.l10n.orgRename,
      initialValue: org.name,
      hint: context.l10n.orgNamePh,
    );
    if (name == null) return;
    if (name.trim().isEmpty) {
      if (context.mounted) ToastHelper.showWarning(context, context.l10n.orgValidName);
      return;
    }
    final ok = await ref.read(planSettingsNotifierProvider.notifier).updateOrgName(name.trim());
    if (!context.mounted) return;
    ok ? ToastHelper.showSuccess(context, context.l10n.orgRenamed) : ToastHelper.showError(context, context.l10n.plansSaveFailed);
  }

  Future<void> _unlink(BuildContext context, WidgetRef ref, Organisation org) async {
    final ok = await showPlanConfirm(
      context,
      title: context.l10n.orgUnlink,
      message: context.l10n.orgUnlinkMessage(org.name),
      confirmText: context.l10n.orgUnlinkButton,
      destructive: true,
    );
    if (!ok || org.id == null) return;
    final success = await ref.read(organisationNotifierProvider.notifier).unlinkCurrentTenant(org.id!);
    if (!context.mounted) return;
    success
        ? ToastHelper.showSuccess(context, context.l10n.orgUnlinked)
        : ToastHelper.showError(context, context.l10n.orgFlutterUnlinkFailed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(effectiveRoleProvider);
    final isSuperAdmin = role == Role.admin;
    final orgAsync = ref.watch(currentOrganisationProvider);
    final tenant = ref.watch(currentTenantProvider);
    final linked = ref.watch(linkedTenantsProvider).valueOrNull ?? const [];
    final others = linked.where((t) => t.id != tenant?.id).toList();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.orgTitle)),
      body: orgAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.l10n.planningFlutterErrorWith(friendlyErrorMessage(e)))),
        data: (org) {
          if (org == null) {
            return ListView(
              children: [
                _Section(children: [
                  ListTile(
                    title: Text(context.l10n.orgNoneLinked),
                    subtitle: Text(isSuperAdmin
                        ? context.l10n.orgNoneIntro
                        : context.l10n.orgNoneAdminOnly),
                  ),
                  if (isSuperAdmin)
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                      title: Text(context.l10n.orgCreateOrLink,
                          style: const TextStyle(color: AppColors.primary)),
                      onTap: () => showOrganisationLinkDialog(context, ref), // UX_SETTINGS
                    ),
                ]),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _Section(title: context.l10n.orgTitle, children: [
                ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text(org.name),
                  subtitle: isSuperAdmin ? Text(context.l10n.orgTapRename) : null,
                  trailing: isSuperAdmin ? const Icon(Icons.chevron_right) : null,
                  onTap: isSuperAdmin ? () => _rename(context, ref, org) : null,
                ),
                if (isSuperAdmin)
                  ListTile(
                    leading: const Icon(Icons.link_off, color: AppColors.danger),
                    title: Text(context.l10n.orgUnlinkTenant, style: const TextStyle(color: AppColors.danger)),
                    onTap: () => _unlink(context, ref, org),
                  ),
              ]),
              _Section(title: context.l10n.orgAppearancePlans, children: [
                // UX_SETTINGS: Ionic org-settings → Branding
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(context.l10n.generalSettingsBranding),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/general/branding'),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(context.l10n.orgTemplatesTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/org-settings/planning-templates'),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(context.l10n.orgOrgPlans),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/org-plans'),
                ),
              ]),
              if (isSuperAdmin)
                _Section(title: context.l10n.orgPersons, children: [
                  // UX_SETTINGS: Ionic org-settings → Personen verknüpfen
                  ListTile(
                    leading: const Icon(Icons.merge_type),
                    title: Text(context.l10n.linkPersonsTitle),
                    subtitle: Text(context.l10n.orgLinkPersonsHint),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/general/link-persons'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.list_alt),
                    title: Text(context.l10n.orgPersonFields),
                    subtitle: Text(context.l10n.orgPersonFieldsHint),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/org-settings/person-fields'),
                  ),
                ]),
              // UX_SETTINGS: Ionic org-settings → Übergabe (admins/responsibles)
              if (role.isAdmin || role.isResponsible)
                _Section(title: context.l10n.orgHandover, children: [
                  ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: Text(context.l10n.handoverTitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/handover'),
                  ),
                ]),
              // SETTINGS2: Werk-Synchronisierung (Ionic: super admin + linked tenants)
              if (isSuperAdmin && others.isNotEmpty)
                OrgSongSyncSection(linkedTenants: others),
              if (others.isNotEmpty)
                _Section(title: context.l10n.orgTenants, children: [
                  ListTile(
                    leading: const Icon(Icons.layers_outlined),
                    title: Text(tenant?.shortName ?? ''),
                    subtitle: Text(context.l10n.orgThisTenant),
                  ),
                  for (final t in others)
                    ListTile(
                      leading: const Icon(Icons.layers_outlined, color: AppColors.medium),
                      title: Text(t.shortName),
                      subtitle: Text(t.longName),
                    ),
                ]),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(title!.toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.medium)),
          ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: children),
        ),
      ],
    );
  }
}
