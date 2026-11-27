import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../attendance/presentation/widgets/event/rd_form_widgets.dart';
import '../../../people/presentation/widgets/members/rd_person_form.dart' show RdPersonAvatar;
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/repositories/profile_repository.dart';
import '../../../../shared/widgets/sheets/image_viewer_sheet.dart';
import 'church_picker.dart';
import 'profile_helpers.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/presentation/widgets/ion_form_list.dart' show showIonSelectOptions;
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

part 'master_data_sheet_form.dart';

/// Opens the "Meine Stammdaten" sheet.
Future<void> showMasterDataSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    // Closing only via "Fertig"/back/barrier, so open changes get saved
    // first (pulling down would pop past PopScope).
    enableDrag: false,
    backgroundColor: context.rd.bg,
    // Only as high as the fields (few fields left a big empty sheet).
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.95),
      child: const MasterDataSheet(),
    ),
  );
}

/// Edit own master data: Passbild, name, phone, birthday, extra fields.
class MasterDataSheet extends ConsumerStatefulWidget {
  const MasterDataSheet({super.key});

  @override
  ConsumerState<MasterDataSheet> createState() => _MasterDataSheetState();
}

class _MasterDataSheetState extends ConsumerState<MasterDataSheet> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final Map<String, TextEditingController> _fieldControllers = {};
  String? _birthday;
  String? _img;
  Map<String, dynamic> _additional = {};
  OwnProfile? _profile;
  // Last ownProfileProvider value taken over as comparison base.
  OwnProfile? _loadedProfile;
  bool _initialized = false;
  bool _saving = false;

  // REDESIGN (E2) live save: changes not saved yet, a save asked for while
  // one runs, the pause timer and whether something was saved already.
  bool _dirty = false;
  bool _again = false;
  bool _closing = false;
  bool _saved = false;
  Timer? _pause;
  List<ProfileExtraField> _visibleFields = const [];

  void _update(VoidCallback fn) => setState(fn);

  @override
  void dispose() {
    _pause?.cancel();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _init(OwnProfile profile, List<ProfileExtraField> visibleFields) {
    _profile = profile;
    _loadedProfile = profile;
    final p = profile.person;
    _firstName.text = p.firstName;
    _lastName.text = p.lastName;
    _phone.text = p.phone ?? '';
    _birthday = p.birthday;
    _img = p.img;
    _additional = Map<String, dynamic>.from(profile.additionalFields);
    // Pre-fill editable extra fields with default values if not yet set
    for (final field in visibleFields) {
      if (field.editableByPlayers &&
          !_additional.containsKey(field.id) &&
          field.defaultValue != null) {
        _additional[field.id] = field.defaultValue;
      }
    }
    _initialized = true;
  }

  TextEditingController _controllerFor(ProfileExtraField field) {
    return _fieldControllers.putIfAbsent(
      field.id,
      () => TextEditingController(text: _additional[field.id]?.toString() ?? ''),
    );
  }

  Future<void> _pickBirthday() async {
    final current = DateTime.tryParse(_birthday ?? '');
    final picked = await showAppDatePicker(
      context: context,
      initialDate: current ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: Locale(currentLanguage()),
    );
    if (picked != null) {
      setState(() {
        _birthday =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
      _changed(now: true);
    }
  }

  Future<void> _changeImg() async {
    final hasImg = hasCustomProfileImage(_img);
    // IOS_LOOK: Ionic action sheet (adaptive).
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        AppActionSheetAction(
          value: 'replace',
          label: context.l10n.settingsReplacePhoto,
          icon: AppIcons.photoLibraryOutlined,
        ),
        if (hasImg) ...[
          AppActionSheetAction(
            value: 'view',
            label: context.l10n.settingsViewPhoto,
            icon: AppIcons.visibilityOutlined,
          ),
          AppActionSheetAction(
            value: 'remove',
            label: context.l10n.settingsRemovePhoto,
            icon: AppIcons.deleteOutline,
            destructive: true,
          ),
        ],
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'replace':
        await _replaceImg();
      case 'view':
        await showImageViewerSheet(
          context,
          url: _img!.replaceAll('?quality=20', ''),
          fileName: 'Passbild.jpg',
        );
      case 'remove':
        await _removeImg();
    }
  }

  Future<void> _replaceImg() async {
    final playerId = _profile?.person.id;
    if (playerId == null) return;
    try {
      // Ionic <input type="file" accept="image/*">: in the native app the
      // system offers photo library and camera; the browser (PWA) opens its
      // own file picker.
      // Camera only on iOS/Android: image_picker has no camera on desktop.
      var source = ImageSource.gallery;
      final hasCamera = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android);
      if (hasCamera) {
        final picked = await showAppActionSheet<ImageSource>(
          context,
          actions: [
            AppActionSheetAction(
              value: ImageSource.gallery,
              label: context.l10n.attendanceFlutterGallery,
              icon: AppIcons.photoLibraryOutlined,
            ),
            AppActionSheetAction(
              value: ImageSource.camera,
              label: context.l10n.attendanceFlutterCamera,
              icon: AppIcons.cameraAltOutlined,
            ),
          ],
        );
        if (picked == null || !mounted) return;
        source = picked;
      }
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 2 * 1024 * 1024) {
        ToastHelper.showError(context, context.l10n.settingsImageTooBig);
        return;
      }
      final url = await ref.read(profileNotifierProvider.notifier).updateImage(
            playerId: playerId,
            bytes: bytes,
            contentType: image.mimeType ?? 'image/jpeg',
          );
      if (!mounted) return;
      if (url != null) {
        setState(() => _img = url);
        ToastHelper.showSuccess(context, context.l10n.settingsPhotoChanged);
      } else {
        ToastHelper.showError(
          context,
          context.l10n.settingsPhotoChangeFailed,
        );
      }
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(
          context,
          context.l10n.settingsPhotoChangeFailed,
        );
      }
    }
  }

  Future<void> _removeImg() async {
    final img = _img;
    if (img == null) return;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.settingsRemovePhoto,
      message: context.l10n.settingsRemovePhotoConfirm,
      confirmText: context.l10n.commonRemove,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(profileNotifierProvider.notifier).removeImage(img);
    if (!mounted) return;
    if (ok) {
      setState(() => _img = '');
      ToastHelper.showSuccess(context, context.l10n.settingsPhotoRemoved);
    } else {
      ToastHelper.showError(
        context,
        context.l10n.settingsPhotoRemoveFailed,
      );
    }
  }

  /// REDESIGN (E2): a field changed – save after a short pause (typing) or
  /// right away (picks, switches).
  void _changed({bool now = false}) {
    _dirty = true;
    _pause?.cancel();
    if (now) {
      _autoSave();
    } else {
      _pause = Timer(const Duration(milliseconds: 900), _autoSave);
      setState(() {});
    }
  }

  /// One save at a time; a change during a save is saved right after it.
  Future<void> _autoSave() async {
    _pause?.cancel();
    if (!mounted || !_dirty) return;
    if (_saving) {
      _again = true;
      return;
    }
    _dirty = false;
    final ok = await _save(_visibleFields, quiet: true);
    if (!mounted) return;
    if (!ok) _dirty = true;
    if (_again) {
      _again = false;
      if (ok) await _autoSave();
    }
  }

  /// "Fertig": saves until nothing is open any more, then closes. Fields are
  /// locked meanwhile; a failed save keeps the sheet open.
  Future<void> _done() async {
    if (_closing) return;
    final navigator = Navigator.of(context);
    _pause?.cancel();
    _again = false;
    FocusScope.of(context).unfocus();
    setState(() => _closing = true);
    while (_saving || _dirty) {
      if (_saving) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (!mounted) return;
        continue;
      }
      _dirty = false;
      final ok = await _save(_visibleFields, quiet: true);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _dirty = true;
          _closing = false;
        });
        return;
      }
    }
    if (navigator.canPop()) navigator.pop();
  }

  Future<bool> _save(List<ProfileExtraField> visibleFields, {bool quiet = false}) async {
    final profile = _profile;
    if (profile == null) return false;
    // Take values of text-based extra fields from their controllers
    for (final field in visibleFields.where((f) => f.editableByPlayers)) {
      final controller = _fieldControllers[field.id];
      if (controller == null) continue;
      if (field.type == 'number') {
        _additional[field.id] = num.tryParse(controller.text.trim());
      } else {
        _additional[field.id] = controller.text;
      }
    }

    // Snapshot of the inputs: the fields stay editable while saving, so the
    // write and the next comparison base must use the same values (a church
    // changed meanwhile is not saved yet and must still be synced next time).
    final firstName = _firstName.text;
    final lastName = _lastName.text;
    final phone = _phone.text;
    final birthday = _birthday;
    final additional = Map<String, dynamic>.of(_additional);

    setState(() => _saving = true);
    final ok = await ref.read(profileNotifierProvider.notifier).saveMasterData(
          original: profile,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          birthday: birthday,
          additionalFields: additional,
          visibleFields: visibleFields,
        );
    if (!mounted) return ok;
    setState(() {
      _saving = false;
      if (ok) _saved = true;
    });
    if (ok) {
      // The saved values are the comparison base for the next save right
      // away; the reload of ownProfileProvider replaces it once it arrives.
      _profile = OwnProfile(
        person: profile.person.copyWith(
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          phone: phone.trim(),
          birthday: birthday,
        ),
        globalPersonId: profile.globalPersonId,
        organisationId: profile.organisationId,
        additionalFields: {...profile.additionalFields, ...additional},
      );
      // Ionic updateUserData: toast only, the sheet stays open. The Beta
      // shows "Gespeichert ✓" instead.
      if (!quiet) {
        ToastHelper.showSuccess(
            context, context.l10n.settingsProfileUpdated);
      }
    } else {
      ToastHelper.showError(context, context.l10n.dbUpdateProfileFailed);
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(ownProfileProvider);
    final fieldsAsync = ref.watch(personExtraFieldsProvider);
    final visibleFields = ref.watch(visibleProfileExtraFieldsProvider);
    final churches = ref.watch(churchesProvider).valueOrNull ?? const <Church>[];

    final profile = profileAsync.valueOrNull;
    if (!_initialized && profile != null && fieldsAsync.hasValue) {
      _init(profile, visibleFields);
    }
    // The sheet stays open after saving: the next save compares against the
    // freshly loaded profile (church/birthday change detection). Only a newly
    // loaded value replaces the base; the stale one still shown while
    // reloading must not overwrite the just-saved values.
    if (_initialized &&
        profile != null &&
        !_saving &&
        !identical(profile, _loadedProfile)) {
      _profile = profile;
      _loadedProfile = profile;
    }
    _visibleFields = visibleFields;
    return _buildView(context, profileAsync, profile, churches);
  }
}
