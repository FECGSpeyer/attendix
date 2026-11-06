import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/constants/table_names.dart';
import '../../../../../core/providers/player_providers.dart';
import '../../../../../core/providers/realtime_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/services/error_reporter.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/demo_guard.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../core/utils/profile_image_path.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';
import '../../pages/person_detail_page.dart' show personProvider;
import '../person_image_picker.dart';

/// Passbild of an existing person: pick, upload and store (Ionic
/// ImageService.updateImage). Shared by the person page of the normal app
/// ([PersonHeader]) and "Person bearbeiten" of the new design.
Future<void> replacePersonPhoto(BuildContext context, WidgetRef ref, Person person) async {
  // Bind the tenant-scoped repository before the first await (tenant switch).
  final repo = ref.read(playerRepositoryWithTenantProvider);
  final supabase = ref.read(supabaseClientProvider);
  final tenant = ref.read(currentTenantProvider);
  try {
    final image = await pickPersonImage(context, ref);

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

    // Ionic: own picture → all instances of the account (appId).
    final publicUrl = await repo.updateImage(personId, bytes, appId: person.appId);

    // Drop a legacy `<tenantId>/<id>.jpg` object so it does not stay orphaned
    // (never the file of another person, e.g. an adopted e-mail match).
    if (legacyPath != null &&
        legacyPath != storagePath &&
        isOwnProfileImagePath(legacyPath, personId)) {
      try {
        await supabase.storage
            .from(SupabaseBuckets.profiles)
            .remove([legacyPath]);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'person_header');
      }
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

/// Removes the Passbild of an existing person after a confirmation (Ionic
/// removeImgFromViewer / removeImage).
Future<void> removePersonPhoto(BuildContext context, WidgetRef ref, Person person) async {
  // Bound before the dialog (tenant switch safety).
  final repo = ref.read(playerRepositoryWithTenantProvider);
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
    await repo.updatePlayerFields(personId, {'img': ''});
    // Ionic removeImage with the own appId clears every instance's row.
    await repo.syncOwnImage(person.appId, '');

    // Only the person's own file: an adopted picture (e-mail match of
    // another instance) belongs to that person.
    final storagePath = profileImagePathFromUrl(person.img);
    if (storagePath != null && isOwnProfileImagePath(storagePath, personId)) {
      try {
        await supabase.storage
            .from(SupabaseBuckets.profiles)
            .remove([storagePath]);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'person_header');
      }
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
