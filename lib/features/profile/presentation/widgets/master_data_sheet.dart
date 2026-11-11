import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart';
import '../../../redesign/presentation/widgets/members/rd_person_form.dart' show RdPersonAvatar;
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/repositories/profile_repository.dart';
import '../../../../shared/widgets/display/avatar.dart';
import '../../../../shared/widgets/sheets/image_viewer_sheet.dart';
import '../../../auth/presentation/widgets/ion_form_list.dart';
import 'church_picker.dart';
import 'profile_helpers.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/layout/ion_modal_handle.dart';

/// Opens the "Meine Stammdaten" sheet (Ionic settings master data modal).
///
/// Ionic: `ion-modal [breakpoints]="[0, .9]"` – on iOS a sheet with the
/// grabber drawn over the toolbar (IOS_FORMS1).
Future<void> showMasterDataSheet(BuildContext context) {
  // REDESIGN (E2): Beta edit page as a high sheet that saves right away.
  if (ProviderScope.containerOf(context, listen: false).read(redesignEnabledProvider)) {
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
        child: const MasterDataSheet(beta: true),
      ),
    );
  }
  final ios = useIosLook(context);
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: ios ? Theme.of(context).scaffoldBackgroundColor : null,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: ios
          ? const IonModalHandleOverlay(child: MasterDataSheet())
          : const MasterDataSheet(),
    ),
  );
}

/// Edit own master data: Passbild, name, phone, birthday, extra fields.
class MasterDataSheet extends ConsumerStatefulWidget {
  const MasterDataSheet({super.key, this.beta = false});

  /// Beta look: no "Speichern" button, every change is saved on its own
  /// (text after a short pause, picks right away), "Fertig" closes.
  final bool beta;

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
      if (widget.beta) _changed(now: true);
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
    if (widget.beta) return _buildBeta(context, profileAsync, profile, churches);
    final inputStyle = ionItemInputStyle(context);

