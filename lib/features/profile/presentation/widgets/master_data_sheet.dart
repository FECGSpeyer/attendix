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
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('de', 'DE'),
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
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Passbild ersetzen'),
              onTap: () => Navigator.pop(sheetContext, 'replace'),
            ),
            if (hasImg) ...[
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Passbild ansehen'),
                onTap: () => Navigator.pop(sheetContext, 'view'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text(
                  'Passbild entfernen',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Abbrechen'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
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
        ToastHelper.showError(context, 'Das Bild darf maximal 2MB groß sein.');
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
        ToastHelper.showSuccess(context, 'Das Passbild wurde erfolgreich geändert.');
      } else {
        ToastHelper.showError(
          context,
          'Fehler beim ändern des Passbildes, versuche es später erneut',
        );
      }
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(
          context,
          'Fehler beim ändern des Passbildes, versuche es später erneut',
        );
      }
    }
  }

  Future<void> _removeImg() async {
    final img = _img;
    if (img == null) return;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Passbild entfernen',
      message: 'Möchtest du dein Passbild wirklich entfernen?',
      confirmText: 'Entfernen',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref.read(profileNotifierProvider.notifier).removeImage(img);
    if (!mounted) return;
    if (ok) {
      setState(() => _img = '');
      ToastHelper.showSuccess(context, 'Das Passbild wurde erfolgreich entfernt');
    } else {
      ToastHelper.showError(
        context,
        'Fehler beim Entfernen des Passbildes, versuche es später erneut',
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
          context, 'Die Profildaten wurden erfolgreich aktualisiert.');
      Navigator.of(context).pop();
    } else {
      ToastHelper.showError(context, 'Fehler beim Aktualisieren des Profils');
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
        title: const Text('Meine Stammdaten'),
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
              ? Center(child: Text('Fehler: ${profileAsync.error}'))
              : profileAsync.hasValue && profile == null
                  ? const Center(child: Text('Kein Profil gefunden'))
                  : const Center(child: CircularProgressIndicator()))
          : ListView(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Passbild'),
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
                                  const InputDecoration(labelText: 'Vorname'),
                            ),
                            const SizedBox(height: AppDimensions.paddingM),
                            TextField(
                              controller: _lastName,
                              textCapitalization: TextCapitalization.words,
                              decoration:
                                  const InputDecoration(labelText: 'Nachname'),
                            ),
                            const SizedBox(height: AppDimensions.paddingM),
                            TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                  labelText: 'Handynummer'),
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        title: const Text('Geburtsdatum'),
                        trailing: TextButton(
                          onPressed: _pickBirthday,
                          child: Text(
                            (_birthday ?? '').isEmpty
                                ? 'Auswählen'
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
                      'Zusatzfelder',
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Speichern'),
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
        return SwitchListTile(
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
            hint: const Text('Bitte auswählen'),
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
    if (value == null) return 'Bitte auswählen';
    if (value == '') return 'Nicht gelistet';
    return churches.where((c) => c.id == value).firstOrNull?.name ??
        'Bitte auswählen';
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
            child: const Text('Schließen'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Gemeinde suchen',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  title: const Text('Nicht gelistet'),
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
                  const ListTile(
                    title: Text(
                      'Keine Gemeinde gefunden.',
                      style: TextStyle(color: AppColors.medium),
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
