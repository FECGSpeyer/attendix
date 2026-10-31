import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_beamer.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/organisation/organisation.dart';
import '../../../planning/presentation/widgets/plan_field_dialogs.dart';
import '../widgets/org_song_sync_section.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/widgets/ion_condense.dart';
import '../../../settings/presentation/widgets/settings_list.dart';
import '../widgets/org_link_dialogs.dart';
import '../../../../core/utils/error_message.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonTranslucentAppBar, IonContentTopInset;
import '../../../../shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';

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

  Future<void> _toggleBeamerFiles(BuildContext context, WidgetRef ref, bool enabled) async {
    final ok = await ref
        .read(planSettingsNotifierProvider.notifier)
        .updateOrgGemeindeApp({'beamer_files_enabled': enabled});
    if (!ok && context.mounted) ToastHelper.showError(context, context.l10n.svcSaveGemeindeAppFailed);
  }

  /// Ionic 4.17.10 `createGemeindeAppKey`: only the hash is stored, so the
  /// key is shown once. A new key cuts the old link.
  Future<void> _createGemeindeAppKey(BuildContext context, WidgetRef ref, Organisation org) async {
    final l10n = context.l10n;
    if (org.gemeindeAppKeyHash != null) {
      final ok = await showPlanConfirm(
        context,
        title: l10n.orgGaRenewKey,
        message: l10n.orgGaRenewMessage,
        confirmText: l10n.orgGaRenewButton,
        destructive: true,
      );
      if (!ok || !context.mounted) return;
    }
    final created = PlanBeamer.newGemeindeAppKey();
    final saved = await ref.read(planSettingsNotifierProvider.notifier).updateOrgGemeindeApp({
      'gemeinde_app_key_hash': created.hash,
      'gemeinde_app_key_hint': created.hint,
    });
    if (!context.mounted) return;
    if (!saved) {
      ToastHelper.showError(context, l10n.svcSaveGemeindeAppFailed);
      return;
    }
    await showAppDialog<void>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(ctx.l10n.orgGaKeyHeader),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(created.key, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(ctx.l10n.orgGaKeyMessage),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: created.key));
                if (ctx.mounted) ToastHelper.showSuccess(ctx, ctx.l10n.orgGaCopied);
              } catch (_) {
                // Clipboard not available (PWA without permission): key stays visible.
              }
            },
            child: Text(ctx.l10n.orgGaCopy),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.commonClose)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(effectiveRoleProvider);
    final isSuperAdmin = role == Role.admin;
    final orgAsync = ref.watch(currentOrganisationProvider);
    final tenant = ref.watch(currentTenantProvider);
    final linked = ref.watch(linkedTenantsProvider).valueOrNull ?? const [];
    final others = linked.where((t) => t.id != tenant?.id).toList();

    // UX_SETTINGS (WAVE 8): org-settings.page.html — condense title, inset
    // lists with list headers and start icons on the light page.
    return IonCondense(builder: (context, collapsed) => Scaffold(
      // IOS_R6: Ionic `ion-content fullscreen` under the translucent header
      extendBodyBehindAppBar: ionIsIos(context),
      // IOS_R6: `ion-header translucent` (blur once condensed)
      appBar: IonTranslucentAppBar(condensed: collapsed, child: AppBar(title: IonCondenseTitle(context.l10n.orgTitle, collapsed: collapsed))),
      body: orgAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (e, _) => Center(child: Text(context.l10n.planningFlutterErrorWith(friendlyErrorMessage(e)))),
        data: (org) {
          if (org == null) {
            return ListView(
              children: [
                const IonContentTopInset(),
                IonLargeTitle(context.l10n.orgTitle),
                if (ionIsIos(context)) const SizedBox(height: 16),
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
                      onTap: () => showOrganisationLinkDialog(context, ref),
                    ),
                ]),
              ],
            );
          }
          return ListView(
            padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: 24)),
            children: [
              const IonContentTopInset(),
              IonLargeTitle(context.l10n.orgTitle),
              if (ionIsIos(context)) const SizedBox(height: 16),
              _Section(title: context.l10n.orgTitle, children: [
                ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text(org.name),
                  subtitle: isSuperAdmin ? Text(context.l10n.orgTapRename) : null,
                  trailing: isSuperAdmin ? const _Chevron() : null,
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
                  trailing: const _Chevron(),
                  onTap: () => context.push('/settings/general/branding'),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(context.l10n.orgTemplatesTitle),
                  trailing: const _Chevron(),
                  onTap: () => context.push('/settings/org-settings/planning-templates'),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(context.l10n.orgOrgPlans),
                  trailing: const _Chevron(),
                  onTap: () => context.push('/settings/org-plans'),
                ),
              ]),
              // Ionic 4.17.10: Gemeinde App (FECG Speyer, FECG Schwegenheim only)
              if (isSuperAdmin && PlanBeamer.gemeindeAppLinked(org)) ...[
                _Section(title: context.l10n.orgGemeindeApp, children: [
                  SwitchListTile.adaptive(
                    key: const ValueKey('org-beamer-files-toggle'),
                    secondary: const Icon(Icons.tv_outlined),
                    title: Text(context.l10n.orgGaBeamerFiles),
                    subtitle: Text(context.l10n.orgGaBeamerFilesHint),
                    value: org.beamerFilesEnabled,
                    onChanged: (v) => _toggleBeamerFiles(context, ref, v),
                  ),
                  ListTile(
                    key: const ValueKey('org-gemeinde-app-key'),
                    leading: const Icon(Icons.key_outlined),
                    title: Text(org.gemeindeAppKeyHash != null
                        ? context.l10n.orgGaRenewKey
                        : context.l10n.orgGaCreateKey),
                    subtitle: Text(org.gemeindeAppKeyHash != null
                        ? context.l10n.orgGaKeyActive(org.gemeindeAppKeyHint ?? '')
                        : context.l10n.orgGaNoKey),
                    onTap: () => _createGemeindeAppKey(context, ref, org),
                  ),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 4, 32, 8),
                  child: Text(context.l10n.orgGaHint,
                      style: const TextStyle(fontSize: 13, color: AppColors.medium)),
                ),
              ],
              if (isSuperAdmin)
                _Section(title: context.l10n.orgPersons, children: [
                  // UX_SETTINGS: Ionic org-settings → Personen verknüpfen
                  ListTile(
                    leading: const Icon(Icons.merge_type),
                    title: Text(context.l10n.linkPersonsTitle),
                    subtitle: Text(context.l10n.orgLinkPersonsHint),
                    trailing: const _Chevron(),
                    onTap: () => context.push('/settings/general/link-persons'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.list_alt),
                    title: Text(context.l10n.orgPersonFields),
                    subtitle: Text(context.l10n.orgPersonFieldsHint),
                    trailing: const _Chevron(),
                    onTap: () => context.push('/settings/org-settings/person-fields'),
                  ),
                ]),
              // UX_SETTINGS: Ionic org-settings → Übergabe (admins/responsibles)
              if (role.isAdmin || role.isResponsible)
                _Section(title: context.l10n.orgHandover, children: [
                  ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: Text(context.l10n.handoverTitle),
                    trailing: const _Chevron(),
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
    ));
  }
}

/// Ionic detail chevron (iOS) / Material chevron.
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) =>
      ionIsIos(context) ? const IonDetailChevron() : const Icon(Icons.chevron_right);
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (ionIsIos(context)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SettingsListSection(title: title, children: children),
      );
    }
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
