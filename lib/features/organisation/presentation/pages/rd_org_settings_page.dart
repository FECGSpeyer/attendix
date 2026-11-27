import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/plan_beamer.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/organisation/organisation.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/song_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../widgets/org_link_dialogs.dart';
import '../widgets/rd_org_info_sheet.dart' show showRdOrgInfoSheet;
import '../../../planning/presentation/widgets/plan_field_dialogs.dart' show showPlanConfirm;
import '../../../settings/data/rd_manage_logic.dart' show RdManageArea;
import '../../../today/presentation/widgets/rd_today_common.dart' show RdInfoCard;
import '../../../settings/presentation/widgets/manage/rd_settings_sheets.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../../shared/widgets/redesign/rd_split_view.dart' show RdManageBackLink;

/// REDESIGN: Verwaltung › Gruppe › Organisation (canvas "Beta: Gruppe und
/// Daten", board "G2 Organisation"). Same functions and role checks as the
/// old page `/settings/org-settings`, as page type "Einstellungen mit
/// Unterseiten": name in a sheet, sub pages as rows, "Von Organisation
/// trennen" in red at the bottom. "Instanz" is called "Gruppe" here.
class RdOrgSettingsPage extends ConsumerStatefulWidget {
  const RdOrgSettingsPage({super.key});

  @override
  ConsumerState<RdOrgSettingsPage> createState() => _RdOrgSettingsPageState();
}

