import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../shared/widgets/sheets/image_viewer_sheet.dart';
import '../../../../../l10n/l10n.dart';
import 'person_photo_actions.dart';

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

  /// Ionic onProfileImageClick: a picture opens the viewer (with
  /// "Ersetzen" / "Entfernen" when editable); no picture + editable opens
  /// the file chooser directly.
  Future<void> _onAvatarTap(BuildContext context, WidgetRef ref) async {
    if (_hasImage) {
      await showImageViewerSheet(
        context,
        url: person.img!,
        fileName: '${person.fullName}.jpg',
        actions: [
          if (canEdit) ...[
            ImageViewerAction(
              label: context.l10n.personReplace,
              icon: Icons.photo_camera_outlined,
              onPressed: () => replacePersonPhoto(context, ref, person),
            ),
            ImageViewerAction(
              label: context.l10n.commonRemove,
              icon: Icons.delete_outline,
              destructive: true,
              onPressed: () => removePersonPhoto(context, ref, person),
            ),
          ],
        ],
      );
    } else if (canEdit) {
      await replacePersonPhoto(context, ref, person);
    }
  }
}
