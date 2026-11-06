import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/branding_providers.dart';
import '../../../../core/providers/files_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/organisation/organisation.dart';
import '../../../../data/repositories/organisation_settings_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../settings/presentation/pages/branding_page.dart' show kMaxLogoBytes;
import '../../data/rd_manage_logic.dart' show RdManageArea;
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/rd_widgets.dart';

/// REDESIGN: Verwaltung › Gruppe › Branding (canvas "Beta: Gruppe und
/// Daten", board "G1 Branding"). Same data as the old page
/// `/settings/general/branding` (logo + text of the organisation), but every
/// change is saved right away: uploading or removing the logo stores the
/// new logo URL, the text is edited in a sheet.
class RdBrandingPage extends ConsumerStatefulWidget {
  const RdBrandingPage({super.key});

  @override
  ConsumerState<RdBrandingPage> createState() => _RdBrandingPageState();
}

class _RdBrandingPageState extends ConsumerState<RdBrandingPage> {
  bool _busy = false;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.manageArea(RdManageArea.group.key));
    }
  }

  /// The organisation as `updateBranding` returned it. The page shows and
  /// edits this one, so a later change always starts from what was saved,
  /// even when reloading the organisation fails.
  Organisation? _saved;

  /// Group (and so organisation context) [_saved] belongs to; it is only
  /// used while that group is still the current one.
  int? _savedTenantId;

  /// Stores logo and text together (the repository writes both columns),
  /// keeps the returned organisation and refreshes the cached ones.
  Future<void> _store(
    ProviderContainer container,
    OrganisationSettingsRepository repo, {
    required int? tenantId,
    required String logoUrl,
    required String text,
  }) async {
    // Started in another group than the current one: write nothing.
    if (tenantId == null || container.read(currentTenantIdProvider) != tenantId) return;
    final saved = await repo.updateBranding(logoUrl: logoUrl, brandingText: text);
    if (mounted && ref.read(currentTenantIdProvider) == tenantId) {
      setState(() {
        _saved = saved;
        _savedTenantId = tenantId;
      });
    }
    container.invalidate(brandingOrganisationProvider);
    container.invalidate(brandingSourceProvider);
    container.invalidate(currentOrganisationProvider);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || DemoGuard.blocked()) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectLogo(Organisation org) async {
    final l10n = context.l10n;
    // Read the tenant-bound repository before the first await.
    final repo = ref.read(organisationSettingsRepositoryWithTenantProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final tenantId = ref.read(currentTenantIdProvider);
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null || !mounted) return;
    if (file.size > kMaxLogoBytes) {
      ToastHelper.showError(context, l10n.brandingLogoTooBig);
      return;
    }
    final ext = (file.extension ?? '').toLowerCase();
    const imageExt = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp', 'heic', 'heif'];
    if (!imageExt.contains(ext)) {
      ToastHelper.showError(context, l10n.brandingSelectImage);
      return;
    }
    await _run(() async {
      if (container.read(currentTenantIdProvider) != tenantId) return;
      final url = await repo.uploadLogo(
        file.bytes!,
        contentType: ext == 'svg' ? 'image/svg+xml' : 'image/${ext == 'jpg' ? 'jpeg' : ext}',
      );
      await _store(container, repo, tenantId: tenantId, logoUrl: url, text: org.brandingText ?? '');
      if (mounted) ToastHelper.showSuccess(context, l10n.rdSettingsBrandingLogoSaved);
    });
  }

  Future<void> _removeLogo(Organisation org) async {
    final l10n = context.l10n;
    final repo = ref.read(organisationSettingsRepositoryWithTenantProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final tenantId = ref.read(currentTenantIdProvider);
    final confirmed = await showAppConfirm(
      context,
      title: l10n.rdSettingsBrandingRemoveLogo,
      confirmText: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      if (container.read(currentTenantIdProvider) != tenantId) return;
      await repo.removeLogo();
      await _store(container, repo, tenantId: tenantId, logoUrl: '', text: org.brandingText ?? '');
      if (mounted) ToastHelper.showSuccess(context, l10n.rdSettingsBrandingLogoRemoved);
    });
  }

  Future<void> _editText(Organisation org) async {
    final l10n = context.l10n;
    final repo = ref.read(organisationSettingsRepositoryWithTenantProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final tenantId = ref.read(currentTenantIdProvider);
    final value = await showRdTextSheet(
      context,
      title: l10n.brandingText,
      initial: org.brandingText ?? '',
      hint: l10n.brandingTextPh,
      maxLength: 60,
    );
    if (value == null || !mounted) return;
    await _run(() async {
      await _store(container, repo, tenantId: tenantId, logoUrl: org.logoUrl ?? '', text: value);
      if (mounted) ToastHelper.showSuccess(context, l10n.brandingSaved);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final orgAsync = ref.watch(brandingOrganisationProvider);
    final header = <Widget>[
      RdBackLink(label: l10n.rdSettingsBack, onTap: _back),
      const SizedBox(height: 4),
      Semantics(header: true, child: Text(l10n.rdSettingsBrandingTitle, style: RdType.largeTitle(p))),
      const SizedBox(height: 8),
    ];
    final tenantId = ref.watch(currentTenantIdProvider);
    final org = (_saved != null && _savedTenantId == tenantId ? _saved : null) ?? orgAsync.valueOrNull;
    if (orgAsync.isLoading && org == null) {
      return RdPage(
        children: [
          ...header,
          Center(child: Padding(padding: const EdgeInsets.all(32), child: CircularProgressIndicator(color: p.primary))),
        ],
      );
    }
    if (orgAsync.hasError && org == null) {
      return RdPage(
        children: [...header, RdListNote(l10n.settingsFlutterLoadFailed(friendlyErrorMessage(orgAsync.error!)))],
      );
    }
    if (org == null) {
      return RdPage(
        children: [
          ...header,
          const SizedBox(height: 10),
          RdCard(child: Text(l10n.rdSettingsBrandingNoOrg, style: RdType.body(p))),
          const SizedBox(height: 14),
          RdOutlineButton(label: l10n.rdSettingsBrandingToOrg, onPressed: () => context.push('/settings/org-settings')),
        ],
      );
    }
    final logo = org.logoUrl ?? '';
    final text = org.brandingText ?? '';
    return RdPage(
      children: [
        ...header,
        Text(l10n.rdSettingsBrandingIntro, style: RdType.meta(p)),
        const SizedBox(height: 18),
        RdCard(
          child: Column(
            children: [
              Container(
                width: 140,
                height: 120,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.text2.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child:
                    logo.isEmpty
                        ? Text(l10n.brandingLogo, style: RdType.meta(p).copyWith(color: Colors.black54))
                        : Image.network(
                          logo,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 40, color: Colors.black45),
                        ),
              ),
              const SizedBox(height: 14),
              if (_busy) ...[LinearProgressIndicator(color: p.primary), const SizedBox(height: 14)],
              Row(
                children: [
                  Expanded(
                    child: RdPrimaryButton(
                      label: logo.isEmpty ? l10n.brandingFlutterUploadLogo : l10n.brandingFlutterReplaceLogo,
                      onPressed: _busy ? null : () => _selectLogo(org),
                    ),
                  ),
                  if (logo.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: RdOutlineButton(
                        label: l10n.commonDelete,
                        color: p.absent,
                        onPressed: _busy ? null : () => _removeLogo(org),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(l10n.rdSettingsBrandingLogoHint, style: RdType.meta(p)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        RdGroupedList(
          children: [
            RdListRow(
              title: l10n.brandingText,
              value: text.isEmpty ? l10n.rdSettingsBrandingNoText : text,
              onTap: _busy ? null : () => _editText(org),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
