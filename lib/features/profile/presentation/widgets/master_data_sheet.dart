import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/profile_providers.dart';
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
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Opens the "Meine Stammdaten" sheet (Ionic settings master data modal).
Future<void> showMasterDataSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.9,
      child: MasterDataSheet(),
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
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
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
          icon: Icons.photo_library_outlined,
        ),
        if (hasImg) ...[
          AppActionSheetAction(
            value: 'view',
            label: context.l10n.settingsViewPhoto,
            icon: Icons.visibility_outlined,
          ),
          AppActionSheetAction(
            value: 'remove',
            label: context.l10n.settingsRemovePhoto,
            icon: Icons.delete_outline,
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
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
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

  Future<void> _save(List<ProfileExtraField> visibleFields) async {
    final profile = _profile;
    if (profile == null) return;
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

    setState(() => _saving = true);
    final ok = await ref.read(profileNotifierProvider.notifier).saveMasterData(
          original: profile,
          firstName: _firstName.text,
          lastName: _lastName.text,
          phone: _phone.text,
          birthday: _birthday,
          additionalFields: _additional,
          visibleFields: visibleFields,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ToastHelper.showSuccess(
          context, context.l10n.settingsProfileUpdated);
      Navigator.of(context).pop();
    } else {
      ToastHelper.showError(context, context.l10n.dbUpdateProfileFailed);
    }
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
    final inputStyle = ionItemInputStyle(context);

    // Ionic master data modal: sheet (breakpoint .9) with a plain toolbar
    // title "Meine Stammdaten" (no close button, swipe/backdrop closes) and
    // an inset list on the light background; "Speichern" is the last item.
    return Scaffold(
      appBar: AppBar(
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
                    IonInputItem(
                      child: TextField(
                        controller: _firstName,
                        style: inputStyle,
                        textCapitalization: TextCapitalization.words,
                        decoration: ionItemInputDecoration(
                            context, context.l10n.peopleFirstName),
                      ),
                    ),
                    IonInputItem(
                      child: TextField(
                        controller: _lastName,
                        style: inputStyle,
                        textCapitalization: TextCapitalization.words,
                        decoration: ionItemInputDecoration(
                            context, context.l10n.peopleLastName),
                      ),
                    ),
                    IonInputItem(
                      child: TextField(
                        controller: _phone,
                        style: inputStyle,
                        keyboardType: TextInputType.phone,
                        decoration: ionItemInputDecoration(
                            context, context.l10n.settingsMobile),
                      ),
                    ),
                    IonItem(
                      label: context.l10n.peopleBirthday,
                      end: IonDateButton(
                        onTap: _pickBirthday,
                        text: (_birthday ?? '').isEmpty
                            ? context.l10n.orgChoose
                            : formatProfileDate(_birthday),
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
            child: Text(_churchLabel(field, churches)),
          ),
        );
      default:
        return IonInputItem(
          child: TextField(
            controller: _controllerFor(field),
            style: ionItemInputStyle(context),
            keyboardType: field.type == 'number'
                ? TextInputType.number
                : TextInputType.text,
            maxLines: field.type == 'textarea' ? 3 : 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: ionItemInputDecoration(context, field.name),
          ),
        );
    }
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
