import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/branding_providers.dart';
import '../../../../core/providers/files_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2

/// Maximale Logo-Größe (2 MB, wie Ionic)
const int kMaxLogoBytes = 2 * 1024 * 1024;

/// Branding der Organisation: Logo + Text (Ionic: settings/general/branding)
class BrandingPage extends ConsumerStatefulWidget {
  const BrandingPage({super.key});

  @override
  ConsumerState<BrandingPage> createState() => _BrandingPageState();
}

class _BrandingPageState extends ConsumerState<BrandingPage> {
  final _textController = TextEditingController();
  String _logoUrl = '';
  bool _initialized = false;
  bool _busy = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _selectLogo() async {
    final organisationSettingsRepo = ref.read(organisationSettingsRepositoryWithTenantProvider);
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null || !mounted) return;
    if (file.size > kMaxLogoBytes) {
      ToastHelper.showError(context, context.l10n.brandingLogoTooBig);
      return;
    }
    final ext = (file.extension ?? '').toLowerCase();
    const imageExt = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp', 'heic', 'heif'];
    if (!imageExt.contains(ext)) {
      ToastHelper.showError(context, context.l10n.brandingSelectImage);
      return;
    }

    setState(() => _busy = true);
    try {
      final url = await organisationSettingsRepo.uploadLogo(
            file.bytes!,
            contentType: ext == 'svg' ? 'image/svg+xml' : 'image/${ext == 'jpg' ? 'jpeg' : ext}',
          );
      if (!mounted) return;
      setState(() => _logoUrl = url);
      ToastHelper.showSuccess(context, context.l10n.brandingLogoUploaded);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeLogo() async {
    setState(() => _busy = true);
    try {
      await ref.read(organisationSettingsRepositoryWithTenantProvider).removeLogo();
      if (!mounted) return;
      setState(() => _logoUrl = '');
      ToastHelper.showSuccess(context, context.l10n.brandingLogoRemoved);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(organisationSettingsRepositoryWithTenantProvider).updateBranding(
            logoUrl: _logoUrl,
            brandingText: _textController.text,
          );
      ref.invalidate(brandingOrganisationProvider);
      ref.invalidate(brandingSourceProvider); // MISC2: refresh export branding
      ref.invalidate(currentOrganisationProvider);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.brandingSaved);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.svcSaveBrandingFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(brandingOrganisationProvider);
    final hasOrg = orgAsync.valueOrNull != null;

    final ios = ionIsIos(context);
    final pStyle = TextStyle(
      fontSize: 14,
      color: ios ? IonIos.labelP(context) : AppColors.medium,
    );

    // UX_SETTINGS (WAVE 8): branding.page.html — arrow-back, checkmark save,
    // intro / logo / text as inset lists, block save button.
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.l10n.generalSettingsBranding),
        actions: [
          if (hasOrg)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _busy ? null : _save,
            ),
        ],
      ),
      body: orgAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (e, _) => Center(child: Text(context.l10n.settingsFlutterLoadFailed(friendlyErrorMessage(e)))),
        data: (org) {
          if (org == null) {
            return ListView(
              padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
              children: [
                SettingsListSection(
                  children: [
                    SettingsListTile(
                      icon: Icons.info_outline,
                      iconColor: AppColors.medium,
                      title: '',
                      titleWidget: Text(context.l10n.brandingOrgOnly, style: pStyle),
                    ),
                  ],
                ),
              ],
            );
          }
          if (!_initialized) {
            _initialized = true;
            _logoUrl = org.logoUrl ?? '';
            _textController.text = org.brandingText ?? '';
          }
          return Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
                children: [
                  SettingsListSection(
                    icons: false,
                    children: [
                      ListTile(title: Text(context.l10n.brandingIntro, style: pStyle)),
                    ],
                  ),
                  SettingsListSection(
                    title: context.l10n.brandingLogo,
                    children: [
                      if (_logoUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 120),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Image.network(
                                _logoUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 48),
                              ),
                            ),
                          ),
                        ),
                      SettingsListTile(
                        icon: Icons.image_outlined,
                        color: AppColors.primary,
                        detail: false,
                        title: _logoUrl.isNotEmpty ? context.l10n.brandingFlutterReplaceLogo : context.l10n.brandingFlutterUploadLogo,
                        onTap: _busy ? null : _selectLogo,
                      ),
                      if (_logoUrl.isNotEmpty)
                        SettingsListTile(
                          icon: Icons.delete_outline,
                          color: AppColors.danger,
                          detail: false,
                          title: context.l10n.brandingRemoveLogo,
                          onTap: _busy ? null : _removeLogo,
                        ),
                    ],
                  ),
                  SettingsListSection(
                    icons: false,
                    children: [
                      IonStackedField(
                        label: context.l10n.brandingText,
                        hint: context.l10n.brandingTextPh,
                        builder: (decoration) => TextField(
                          controller: _textController,
                          maxLength: 60,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: decoration.copyWith(counterText: ios ? '' : null),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _busy ? null : _save,
                    child: Text(context.l10n.commonSave),
                  ),
                ],
              ),
              if (_busy) const LinearProgressIndicator(),
            ],
          );
        },
      ),
    );
  }
}
