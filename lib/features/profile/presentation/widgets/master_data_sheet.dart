import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/church/church.dart';
import '../../../../data/repositories/profile_repository.dart';
import '../../../../shared/widgets/display/avatar.dart';
import '../../../../shared/widgets/sheets/image_viewer_sheet.dart';
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
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        AppActionSheetAction(
          value: 'replace',
          icon: Icons.photo_library_outlined,
          label: context.l10n.settingsReplacePhoto,
        ),
        if (hasImg) ...[
          AppActionSheetAction(
            value: 'view',
            icon: Icons.visibility_outlined,
            label: context.l10n.settingsViewPhoto,
          ),
          AppActionSheetAction(
            value: 'remove',
            icon: Icons.delete_outline,
            label: context.l10n.settingsRemovePhoto,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsMyData),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: !_initialized
          ? (profileAsync.hasError
              ? Center(child: Text(context.l10n.signoutFlutterError(friendlyErrorMessage(profileAsync.error))))
              : profileAsync.hasValue && profile == null
                  ? Center(child: Text(context.l10n.settingsFlutterNoProfile))
                  : const Center(child: AppSpinner()))
          : ListView(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(context.l10n.settingsPassPhoto),
                        trailing: Avatar(
                          imageUrl: hasCustomProfileImage(_img) ? _img : null,
                          firstName: _firstName.text,
                          lastName: _lastName.text,
                          size: 44,
                        ),
                        onTap: _changeImg,
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingM),
                        child: Column(
                          children: [
                            TextField(
                              controller: _firstName,
                              textCapitalization: TextCapitalization.words,
                              decoration:
                                  InputDecoration(labelText: context.l10n.peopleFirstName),
                            ),
                            const SizedBox(height: AppDimensions.paddingM),
                            TextField(
                              controller: _lastName,
                              textCapitalization: TextCapitalization.words,
                              decoration:
                                  InputDecoration(labelText: context.l10n.peopleLastName),
                            ),
                            const SizedBox(height: AppDimensions.paddingM),
                            TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                  labelText: context.l10n.settingsMobile),
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        title: Text(context.l10n.peopleBirthday),
                        trailing: TextButton(
                          onPressed: _pickBirthday,
                          child: Text(
                            (_birthday ?? '').isEmpty
                                ? context.l10n.orgChoose
                                : formatProfileDate(_birthday),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (visibleFields.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.paddingM),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingS,
                      vertical: AppDimensions.paddingXS,
                    ),
                    child: Text(
                      context.l10n.settingsExtraFields,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.medium,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final field in visibleFields)
                          _buildExtraField(field, churches),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.paddingL),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _save(visibleFields),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: AppSpinner(strokeWidth: 2),
                          )
                        : Text(context.l10n.commonSave),
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingL),
              ],
            ),
    );
  }

  Widget _buildExtraField(ProfileExtraField field, List<Church> churches) {
    if (!field.editableByPlayers) {
      return ListTile(
        title: Text(field.name),
        subtitle: Text(extraFieldDisplayValue(field, _additional, churches)),
      );
    }

    switch (field.type) {
      case 'boolean':
        return SwitchListTile.adaptive(
          title: Text(field.name),
          value: _additional[field.id] == true,
          onChanged: (v) => setState(() => _additional[field.id] = v),
        );
      case 'select':
        final current = _additional[field.id]?.toString();
        return ListTile(
          title: Text(field.name),
          trailing: DropdownButton<String>(
            value: field.options.contains(current) ? current : null,
            hint: Text(context.l10n.settingsPleaseSelect),
            items: field.options
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) => setState(() => _additional[field.id] = v),
          ),
        );
      case 'bfecg_church':
        return ListTile(
          title: Text(field.name),
          trailing: TextButton(
            onPressed: () => _selectChurch(field, churches),
            child: Text(_churchLabel(field, churches)),
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          child: TextField(
            controller: _controllerFor(field),
            keyboardType: field.type == 'number'
                ? TextInputType.number
                : TextInputType.text,
            maxLines: field.type == 'textarea' ? 3 : 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: field.name),
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
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _ChurchPicker(
          title: field.name,
          churches: churches,
          selectedId: _additional[field.id]?.toString(),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _additional[field.id] = selected);
    }
  }
}

/// Searchable church picker (Ionic church modal in settings)
class _ChurchPicker extends StatefulWidget {
  const _ChurchPicker({
    required this.title,
    required this.churches,
    this.selectedId,
  });

  final String title;
  final List<Church> churches;
  final String? selectedId;

  @override
  State<_ChurchPicker> createState() => _ChurchPickerState();
}

class _ChurchPickerState extends State<_ChurchPicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final term = _search.trim().toLowerCase();
    final filtered = term.isEmpty
        ? widget.churches
        : widget.churches
            .where((c) => c.name.toLowerCase().contains(term))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: TextField(
              decoration: InputDecoration(
                hintText: context.l10n.settingsSearchChurch,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  title: Text(context.l10n.settingsNotListed),
                  trailing: widget.selectedId == ''
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(''),
                ),
                for (final church in filtered)
                  ListTile(
                    title: Text(church.name),
                    trailing: widget.selectedId == church.id
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(church.id),
                  ),
                if (filtered.isEmpty)
                  ListTile(
                    title: Text(
                      context.l10n.settingsNoChurch,
                      style: const TextStyle(color: AppColors.medium),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
