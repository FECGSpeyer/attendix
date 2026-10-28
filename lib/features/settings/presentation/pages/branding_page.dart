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
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

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

    return Scaffold(
      appBar: AppBar(
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
            return Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline, color: AppColors.medium),
                  title: Text(
                    context.l10n.brandingOrgOnly,
                  ),
                ),
              ),
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
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      child: Text(
                        context.l10n.brandingIntro,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  Text(context.l10n.brandingLogo,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          )),
                  const SizedBox(height: AppDimensions.paddingS),
                  Card(
                    child: Column(
                      children: [
                        if (_logoUrl.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(AppDimensions.paddingM),
                            child: Image.network(
                              _logoUrl,
                              height: 120,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 48),
                            ),
                          ),
                        ListTile(
                          leading: const Icon(Icons.image_outlined, color: AppColors.primary),
                          title: Text(
                            _logoUrl.isNotEmpty ? context.l10n.brandingFlutterReplaceLogo : context.l10n.brandingFlutterUploadLogo,
                            style: const TextStyle(color: AppColors.primary),
                          ),
                          onTap: _busy ? null : _selectLogo,
                        ),
                        if (_logoUrl.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                            title: Text(context.l10n.brandingRemoveLogo, style: const TextStyle(color: AppColors.danger)),
                            onTap: _busy ? null : _removeLogo,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  TextField(
                    controller: _textController,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: context.l10n.brandingText,
                      hintText: context.l10n.brandingTextPh,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
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
