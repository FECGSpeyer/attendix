import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/native/native_platform.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// ASTRA_PHOTO: picks a Passbild from the gallery (Ionic hidden
/// `<input type="file" accept="image/*">` behind the profile avatar).
typedef PersonImagePicker = Future<XFile?> Function();

/// Max upload size of a Passbild (Ionic person.page onImageSelect: 2 MB).
const int kPersonImageMaxBytes = 2 * 1024 * 1024;

/// Shared by the person detail header and the create page so both pick with
/// the same settings. Overridable in tests (injectable seam).
final personImagePickerProvider = Provider<PersonImagePicker>((ref) {
  return () => ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
});

/// Ionic `<input type="file" accept="image/*">`: on iOS/Android the system
/// offers camera or photo library. The browser file input already does that
/// on the web, so only the installed app asks for the source first.
Future<XFile?> pickPersonImage(BuildContext context, WidgetRef ref) async {
  final pickFromGallery = ref.read(personImagePickerProvider);
  if (!isNativeApp) return pickFromGallery();
  final source = await showAppActionSheet<ImageSource>(
    context,
    actions: [
      AppActionSheetAction(
        value: ImageSource.camera,
        icon: AppIcons.photoCameraOutlined,
        label: context.l10n.attendanceFlutterCamera,
      ),
      AppActionSheetAction(
        value: ImageSource.gallery,
        icon: AppIcons.photoLibraryOutlined,
        label: context.l10n.attendanceFlutterGallery,
      ),
    ],
  );
  if (source == null) return null;
  if (source == ImageSource.gallery) return pickFromGallery();
  return ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 800,
    maxHeight: 800,
    imageQuality: 80,
  );
}