class _RdOrgSettingsPageState extends ConsumerState<RdOrgSettingsPage> {
  bool _busy = false;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.manageArea(RdManageArea.group.key));
    }
  }

  /// Whether [tenantId] (read when an action started) is still the current
  /// group. An action that started in another group writes nothing.
  bool _stillIn(int? tenantId) => mounted && tenantId != null && ref.read(currentTenantIdProvider) == tenantId;

  Future<void> _rename(Organisation org) async {
    final l10n = context.l10n;
    final tenantId = ref.read(currentTenantIdProvider);
    final name = await showRdTextSheet(
      context,
      title: l10n.orgRename,
      initial: org.name,
      hint: l10n.orgNamePh,
      required: true,
      capitalization: TextCapitalization.words,
    );
    if (name == null || name.trim().isEmpty || !_stillIn(tenantId)) return;
    final ok = await ref.read(planSettingsNotifierProvider.notifier).updateOrgName(name.trim());
    if (!mounted) return;
    ok ? ToastHelper.showSuccess(context, l10n.orgRenamed) : ToastHelper.showError(context, l10n.plansSaveFailed);
  }

  Future<void> _unlink(Organisation org) async {
    final l10n = context.l10n;
    final tenantId = ref.read(currentTenantIdProvider);
    final ok = await showAppConfirm(
      context,
      title: l10n.orgUnlink,
      message: l10n.orgUnlinkMessage(org.name),
      confirmText: l10n.orgUnlinkButton,
      destructive: true,
    );
    if (!ok || org.id == null || !_stillIn(tenantId)) return;
    final success = await ref.read(organisationNotifierProvider.notifier).unlinkCurrentTenant(org.id!);
    if (!mounted) return;
    success ? ToastHelper.showSuccess(context, l10n.orgUnlinked) : ToastHelper.showError(context, l10n.orgFlutterUnlinkFailed);
  }

  Future<void> _toggleBeamerFiles(bool enabled) async {
    final ok = await ref.read(planSettingsNotifierProvider.notifier).updateOrgGemeindeApp({'beamer_files_enabled': enabled});
    if (!ok && mounted) ToastHelper.showError(context, context.l10n.svcSaveGemeindeAppFailed);
  }

  /// Ionic org-settings "Werk-Synchronisierung" (super admin only): the
  /// group whose works this group uses, or its own works.
  Future<void> _pickSongSource(List<Tenant> others, int? current) async {
    final l10n = context.l10n;
    final tenantId = ref.read(currentTenantIdProvider);
    final picked = await showRdChoiceSheet<int>(
      context,
      title: l10n.rdOrgSongSource,
      selected: current ?? 0,
      options: [
        (0, l10n.orgNoneOwnSongs),
        for (final t in others)
          if (t.id != null) (t.id!, t.shortName),
      ],
    );
    if (!mounted || picked == null || !_stillIn(tenantId)) return;
    final next = picked == 0 ? null : picked;
    if (next == current) return;
    if (current != null && next == null) {
      final ok = await showAppConfirm(
        context,
        title: l10n.orgDisableSync,
        message: l10n.orgDisableSyncMessage,
        confirmText: l10n.orgDisable,
        destructive: true,
      );
      if (!mounted || !ok || !_stillIn(tenantId)) return;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = ref.read(songRepositoryForTenantProvider((tenantId: tenantId!, songSourceTenantId: null)));
    setState(() => _busy = true);
    try {
      await repo.updateSongSourceTenantId(next);
      container.invalidate(songTenantSettingsProvider);
      container.invalidate(currentTenantProvider);
      if (mounted) ToastHelper.showSuccess(context, l10n.orgSyncSaved);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, l10n.plansSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _header(BuildContext context, {bool showInfo = false}) {
    final p = context.rd;
    final l10n = context.l10n;
    return [
      RdManageBackLink(label: l10n.redesignMeAdmin, onTap: _back),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(l10n.orgTitle, style: RdType.largeTitle(p))),
          ),
          if (showInfo)
            RdCircleButton(
              key: const Key('rd-org-settings-info'),
              icon: Icons.info_outline,
              label: l10n.rdOrgInfoButtonTooltip,
              onPressed: () => showRdOrgInfoSheet(context, showManageButton: false),
            ),
        ],
      ),
      const SizedBox(height: 18),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    final isSuperAdmin = role == Role.admin;
    final lead = role.isAdmin || role.isResponsible;
    final orgAsync = ref.watch(currentOrganisationProvider);
    final tenant = ref.watch(currentTenantProvider);
    // After a group switch the provider reloads and may still hold the
    // previous group's organisation: show nothing of it then.
    final org = orgAsync.isReloading || orgAsync.hasError ? null : orgAsync.valueOrNull;

    if (orgAsync.isLoading && org == null) {
      return RdPage(children: [
        ..._header(context),
        RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
      ]);
    }
    if (orgAsync.hasError && org == null) {
      return RdPage(children: [
        ..._header(context),
        RdInfoCard(
          text: l10n.redesignTodayLoadFailed,
          icon: Icons.cloud_off_outlined,
          action: RdOutlineButton(
            label: l10n.redesignCommonRetry,
            onPressed: () => ref.invalidate(currentOrganisationProvider),
          ),
        ),
      ]);
    }
    if (org == null) {
      return RdPage(children: [
        ..._header(context),
        RdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.rdOrgNoneTitle, style: RdType.section(p)),
              const SizedBox(height: 6),
              Text(isSuperAdmin ? l10n.rdOrgNoneIntro : l10n.rdOrgNoneAdminOnly, style: RdType.meta(p)),
            ],
          ),
        ),
        if (isSuperAdmin) ...[
          const SizedBox(height: 14),
          RdPrimaryButton(label: l10n.rdOrgCreate, onPressed: () => showOrganisationLinkDialog(context, ref)),
        ],
      ]);
    }

    final linkedAsync = ref.watch(linkedTenantsProvider);
    final linked = (linkedAsync.isReloading ? null : linkedAsync.valueOrNull) ?? const <Tenant>[];
    final others = linked.where((t) => t.id != tenant?.id).toList();
    final songAsync = ref.watch(songTenantSettingsProvider);
    final songSource = songAsync.isReloading ? null : songAsync.valueOrNull?.songSourceTenantId;
    final songSourceName = songSource == null
        ? l10n.orgNoneOwnSongs
        : others.where((t) => t.id == songSource).map((t) => t.shortName).firstOrNull ?? l10n.orgNoneOwnSongs;
    const gap = SizedBox(height: 24);

    final totalGroups = others.length + 1;
    return RdPage(
      children: [
        ..._header(context, showInfo: true),
        RdCard(
          key: const Key('rd-org-settings-intro'),
          padding: const EdgeInsets.all(14),
          border: Border.all(color: p.primary.withValues(alpha: 0.25)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RdRowIcon(Icons.hub_outlined, color: p.softText, background: p.soft),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.rdOrgOrgIntro(org.name, totalGroups),
                  style: RdType.meta(p, size: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        RdGroupedList(children: [
          RdListRow(
            title: l10n.rdOrgName,
            value: org.name,
            showChevron: isSuperAdmin,
            onTap: isSuperAdmin ? () => _rename(org) : null,
          ),
        ]),
        if (isSuperAdmin || lead) ...[
          gap,
          RdGroupLabel(l10n.orgPersons),
          RdGroupedList(children: [
            if (isSuperAdmin) ...[
              RdListRow(
                leading: const RdRowIcon(Icons.merge_type),
                title: l10n.linkPersonsTitle,
                subtitle: l10n.rdOrgLinkPersonsHint,
                onTap: () => context.push('/settings/general/link-persons'),
              ),
              RdListRow(
                leading: const RdRowIcon(Icons.list_alt),
                title: l10n.rdOrgPersonFields,
                onTap: () => context.push('/settings/org-settings/person-fields'),
              ),
            ],
            if (lead)
              RdListRow(
                leading: const RdRowIcon(Icons.swap_horiz),
                title: l10n.rdOrgHandover,
                onTap: () => context.push('/settings/handover'),
              ),
          ]),
        ],
        gap,
        RdGroupLabel(l10n.rdOrgSectionPlansWorks),
        RdGroupedList(children: [
          RdListRow(
            leading: const RdRowIcon(Icons.palette_outlined),
            title: l10n.generalSettingsBranding,
            onTap: () => context.push('/settings/general/branding'),
          ),
          RdListRow(
            leading: const RdRowIcon(Icons.description_outlined),
            title: l10n.orgTemplatesTitle,
            onTap: () => context.push('/settings/org-settings/planning-templates'),
          ),
          RdListRow(
            leading: const RdRowIcon(Icons.calendar_month_outlined),
            title: l10n.orgOrgPlans,
            onTap: () => context.push('/settings/org-plans'),
          ),
          if (lead && others.isNotEmpty)
            RdListRow(
              leading: const RdRowIcon(Icons.search),
              title: l10n.rdOrgWorks,
              subtitle: l10n.rdOrgWorksHint,
              onTap: () => context.push('/settings/org-settings/songs'),
            ),
          if (isSuperAdmin && others.isNotEmpty)
            RdListRow(
              leading: const RdRowIcon(Icons.sync),
              title: l10n.rdOrgSongSource,
              value: songSourceName,
              onTap: _busy ? null : () => _pickSongSource(others, songSource),
            ),
        ]),
        if (isSuperAdmin && others.isNotEmpty) RdListNote(l10n.rdOrgSongSyncIntro),
        if (isSuperAdmin && PlanBeamer.gemeindeAppLinked(org)) ...[
          gap,
          RdGroupLabel(l10n.orgGemeindeApp),
          RdGroupedList(children: [
            RdSwitchRow(
              key: const ValueKey('org-beamer-files-toggle'),
              title: l10n.orgGaBeamerFiles,
              subtitle: l10n.orgGaBeamerFilesHint,
              value: org.beamerFilesEnabled,
              onChanged: _toggleBeamerFiles,
            ),
            RdListRow(
              key: const ValueKey('org-gemeinde-app-key'),
              title: l10n.rdOrgGaKey,
              subtitle: org.gemeindeAppKeyHash != null
                  ? l10n.rdOrgGaKeyActive(org.gemeindeAppKeyHint ?? '')
                  : l10n.rdOrgGaNoKey,
              value: org.gemeindeAppKeyHash != null ? l10n.orgGaRenewKey : l10n.orgGaCreateKey,
              onTap: () => createGemeindeAppKey(context, ref, org),
            ),
          ]),
          RdListNote(l10n.orgGaHint),
        ],
        if (others.isNotEmpty) ...[
          gap,
          RdGroupLabel(l10n.rdOrgSectionGroups),
          RdGroupedList(children: [
            RdListRow(
              title: tenant?.longName ?? tenant?.shortName ?? '',
              value: l10n.rdOrgThisGroup,
              showChevron: false,
            ),
            for (final t in others) RdListRow(title: t.longName, showChevron: false),
          ]),
        ],
        if (isSuperAdmin) ...[
          gap,
          RdGroupedList(children: [
            RdListRow(
              title: l10n.rdOrgUnlink,
              titleColor: p.absent,
              showChevron: false,
              onTap: () => _unlink(org),
            ),
          ]),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

/// Ionic 4.17.10 `createGemeindeAppKey`: only the hash is stored, so the
/// key is shown once. A new key cuts the old link.
Future<void> createGemeindeAppKey(BuildContext context, WidgetRef ref, Organisation org) async {
  final l10n = context.l10n;
  final stillCurrent = bindCurrentTenant(context);
  final notifier = ref.read(planSettingsNotifierProvider.notifier);
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
  if (!stillCurrent()) return;
  final created = PlanBeamer.newGemeindeAppKey();
  final saved = await notifier.updateOrgGemeindeApp({
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
