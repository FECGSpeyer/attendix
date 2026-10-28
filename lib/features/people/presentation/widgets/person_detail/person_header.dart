import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/constants/app_constants.dart';
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
import '../../../../../core/utils/profile_image_path.dart'; // DB_REVIEW_REST

/// Header widget displaying person avatar, group, and attendance stats.
class PersonHeader extends ConsumerWidget {
  const PersonHeader({
    super.key,
    required this.person,
    required this.statsAsync,
    this.canEdit = false,
  });

  final Person person;
  final AsyncValue<Map<String, dynamic>> statsAsync;
  final bool canEdit;

  bool get _hasImage =>
      person.img != null &&
      person.img!.isNotEmpty &&
      !person.img!.contains('.svg');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            person.isCritical ? AppColors.danger : AppColors.primary,
            (person.isCritical ? AppColors.danger : AppColors.primary)
                .withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _onAvatarTap(context, ref),
            child: Hero(
              tag: 'person-${person.id}',
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                backgroundImage: _hasImage ? NetworkImage(person.img!) : null,
                child: !_hasImage
                    ? Text(
                        person.initials,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          if (person.groupName != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingXS,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusS),
              ),
              child: Text(
                person.groupName!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: AppDimensions.paddingM),
          statsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatItem(
                  value: '${stats['percentage']}%',
                  label: stats['lateCount'] > 0
                      ? context.l10n.personFlutterAttendanceLate(stats['lateCount'] as int)
                      : context.l10n.peopleAttendance,
                  color: stats['percentage'] >= 75
                      ? AppColors.success
                      : stats['percentage'] >= 50
                          ? AppColors.warning
                          : AppColors.danger,
                ),
                Container(
                  width: 1,
                  height: 40,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingL,
                  ),
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                _StatItem(
                  value: '${stats['attended']}/${stats['total']}',
                  label: context.l10n.tabsEvents,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onAvatarTap(BuildContext context, WidgetRef ref) {
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

    // Show action sheet
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(context.l10n.settingsReplacePhoto),
              onTap: () {
                Navigator.pop(sheetContext);
                _replacePhoto(outerContext, ref);
              },
            ),
            if (_hasImage)
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.danger),
                title: Text(context.l10n.personRemovePhoto),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removePhoto(outerContext, ref);
                },
              ),
            if (_hasImage)
              ListTile(
                leading: const Icon(Icons.visibility),
                title: Text(context.l10n.settingsViewPhoto),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showImageViewerSheet(
                    outerContext,
                    url: person.img!,
                    fileName: '${person.fullName}.jpg',
                  );
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(context.l10n.commonCancel),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _replacePhoto(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image == null) return;

      if (!context.mounted) return;
      ToastHelper.showInfo(context, context.l10n.personFlutterUploadingPhoto);

      final bytes = await image.readAsBytes();

      // Check file size (max 2MB)
      if (bytes.length > 2 * 1024 * 1024) {
        if (context.mounted) {
          ToastHelper.showError(context, context.l10n.personPhotoTooLarge);
        }
        return;
      }

      if (DemoGuard.blocked()) return; // DEMO_GUARD
      final supabase = ref.read(supabaseClientProvider);
      final tenant = ref.read(currentTenantProvider);
      final personId = person.id;

      if (personId == null || tenant == null) return;

      // DB_REVIEW_REST (M4): Ionic ImageService.updateImage – key `<id>`,
      // upsert, plain public URL in player.img (no tenant folder).
      final storagePath = profileImageStoragePath(personId);
      final legacyPath = profileImagePathFromUrl(person.img);

      await supabase.storage.from(SupabaseBuckets.profiles).uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Drop a legacy `<tenantId>/<id>.jpg` object so it does not stay orphaned.
      if (legacyPath != null && legacyPath != storagePath) {
        try {
          await supabase.storage
              .from(SupabaseBuckets.profiles)
              .remove([legacyPath]);
        } catch (_) {}
      }

      final publicUrl = supabase.storage
          .from(SupabaseBuckets.profiles)
          .getPublicUrl(storagePath);

      // Same URL after a replace: drop the cached image so it reloads.
      try {
        await CachedNetworkImage.evictFromCache(publicUrl);
      } catch (_) {}

      // Update player record
      await supabase
          .from('player')
          .update({'img': publicUrl})
          .eq('id', personId)
          .eq('tenantId', tenant.id!);

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
