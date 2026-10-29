import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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
