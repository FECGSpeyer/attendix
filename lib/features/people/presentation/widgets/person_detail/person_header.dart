import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/constants/table_names.dart';
import '../../../../../core/providers/realtime_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../shared/widgets/sheets/image_viewer_sheet.dart';
import '../../pages/person_detail_page.dart';
import '../../../../../core/utils/demo_guard.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../../../../../core/utils/profile_image_path.dart'; // DB_REVIEW_REST
import '../../../../../core/providers/player_providers.dart'; // ASTRA_PHOTO
import '../person_image_picker.dart'; // ASTRA_PHOTO

/// UX_PEOPLE: Ionic person.page `.profile-header`: 120px avatar with white
/// ring and shadow, camera badge when editable, name (h1) with a pencil
/// button that shows the name inputs.
class PersonHeader extends ConsumerWidget {
  const PersonHeader({
    super.key,
    required this.person,
    required this.statsAsync,
    this.canEdit = false,
    this.onEditName,
  });

  final Person person;
  final AsyncValue<Map<String, dynamic>> statsAsync;
  final bool canEdit;

  /// Ionic `editingName = true` (pencil next to the name).
  final VoidCallback? onEditName;

  bool get _hasImage =>
      person.img != null &&
      person.img!.isNotEmpty &&
      !person.img!.contains('.svg');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ringColor = dark ? Colors.black : Colors.white;
    final placeholder = Container(
      color: dark ? const Color(0xFF222428) : AppColors.light,
      alignment: Alignment.bottomCenter,
      child: Icon(
        Icons.person,
        size: 104,
        color: dark ? const Color(0xFF555555) : const Color(0xFFC5C5C5),
      ),
    );
    final name = '${person.firstName} ${person.lastName}'.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _onAvatarTap(context, ref),
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Hero(
                    tag: 'person-${person.id}',
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ringColor, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x2E000000),
                            offset: Offset(0, 4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _hasImage
                            ? Image.network(
                                person.img!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => placeholder,
                              )
                            : placeholder,
                      ),
                    ),
                  ),
                  if (canEdit)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: ringColor, width: 3),
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (name.isNotEmpty || onEditName != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21.6,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (onEditName != null) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 28,
                      width: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: context.l10n.personEditName,
                        icon: const Icon(Icons.edit_note,
                            size: 20, color: AppColors.medium),
                        onPressed: onEditName,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onAvatarTap(BuildContext context, WidgetRef ref) async {
    if (!canEdit && !_hasImage) return;

    // If not editable but has image, just view it
    if (!canEdit && _hasImage) {
      showImageViewerSheet(
        context,
        url: person.img!,
        fileName: '${person.fullName}.jpg',
      );
      return;
    }

    // Capture outer context before bottom sheet builder shadows it
    final outerContext = context;

    // Show action sheet (IOS_LOOK: adaptive ion-action-sheet)
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        AppActionSheetAction(
          value: 'replace',
          icon: Icons.photo_camera,
          label: context.l10n.settingsReplacePhoto,
        ),
        if (_hasImage)
          AppActionSheetAction(
            value: 'remove',
            icon: Icons.delete,
            label: context.l10n.personRemovePhoto,
            destructive: true,
          ),
        if (_hasImage)
          AppActionSheetAction(
            value: 'view',
            icon: Icons.visibility,
            label: context.l10n.settingsViewPhoto,
          ),
      ],
    );
    if (!outerContext.mounted) return;
    switch (action) {
      case 'replace':
        _replacePhoto(outerContext, ref);
      case 'remove':
        _removePhoto(outerContext, ref);
      case 'view':
        showImageViewerSheet(
          outerContext,
          url: person.img!,
          fileName: '${person.fullName}.jpg',
        );
    }
  }

  Future<void> _replacePhoto(BuildContext context, WidgetRef ref) async {
    // Bind the tenant-scoped repository before the first await (tenant switch).
    final repo = ref.read(playerRepositoryWithTenantProvider);
    final supabase = ref.read(supabaseClientProvider);
    final tenant = ref.read(currentTenantProvider);
    try {
      final image = await ref.read(personImagePickerProvider)();

      if (image == null) return;

      if (!context.mounted) return;
      ToastHelper.showInfo(context, context.l10n.personFlutterUploadingPhoto);

      final bytes = await image.readAsBytes();

      // Check file size (max 2MB)
      if (bytes.length > kPersonImageMaxBytes) {
        if (context.mounted) {
          ToastHelper.showError(context, context.l10n.personPhotoTooLarge);
        }
        return;
      }

      if (DemoGuard.blocked()) return; // DEMO_GUARD
      final personId = person.id;

      if (personId == null || tenant == null) return;

      // DB_REVIEW_REST (M4): Ionic ImageService.updateImage – key `<id>`,
      // upsert, plain public URL in player.img (no tenant folder).
      // ASTRA_PHOTO: upload + img update shared via PlayerRepository.updateImage.
      final storagePath = profileImageStoragePath(personId);
      final legacyPath = profileImagePathFromUrl(person.img);

      final publicUrl = await repo.updateImage(personId, bytes);

      // Drop a legacy `<tenantId>/<id>.jpg` object so it does not stay orphaned.
      if (legacyPath != null && legacyPath != storagePath) {
        try {
          await supabase.storage
              .from(SupabaseBuckets.profiles)
              .remove([legacyPath]);
        } catch (_) {}
      }

      // Same URL after a replace: drop the cached image so it reloads.
      try {
        await CachedNetworkImage.evictFromCache(publicUrl);
      } catch (_) {}

      ref.invalidate(personProvider(personId));
      ref.invalidate(realtimePlayersProvider);

      if (context.mounted) {
        ToastHelper.showSuccess(context, context.l10n.settingsPhotoChanged);
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(context, context.l10n.personFlutterUploadFailedWith(friendlyErrorMessage(e)));
      }
    }
  }

  Future<void> _removePhoto(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.personRemovePhoto),
        content: Text(context.l10n.personRemovePhotoMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.commonRemove),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      if (DemoGuard.blocked()) return; // DEMO_GUARD
      final supabase = ref.read(supabaseClientProvider);
      final tenant = ref.read(currentTenantProvider);
      final personId = person.id;

      if (personId == null || tenant == null) return;

      // DB_REVIEW_REST (M4): Ionic removeImage – clear img with '' (Ionic
      // code calls img.split and breaks on null), then delete the object
      // whose key is taken from the stored URL.
      await supabase
          .from('player')
          .update({'img': ''})
          .eq('id', personId)
          .eq('tenantId', tenant.id!);

      final storagePath = profileImagePathFromUrl(person.img);
      if (storagePath != null) {
        try {
          await supabase.storage
              .from(SupabaseBuckets.profiles)
              .remove([storagePath]);
        } catch (_) {}
      }

      ref.invalidate(personProvider(personId));
      ref.invalidate(realtimePlayersProvider);

      if (context.mounted) {
        ToastHelper.showSuccess(context, context.l10n.personPhotoRemoved);
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e)));
      }
    }
  }
}