    // Ionic master data modal: sheet (breakpoint .9) with a plain toolbar
    // title "Meine Stammdaten" (no close button, swipe/backdrop closes) and
    // an inset list on the light background; "Speichern" is the last item.
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: ionModalToolbarHeight(context),
        title: Text(context.l10n.settingsMyData),
        automaticallyImplyLeading: false,
      ),
      body: !_initialized
          ? (profileAsync.hasError
              ? Center(child: Text(context.l10n.signoutFlutterError(friendlyErrorMessage(profileAsync.error))))
              : profileAsync.hasValue && profile == null
                  ? Center(child: Text(context.l10n.settingsFlutterNoProfile))
                  : const Center(child: AppSpinner()))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                IonInsetGroup(
                  children: [
                    IonItem(
                      label: context.l10n.settingsPassPhoto,
                      onTap: _changeImg,
                      detail: true,
                      end: Avatar(
                        imageUrl: hasCustomProfileImage(_img) ? _img : null,
                        firstName: _firstName.text,
                        lastName: _lastName.text,
                        size: 40,
                      ),
                    ),
                    _stackedInput(
                      label: context.l10n.peopleFirstName,
                      controller: _firstName,
                      style: inputStyle,
                      textCapitalization: TextCapitalization.words,
                    ),
                    _stackedInput(
                      label: context.l10n.peopleLastName,
                      controller: _lastName,
                      style: inputStyle,
                      textCapitalization: TextCapitalization.words,
                    ),
                    _stackedInput(
                      label: context.l10n.settingsMobile,
                      controller: _phone,
                      style: inputStyle,
                      keyboardType: TextInputType.phone,
                    ),
                    IonItem(
                      label: context.l10n.peopleBirthday,
                      end: IonDateButton(
                        onTap: _pickBirthday,
                        // Ionic ion-datetime-button: "16. Feb. 2002"
                        text: (_birthday ?? '').isEmpty
                            ? context.l10n.orgChoose
                            : formatIonDateButton(_birthday),
                      ),
                    ),
                  ],
                ),
                if (visibleFields.isNotEmpty) ...[
                  IonListHeader(context.l10n.settingsExtraFields),
                  IonInsetGroup(
                    children: [
                      for (final field in visibleFields)
                        _buildExtraField(field, churches),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                IonInsetGroup(
                  children: [
                    IonButtonItem(
                      label: context.l10n.commonSave,
                      onTap: _saving ? null : () => _save(visibleFields),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  /// REDESIGN (E2): "Meine Stammdaten" edit page – Passbild on top, fields
  /// in cards, saves on its own ("Gespeichert ✓"), "Fertig" closes.
  Widget _buildBeta(
    BuildContext context,
    AsyncValue<OwnProfile?> profileAsync,
    OwnProfile? profile,
    List<Church> churches,
  ) {
    final p = context.rd;
    final l10n = context.l10n;
    Widget text(String label, TextEditingController c,
            {TextInputType? keyboard, TextCapitalization caps = TextCapitalization.none, int lines = 1, String hint = ''}) =>
        RdFieldRow(
          label: label,
          child: TextField(
            controller: c,
            keyboardType: keyboard,
            textCapitalization: caps,
            minLines: 1,
            maxLines: lines,
            style: TextStyle(fontSize: 17, color: p.text),
            decoration: rdInputDecoration(p, hint),
            onChanged: (_) => _changed(),
          ),
        );
    final Widget body;
    if (!_initialized) {
      body = SizedBox(
        height: 200,
        child: Center(
          child: profileAsync.hasError
              ? Text(l10n.signoutFlutterError(friendlyErrorMessage(profileAsync.error)), style: RdType.body(p))
              : profileAsync.hasValue && profile == null
                  ? Text(l10n.settingsFlutterNoProfile, style: RdType.body(p))
                  : const AppSpinner(),
        ),
      );
    } else {
      body = RdFormBody(
        shrinkWrap: true,
        children: [
          const SizedBox(height: 8),
          // Name card like "Neue Person": Passbild (initials + camera
          // badge) beside Vorname/Nachname.
          RdCard(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: RdPersonAvatar(
                    name: '${_firstName.text} ${_lastName.text}',
                    imageUrl: hasCustomProfileImage(_img) ? _img : null,
                    onTap: _changeImg,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      text(l10n.peopleFirstName, _firstName, caps: TextCapitalization.words),
                      Divider(height: 1, thickness: 1, color: p.line),
                      text(l10n.peopleLastName, _lastName, caps: TextCapitalization.words),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          RdGroupLabel(l10n.redesignPersonFormContact),
          RdGroupedList(
            children: [
              text(l10n.settingsMobile, _phone, keyboard: TextInputType.phone, hint: '+49 123 456789'),
            ],
          ),
          const SizedBox(height: 20),
          RdGroupedList(
            children: [
              RdListRow(
                title: l10n.peopleBirthday,
                value: (_birthday ?? '').isEmpty ? l10n.orgChoose : formatIonDateButton(_birthday),
                onTap: _pickBirthday,
              ),
            ],
          ),
          if (_visibleFields.isNotEmpty) ...[
            const SizedBox(height: 20),
            RdGroupLabel(l10n.settingsExtraFields),
            RdGroupedList(
              children: [
                for (final field in _visibleFields) _buildBetaExtraField(field, churches, text),
              ],
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
              _saving
                  ? l10n.redesignMeSaving
                  : _dirty
                      ? ''
                      : _saved
                          ? l10n.redesignMeSaved
                          : l10n.redesignMeSavesItself,
              style: RdType.meta(p, size: 13),
            ),
          ),
        ],
      );
    }
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Padding(
        // Keep the lower fields above the keyboard.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RdFormTopBar(
              title: l10n.settingsMyData,
              cancel: '',
              submit: l10n.redesignCommonDone,
              saving: _closing,
              onCancel: null,
              onSubmit: _done,
            ),
            Flexible(child: IgnorePointer(ignoring: _closing, child: body)),
          ],
        ),
      ),
    );
  }

  Widget _buildBetaExtraField(
    ProfileExtraField field,
    List<Church> churches,
    Widget Function(String label, TextEditingController c,
            {TextInputType? keyboard, TextCapitalization caps, int lines, String hint})
        text,
  ) {
    final p = context.rd;
    if (!field.editableByPlayers) {
      return RdListRow(
        title: field.name,
        subtitle: extraFieldDisplayValue(field, _additional, churches),
        showChevron: false,
      );
    }
    switch (field.type) {
      case 'boolean':
        return RdListRow(
          title: field.name,
          showChevron: false,
          trailing: Switch.adaptive(
            value: _additional[field.id] == true,
            activeTrackColor: p.primary,
            onChanged: (v) {
              setState(() => _additional[field.id] = v);
              _changed(now: true);
            },
          ),
        );
      case 'select':
        final current = _additional[field.id]?.toString();
        final valid = field.options.contains(current);
        return RdListRow(
          title: field.name,
          value: valid ? current! : context.l10n.settingsPleaseSelect,
          onTap: () async {
            final value = await showIonSelectOptions<String>(
              context,
              title: field.name,
              options: [for (final o in field.options) (o, o)],
              selected: valid ? current : null,
            );
            if (value != null && mounted) {
              setState(() => _additional[field.id] = value);
              _changed(now: true);
            }
          },
        );
      case 'bfecg_church':
        return RdListRow(
          title: field.name,
          value: _churchLabel(field, churches),
          onTap: () async {
            final before = _additional[field.id];
            await _selectChurch(field, churches);
            if (mounted && _additional[field.id] != before) _changed(now: true);
          },
        );
      default:
        return text(
          field.name,
          _controllerFor(field),
          keyboard: field.type == 'number' ? TextInputType.number : TextInputType.text,
          caps: TextCapitalization.sentences,
          lines: field.type == 'textarea' ? 4 : 1,
        );
    }
  }

  Widget _buildExtraField(ProfileExtraField field, List<Church> churches) {
    if (!field.editableByPlayers) {
      // ion-label h3 name + p value
      return IonItem(
        title: Text(field.name, style: const TextStyle(fontSize: 14)),
        subtitle: Text(extraFieldDisplayValue(field, _additional, churches)),
      );
    }

    switch (field.type) {
      case 'boolean':
        return IonItem(
          label: field.name,
          end: Switch.adaptive(
            value: _additional[field.id] == true,
            onChanged: (v) => setState(() => _additional[field.id] = v),
          ),
        );
      case 'select':
        final current = _additional[field.id]?.toString();
        final valid = field.options.contains(current);
        return IonItem(
          label: field.name,
          onTap: () async {
            final value = await showIonSelectOptions<String>(
              context,
              title: field.name,
              options: [for (final o in field.options) (o, o)],
              selected: valid ? current : null,
            );
            if (value != null && mounted) {
              setState(() => _additional[field.id] = value);
            }
          },
          end: IonSelectValue(
            text: valid ? current! : context.l10n.settingsPleaseSelect,
            placeholder: !valid,
          ),
        );
      case 'bfecg_church':
        return IonItem(
          label: field.name,
          end: TextButton(
            onPressed: () => _selectChurch(field, churches),
            child: IonButtonLabel(_churchLabel(field, churches)),
          ),
        );
      default:
        // Ionic `ion-input labelPlacement="stacked"`: the label is scaled
        // to .75 of the item font (legacy `ion-label` keeps the full size).
        return _stackedInput(
          label: field.name,
          controller: _controllerFor(field),
          style: ionItemInputStyle(context),
          keyboardType: field.type == 'number'
              ? TextInputType.number
              : TextInputType.text,
          maxLines: field.type == 'textarea' ? 3 : 1,
          textCapitalization: TextCapitalization.sentences,
          iosLabelScale: 0.75,
        );
    }
  }

  /// `ion-item` with a stacked label above an `ion-input`.
  ///
  /// iOS (IOS_FORMS1): label row (17pt, 10pt from the top, 4pt gap) above a
  /// 44pt input row – two ≈40pt rows like the Ionic iOS item
  /// (`item-label-stacked`, min-height 68). Material keeps the floating
  /// label decoration.
  Widget _stackedInput({
    required String label,
    required TextEditingController controller,
    required TextStyle style,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    double iosLabelScale = 1,
  }) {
    if (!useIosLook(context)) {
      return IonInputItem(
        child: TextField(
          controller: controller,
          style: style,
          keyboardType: keyboardType,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          decoration: ionItemInputDecoration(context, label),
        ),
      );
    }
    final fontSize = ionItemFontSize(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize * iosLabelScale,
              height: 20.33 / 17,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: TextField(
              controller: controller,
              style: style.copyWith(height: 20.33 / 17),
              keyboardType: keyboardType,
              maxLines: maxLines,
              textCapitalization: textCapitalization,
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _churchLabel(ProfileExtraField field, List<Church> churches) {
    final value = _additional[field.id];
    if (value == null) return context.l10n.settingsPleaseSelect;
    if (value == '') return context.l10n.settingsNotListed;
    return churches.where((c) => c.id == value).firstOrNull?.name ??
        context.l10n.settingsPleaseSelect;
  }

  Future<void> _selectChurch(
    ProfileExtraField field,
    List<Church> churches,
  ) async {
    final selected = await showChurchPicker(
      context,
      title: field.name,
      churches: churches,
      selectedId: _additional[field.id]?.toString(),
      searchHint: context.l10n.settingsSearchChurch,
      notListedLabel: context.l10n.settingsNotListed,
      noChurchLabel: context.l10n.settingsNoChurch,
    );
    if (selected != null && mounted) {
      setState(() => _additional[field.id] = selected);
    }
  }
}
