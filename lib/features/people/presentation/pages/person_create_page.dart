import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/tenant_label_utils.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/cross_tenant_person_providers.dart';
import '../../../../core/utils/person_matcher.dart';
import '../../../../data/repositories/cross_tenant_person_repository.dart';
import '../widgets/person_match_suggestions.dart';
import '../widgets/person_image_picker.dart'; // ASTRA_PHOTO
import '../../../../core/providers/church_providers.dart';
import '../../../../core/providers/parent_providers.dart';
import '../../../../core/providers/shift_providers.dart';
import '../../../../core/providers/teacher_providers.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../widgets/church_picker_sheet.dart';
import '../widgets/person_detail/allgemein_accordion.dart'
    show otherOrchestraOptions, personExtraFields;
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/ion/ion_widgets.dart'; // UX_PEOPLE
import '../../../../core/utils/error_message.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Page for creating a new person
class PersonCreatePage extends ConsumerStatefulWidget {
  const PersonCreatePage({super.key});

  @override
  ConsumerState<PersonCreatePage> createState() => _PersonCreatePageState();
}

class _PersonCreatePageState extends ConsumerState<PersonCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  int? _selectedInstrument;
  DateTime? _birthday;
  bool _isLoading = false;
  final Map<String, dynamic> _additionalFieldValues = {};
  bool _extraFieldsInitialized = false;

  // Cross-tenant person matching (Ionic person.page onNameInput/onEmailBlur)
  final _emailFocus = FocusNode();
  Timer? _nameDebounce;
  int _nameLookupSeq = 0;
  String? _dismissedFor;
  String _lastEmailLookup = '';
  List<RankedMatch<CrossTenantPersonCandidate>> _nameSuggestions = const [];

  /// Data adopted from a matched person that has no form field here
  String? _adoptedImg;

  /// ASTRA_PHOTO: Passbild picked while creating (Ionic keeps it as a data
  /// URL in player.img and uploads it after the insert).
  Uint8List? _pickedImage;

  // PEOPLE2: full create form like Ionic person.page (create mode)
  final _rangeController = TextEditingController();
  final _instrumentsController = TextEditingController();
  final _testResultController = TextEditingController();
  final _otherExerciseController = TextEditingController();
  DateTime? _playsSince;
  DateTime _joined = DateTime.now();
  bool _hasTeacher = false;
  int? _teacherId;
  bool _isLeader = false;
  int? _parentId;
  bool _examinee = false;
  List<String> _otherOrchestras = [];
  String? _shiftId;
  String? _shiftName;
  DateTime? _shiftStart;

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onNameInput);
    _lastNameController.addListener(_onNameInput);
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _onEmailBlur();
    });
  }

  /// Ionic person.page `hasChanges` for a new person: something was entered.
  bool get _hasInput =>
      _pickedImage != null ||
      [
        _firstNameController,
        _lastNameController,
        _emailController,
        _phoneController,
        _notesController,
        _rangeController,
        _instrumentsController,
        _testResultController,
        _otherExerciseController,
      ].any((c) => c.text.trim().isNotEmpty);

  /// Ionic dismiss(): with changes ask "Änderungen verwerfen?" first.
  Future<void> _close() async {
    if (_hasInput) {
      final discard = await showAppDialog<bool>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: Text(ctx.l10n.personDiscardChanges),
          content: Text(ctx.l10n.personDiscardChangesMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.commonYes),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) context.pop();
  }

  String get _nameKey =>
      '${_firstNameController.text.trim()}|${_lastNameController.text.trim()}';

  void _onNameInput() {
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 250), _lookupByName);
  }

  Future<void> _lookupByName() async {
    if (!mounted) return;
    final crossTenantPersonRepo = ref.read(crossTenantPersonRepositoryWithTenantProvider);
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (first.length < 2 && last.length < 2) {
      if (_nameSuggestions.isNotEmpty) setState(() => _nameSuggestions = const []);
      return;
    }
    if (_dismissedFor == _nameKey) return;
    _dismissedFor = null;

    final mySeq = ++_nameLookupSeq;
    try {
      final linkedIds = await ref.read(linkedTenantIdsProvider.future);
      if (linkedIds.isEmpty) return;
      final matches = await crossTenantPersonRepo
          .getPossiblePersonsByName(first, last, linkedTenantIds: linkedIds);
      if (!mounted || mySeq != _nameLookupSeq) return; // stale
      setState(() => _nameSuggestions = matches);
    } catch (_) {
      // Silent — suggestions are optional
    }
  }

  void _dismissNameSuggestions() {
    setState(() {
      _dismissedFor = _nameKey;
      _nameSuggestions = const [];
    });
  }

  Future<void> _onEmailBlur() async {
    if (!mounted) return;
    final crossTenantPersonRepo = ref.read(crossTenantPersonRepositoryWithTenantProvider);
    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w-\.+]+@([\w-]+\.)+[\w-]{2,}$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) return;
    if (email == _lastEmailLookup) return;
    _lastEmailLookup = email;

    List<CrossTenantPersonCandidate> matches;
    try {
      final linkedIds = await ref.read(linkedTenantIdsProvider.future);
      matches = await crossTenantPersonRepo
          .getPossiblePersonsByEmail(email, linkedTenantIds: linkedIds);
    } catch (_) {
      return;
    }
    if (matches.isEmpty || !mounted) return;

    final chosen = await showEmailTakenDialog(context, matches);
    if (chosen != null && mounted) _applyMatchedPerson(chosen);
  }

  /// Adopt data from a matched cross-tenant person (Ionic applyMatchedPerson)
  void _applyMatchedPerson(CrossTenantPersonCandidate match) {
    final p = match.person;
    final groups = ref.read(groupsProvider).valueOrNull ?? const [];
    final group = groups.where((g) => g.name == match.groupName).firstOrNull;
    _nameDebounce?.cancel();
    setState(() {
      _firstNameController.text = p.firstName;
      _lastNameController.text = p.lastName;
      _emailController.text = p.email ?? '';
      _lastEmailLookup = _emailController.text.trim();
      if (p.correctBirthday && p.birthday != null) {
        _birthday = DateTime.tryParse(p.birthday!);
      }
      _adoptedImg = p.img;
      _otherExerciseController.text = p.otherExercise ?? '';
      _rangeController.text = p.range ?? '';
      if (group != null) _selectedInstrument = group.id;
      _nameSuggestions = const [];
      _dismissedFor = _nameKey;
    });
    _nameDebounce?.cancel();
    ToastHelper.showSuccess(context, context.l10n.personDataTaken);
  }

  /// Returns the default value for a field type (like Utils.getFieldTypeDefaultValue in Ionic)
  /// For NEW person: defaultValue is NOT used (only type-based defaults)
  /// For EXISTING person: defaultValue IS used if provided
  dynamic _getFieldTypeDefaultValue(String fieldType, {dynamic defaultValue, List<String>? options}) {
    // 1. If explicit defaultValue is provided, use it
    if (defaultValue != null) {
      return defaultValue;
    }

    // 2. SELECT → first option
    if (fieldType == 'select') {
      return (options?.isNotEmpty ?? false) ? options!.first : '';
    }

    // 3. Type-based defaults (matching Ionic behavior)
    switch (fieldType) {
      case 'text':
      case 'textarea':
        return '';
      case 'number':
        return 0;
      case 'date':
        return DateTime.now().toIso8601String().split('T')[0];
      case 'boolean':
        return true; // Ionic uses TRUE as default!
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _emailFocus.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _rangeController.dispose();
    _instrumentsController.dispose();
    _testResultController.dispose();
    _otherExerciseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final instrumentsAsync = ref.watch(groupsProvider);
    final tenant = ref.watch(currentTenantProvider);
    final extraFields = personExtraFields(ref, tenant);

    // Initialize additional_fields with defaults (like Ionic lines 166-174)
    // For NEW person: use type-based defaults only (NO field.defaultValue)
    if (!_extraFieldsInitialized && extraFields.isNotEmpty) {
      for (final field in extraFields) {
        _additionalFieldValues[field.id] ??= _getFieldTypeDefaultValue(
          field.type,
          options: field.options,
          // NOTE: NOT passing field.defaultValue for new person (matches Ionic!)
        );
      }
      _extraFieldsInitialized = true;
    }

    final ios = ionIsIos(context);
    final gap = SizedBox(height: ios ? 0 : AppDimensions.paddingM);

    return Scaffold(
      // Ionic person.page (create): title "Person hinzufügen", close button
      // at the end, save via the person-add FAB. UX_PEOPLE: modalBackground.
      backgroundColor: ionContentBackground(context),
      appBar: AppBar(
        title: Text(context.l10n.attendanceAddPerson),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: context.l10n.commonClose,
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
        ],
      ),
      // IOS_SHELL2: iOS → ion-fab in the tab bar row
      floatingActionButton: TabBarFab(
        child: IonFabButton(
          key: const Key('person_create_save'),
          tooltip: context.l10n.commonSave,
          onPressed: _isLoading ? null : _save,
          icon: Icons.person_add_alt_1_outlined,
        ),
      ),
      body: Form(
        key: _formKey,
        child: IonFormTheme(
          child: ListView(
          padding: ios
              ? EdgeInsets.fromLTRB(
                  16, 0, 0, scrollEndPadding(context, base: 16, fabRoom: 80))
              : EdgeInsets.fromLTRB(AppDimensions.paddingM,
                  AppDimensions.paddingM, AppDimensions.paddingM,
                  scrollEndPadding(context, base: 16, fabRoom: 80)),
          children: [
            // Ionic .profile-header: placeholder avatar + typed name
            _CreateProfileHeader(
              firstName: _firstNameController,
              lastName: _lastNameController,
              imageBytes: _pickedImage,
              imageUrl: _adoptedImg,
              onTap: _onProfileImageTap,
            ),

            // First Name
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: '${context.l10n.peopleFirstName} *',
                hintText: 'Max',
                prefixIcon: ionIsIos(context) ? null : const Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.peopleFlutterFirstNameRequired;
                }
                return null;
              },
              autofocus: true,
            ),
            gap,

            // Last Name
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: '${context.l10n.peopleLastName} *',
                hintText: 'Mustermann',
                prefixIcon: ionIsIos(context) ? null : const Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.peopleFlutterLastNameRequired;
                }
                return null;
              },
            ),
            gap,

            // Cross-tenant name suggestions
            if (_nameSuggestions.isNotEmpty) ...[
              PersonMatchSuggestions(
                matches: _nameSuggestions,
                onSelected: _applyMatchedPerson,
                onDismiss: _dismissNameSuggestions,
              ),
              gap,
            ],

            // Instrument Dropdown
            instrumentsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e))),
              data: (instruments) {
                final label = groupLabel(tenant?.type);
                return AppDropdownFormField<int>(
                  iosInterface: AppSelectInterface.alert, // IOS_THEME2
                value: _selectedInstrument,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: ionIsIos(context) ? null : const Icon(Icons.music_note),
                ),
                items: [
                  DropdownMenuItem<int>(
                    value: null,
                    child: Text(context.l10n.personFlutterNoneLabelMasc(label)),
                  ),
                  ...instruments.map((i) => DropdownMenuItem<int>(
                    value: i.id,
                    child: Text(i.name),
                  )),
                ],
                onChanged: (value) => setState(() => _selectedInstrument = value),
              );
              },
            ),
            gap,

            // Birthday
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ionIsIos(context) ? null : const Icon(Icons.cake),
              title: Text(context.l10n.peopleBirthday),
              subtitle: Text(
                _birthday != null
                    ? DateFormat(dateFmt()).format(_birthday!)
                    : context.l10n.personFlutterNotSpecified,
                style: TextStyle(
                  color: _birthday != null ? null : AppColors.medium,
                ),
              ),
              trailing: _birthday != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _birthday = null),
                    )
                  : null,
              onTap: _pickBirthday,
            ),
            if (!ios) const Divider(),

            // Email
            TextFormField(
              controller: _emailController,
              focusNode: _emailFocus,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.l10n.peopleFlutterOptional(context.l10n.peopleEmail),
                hintText: 'max@example.com',
                prefixIcon: ionIsIos(context) ? null : const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value)) {
                    return context.l10n.registerModalInvalidEmail;
                  }
                }
                return null;
              },
            ),
            gap,

            // Phone
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: context.l10n.peopleFlutterOptional(context.l10n.peoplePhone),
                hintText: '+49 123 456789',
                prefixIcon: ionIsIos(context) ? null : const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            gap,

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: context.l10n.peopleFlutterOptional(context.l10n.peopleNotes),
                hintText: context.l10n.peopleFlutterNotesHint,
                prefixIcon: ionIsIos(context) ? null : const Icon(Icons.note),
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
            ),

            ..._buildIonicFields(tenant),

            // Account help (Ionic person.accountHelp / existingUserHint)
            Padding(
              padding: EdgeInsets.only(top: AppDimensions.paddingM),
              child: Text(
                '${context.l10n.personAccountHelp}\n${context.l10n.personExistingUserHint}',
                style: TextStyle(fontSize: 12, color: AppColors.medium),
              ),
            ),

            // Extra Fields Section - as ExpansionTile like Ionic Accordion
            if (extraFields.isNotEmpty)
              ExpansionTile(
                title: Text(context.l10n.peopleExtraFields),
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                children: extraFields.map((field) => _buildExtraFieldInput(field)).toList(),
              ),

            const SizedBox(height: AppDimensions.paddingL),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildExtraFieldInput(ExtraField field) {
    switch (field.type) {
      case 'text':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextFormField(
            decoration: InputDecoration(labelText: field.name),
            textCapitalization: TextCapitalization.sentences,
            initialValue: _additionalFieldValues[field.id]?.toString() ?? '',
            onChanged: (value) => _additionalFieldValues[field.id] = value,
          ),
        );

      case 'textarea':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextFormField(
            decoration: InputDecoration(
              labelText: field.name,
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            initialValue: _additionalFieldValues[field.id]?.toString() ?? '',
            onChanged: (value) => _additionalFieldValues[field.id] = value,
          ),
        );

      case 'number':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextFormField(
            decoration: InputDecoration(labelText: field.name),
            keyboardType: TextInputType.number,
            initialValue: _additionalFieldValues[field.id]?.toString() ?? '0',
            onChanged: (value) => _additionalFieldValues[field.id] = int.tryParse(value) ?? 0,
          ),
        );

      case 'boolean':
        return SwitchListTile.adaptive(
          title: Text(field.name),
          value: _additionalFieldValues[field.id] as bool? ?? true,
          onChanged: (value) => setState(() => _additionalFieldValues[field.id] = value),
        );

      case 'date':
        final currentValue = _additionalFieldValues[field.id]?.toString();
        final currentDate = currentValue != null ? DateTime.tryParse(currentValue) : null;
        return ListTile(
          title: Text(field.name),
          subtitle: Text(
            currentDate != null
                ? DateFormat(dateFmt()).format(currentDate)
                : context.l10n.personFlutterNotSpecified,
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final date = await showAppDatePicker(
              context: context,
              initialDate: currentDate ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              setState(() => _additionalFieldValues[field.id] = date.toIso8601String().split('T')[0]);
            }
          },
        );

      case 'bfecg_church':
        final churches = ref.watch(churchesProvider).valueOrNull ?? const [];
        return ListTile(
          title: Text(field.name),
          trailing: TextButton(
            onPressed: () async {
              final selected = await showChurchPickerSheet(
                context,
                title: field.name,
                churches: churches,
                selectedId: _additionalFieldValues[field.id]?.toString(),
              );
              if (selected != null) {
                setState(() => _additionalFieldValues[field.id] = selected);
              }
            },
            child: IonButtonLabel(churchLabel(_additionalFieldValues[field.id], churches)),
          ),
        );

      case 'select':
        final options = field.options ?? [];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: AppDropdownFormField<String>(
            iosInterface: AppSelectInterface.alert, // IOS_THEME2
            decoration: InputDecoration(labelText: field.name),
            value: _additionalFieldValues[field.id]?.toString(),
            items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
            onChanged: (value) => setState(() => _additionalFieldValues[field.id] = value),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String? _textOrNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  bool get _isMainGroup {
    final main = ref.read(mainGroupProvider).valueOrNull;
    return main?.id != null && main!.id == _selectedInstrument;
  }

  Widget _dateTile({
    required IconData icon,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    bool clearable = true,
    DateTime? lastDate,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ionIsIos(context) ? null : Icon(icon),
      title: Text(label),
      subtitle: Text(
        value != null ? DateFormat(dateFmt()).format(value) : context.l10n.personFlutterNotSpecified,
        style: TextStyle(color: value != null ? null : AppColors.medium),
      ),
      trailing: clearable && value != null
          ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => onChanged(null),
            )
          : null,
      onTap: () async {
        final picked = await showAppDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: lastDate ?? DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }

  /// Fields Ionic person.page shows when adding a person.
  List<Widget> _buildIonicFields(Tenant? tenant) {
    final isGeneral = tenant?.type == 'general';
    final isChoir = tenant?.type == 'choir';
    final isVoS = tenant?.shortName == 'VoS';
    final isMain = _isMainGroup;
    final teachers = (ref.watch(teachersProvider).valueOrNull ?? const [])
        .where((t) =>
            _selectedInstrument == null ||
            t.instruments.contains(_selectedInstrument))
        .toList();
    final parents = (tenant?.parents ?? false)
        ? ref.watch(parentsProvider).valueOrNull ?? const []
        : const [];
    final shifts = ref.watch(shiftsProvider).valueOrNull ?? const [];
    final shift = shifts.where((s) => s.id == _shiftId).firstOrNull;
    final gap = SizedBox(height: ionIsIos(context) ? 0 : AppDimensions.paddingM);

    return [
      gap,
      if (isChoir) ...[
        TextFormField(
          controller: _rangeController,
          decoration: InputDecoration(
            labelText: context.l10n.personVocalRange,
            prefixIcon: ionIsIos(context) ? null : const Icon(Icons.music_note_outlined),
          ),
        ),
        gap,
      ],
      if (!isGeneral && !isChoir && !isMain)
        _dateTile(
          icon: Icons.music_note,
          label: context.l10n.personPlaysSince,
          value: _playsSince,
          lastDate: DateTime.now(),
          onChanged: (d) => setState(() => _playsSince = d),
        ),
      _dateTile(
        icon: Icons.login,
        label: context.l10n.personJoinedOn,
        value: _joined,
        clearable: false,
        onChanged: (d) => setState(() => _joined = d ?? _joined),
      ),
      if ((tenant?.parents ?? false) && !isMain)
        AppDropdownFormField<int?>(
          iosInterface: AppSelectInterface.alert, // IOS_THEME2
          value: _parentId,
          decoration: InputDecoration(
            labelText: context.l10n.personParents,
            prefixIcon: ionIsIos(context) ? null : const Icon(Icons.family_restroom),
          ),
          items: [
            DropdownMenuItem<int?>(
                value: null, child: Text(context.l10n.personNotSet)),
            for (final p in parents)
              DropdownMenuItem<int?>(value: p.id, child: Text(p.fullName)),
          ],
          onChanged: (v) => setState(() => _parentId = v),
        ),
      if ((tenant?.maintainTeachers ?? false) && !isMain) ...[
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.personPlaysWithTeacher),
          value: _hasTeacher,
          onChanged: (v) => setState(() {
            _hasTeacher = v;
            if (!v) _teacherId = null;
          }),
        ),
        if (_hasTeacher)
          AppDropdownFormField<int?>(
            iosInterface: AppSelectInterface.alert, // IOS_THEME2
            value: teachers.any((t) => t.id == _teacherId) ? _teacherId : null,
            decoration: InputDecoration(
              labelText: context.l10n.peopleTeacher,
              prefixIcon: ionIsIos(context) ? null : const Icon(Icons.school),
            ),
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(context.l10n.peopleNoTeacher)),
              for (final t in teachers)
                DropdownMenuItem<int?>(value: t.id, child: Text(t.name)),
            ],
            onChanged: (v) => setState(() => _teacherId = v),
          ),
      ],
      if (!isGeneral && !isMain)
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.peopleVoiceLeader),
          value: _isLeader,
          onChanged: (v) => setState(() => _isLeader = v),
        ),
      if (!isMain && isChoir) ...[
        TextFormField(
          controller: _instrumentsController,
          decoration: InputDecoration(
            labelText: context.l10n.peopleInstruments,
            prefixIcon: ionIsIos(context) ? null : const Icon(Icons.piano_outlined),
          ),
        ),
        gap,
      ],
      if (!isMain && isVoS) ...[
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.paddingS),
          child: Text(context.l10n.personOtherOrchestras),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final o in otherOrchestraOptions)
              FilterChip(
                label: Text(o),
                selected: _otherOrchestras.contains(o),
                onSelected: (v) => setState(() {
                  if (v) {
                    _otherOrchestras = [..._otherOrchestras, o];
                  } else {
                    _otherOrchestras =
                        _otherOrchestras.where((x) => x != o).toList();
                  }
                }),
              ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.peopleCandidate),
          value: _examinee,
          onChanged: (v) => setState(() => _examinee = v),
        ),
        TextFormField(
          controller: _testResultController,
          decoration: InputDecoration(
            labelText: context.l10n.peopleTestResult,
            prefixIcon: ionIsIos(context) ? null : const Icon(Icons.assignment_outlined),
          ),
        ),
        gap,
      ],
      if (shifts.isNotEmpty) ...[
        AppDropdownFormField<String?>(
          iosInterface: AppSelectInterface.alert, // IOS_THEME2
          value: _shiftId,
          decoration: InputDecoration(
            labelText: context.l10n.personShiftPlan,
            prefixIcon: ionIsIos(context) ? null : const Icon(Icons.schedule),
          ),
          items: [
            DropdownMenuItem<String?>(
                value: null, child: Text(context.l10n.personNoShift)),
            for (final sp in shifts)
              DropdownMenuItem<String?>(value: sp.id, child: Text(sp.name)),
          ],
          // Ionic onShiftChange: named shifts → first name, else start = today
          onChanged: (v) => setState(() {
            _shiftId = v;
            final sp = shifts.where((x) => x.id == v).firstOrNull;
            if (sp == null) {
              _shiftName = null;
              _shiftStart = null;
            } else if (sp.hasNamedShifts) {
              _shiftName = sp.shifts.first.name;
              _shiftStart = null;
            } else {
              _shiftName = null;
              _shiftStart = DateTime.now();
            }
          }),
        ),
        if (shift != null && shift.hasNamedShifts)
          AppDropdownFormField<String?>(
            iosInterface: AppSelectInterface.alert, // IOS_THEME2
            value: _shiftName,
            decoration: InputDecoration(
              labelText: context.l10n.personShift,
              prefixIcon: ionIsIos(context) ? null : const Icon(Icons.access_time),
            ),
            items: [
              for (final name in shift.shifts.map((x) => x.name).toSet())
                DropdownMenuItem<String?>(value: name, child: Text(name)),
            ],
            onChanged: (v) => setState(() => _shiftName = v),
          ),
        if (shift != null && !shift.hasNamedShifts)
          _dateTile(
            icon: Icons.calendar_today,
            label: context.l10n.personStartDate,
            value: _shiftStart,
            clearable: false,
            onChanged: (d) => setState(() => _shiftStart = d ?? _shiftStart),
          ),
        gap,
      ],
      TextFormField(
        controller: _otherExerciseController,
        decoration: InputDecoration(
          labelText: context.l10n.peopleOtherDuties,
          prefixIcon: ionIsIos(context) ? null : const Icon(Icons.work_outline),
        ),
        textCapitalization: TextCapitalization.sentences,
      ),
    ];
  }

  bool get _hasImage =>
      _pickedImage != null || (_adoptedImg?.isNotEmpty ?? false);

  /// ASTRA_PHOTO: Ionic onProfileImageClick – no picture: open the file
  /// chooser right away; with a picture: replace or remove it (Ionic viewer
  /// actions `person.replace` / `common.remove`).
  Future<void> _onProfileImageTap() async {
    if (!_hasImage) {
      await _pickImage();
      return;
    }
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        AppActionSheetAction(
          value: 'replace',
          icon: Icons.photo_camera_outlined,
          label: context.l10n.personReplace,
        ),
        AppActionSheetAction(
          value: 'remove',
          icon: Icons.delete_outline,
          label: context.l10n.commonRemove,
          destructive: true,
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'replace':
        await _pickImage();
      case 'remove':
        await _removeImage();
    }
  }

  /// Ionic onImageSelect (new person): max 2 MB, kept locally until save.
  Future<void> _pickImage() async {
    try {
      final image = await ref.read(personImagePickerProvider)();
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.length > kPersonImageMaxBytes) {
        ToastHelper.showError(context, context.l10n.personPhotoTooLarge);
        return;
      }
      setState(() {
        _pickedImage = bytes;
        _adoptedImg = null; // Ionic overwrites player.img with the data URL
      });
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.personPhotoLoadFailed);
      }
    }
  }

  /// Ionic removeImgFromViewer (new person): confirm, then reset locally.
  Future<void> _removeImage() async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.personRemovePhoto,
      message: context.l10n.personRemovePhotoMessage,
      confirmText: context.l10n.commonRemove,
      cancelText: context.l10n.commonCancel,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _pickedImage = null;
      _adoptedImg = null;
    });
    ToastHelper.showSuccess(context, context.l10n.personPhotoRemoved);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthday = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(playerRepositoryWithTenantProvider);
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      // B3-015: Check for duplicate names
      final existingPlayers = await repo.findPlayersByName(firstName, lastName);
      if (existingPlayers.isNotEmpty && mounted) {
        final confirmed = await DialogHelper.showConfirmation(
          context,
          title: context.l10n.peopleFlutterPossibleDuplicate,
          message: context.l10n.peopleFlutterDuplicateMessage(
              '$firstName $lastName', existingPlayers.length),
          confirmText: context.l10n.peopleFlutterCreateAnyway,
          cancelText: context.l10n.commonCancel,
        );
        if (!confirmed) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final person = Person(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        instrument: _selectedInstrument,
        birthday: _birthday?.toIso8601String().split('T').first,
        joined: _joined.toIso8601String().split('T').first,
        additionalFields: _additionalFieldValues.isNotEmpty ? _additionalFieldValues : null,
        img: _adoptedImg,
        otherExercise: _textOrNull(_otherExerciseController),
        range: _textOrNull(_rangeController),
        instruments: _textOrNull(_instrumentsController),
        testResult: _textOrNull(_testResultController),
        playsSince: _playsSince?.toIso8601String().split('T').first,
        hasTeacher: _hasTeacher,
        teacher: _hasTeacher ? _teacherId : null,
        isLeader: _isLeader,
        parentId: _parentId,
        examinee: _examinee,
        otherOrchestras: _otherOrchestras.isEmpty ? null : _otherOrchestras,
        shiftId: _shiftId,
        shiftName: _shiftName,
        shiftStart: _shiftStart?.toIso8601String(),
        correctBirthday: _birthday != null,
      );

      // LOGIC_PEOPLE: Ionic addPerson → db.addPlayer(player, Boolean(email),
      // role): the account is registered right away when an e-mail is set
      // (RESPONSIBLE for the main group, else PLAYER), an existing row of the
      // same account is reactivated instead of duplicated, and the person is
      // added to all Termine since the join date.
      await repo.addPlayer(
        person,
        register: person.email != null && person.email!.isNotEmpty,
        role: _isMainGroup ? Role.responsible : Role.player,
        // ASTRA_PHOTO: uploaded after the insert; a failure keeps the person.
        imageBytes: _pickedImage,
      );
      ref.read(trackingServiceProvider).track(TrackingEvent.playerAdded, properties: {'instrumentId': person.instrument});

      // Invalidate the people list to trigger refresh
      ref.invalidate(realtimePlayersProvider);
      ref.invalidate(playersProvider);

      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.personAdded);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        // Ionic: person.addFailed
        ToastHelper.showError(context, context.l10n.personAddFailed(friendlyErrorMessage(e)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// UX_PEOPLE: Ionic person.page `.profile-header` while creating: 120px
/// avatar with ring and shadow, the typed name below (h1).
/// ASTRA_PHOTO: tappable like Ionic `.profile-avatar-wrapper.editable` with
/// the camera badge; shows the picked (or adopted) Passbild as preview.
class _CreateProfileHeader extends StatelessWidget {
  const _CreateProfileHeader({
    required this.firstName,
    required this.lastName,
    required this.onTap,
    this.imageBytes,
    this.imageUrl,
  });

  final TextEditingController firstName;
  final TextEditingController lastName;
  final VoidCallback onTap;
  final Uint8List? imageBytes;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
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
    final Widget avatar;
    if (imageBytes != null) {
      avatar = Image.memory(
        imageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatar = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else {
      avatar = placeholder;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 16, 12),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: context.l10n.peoplePassportPhoto,
            child: GestureDetector(
              key: const Key('person_create_avatar'),
              onTap: onTap,
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ringColor, width: 3),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x2E000000),
                              offset: Offset(0, 4),
                              blurRadius: 16),
                        ],
                      ),
                      child: ClipOval(child: avatar),
                    ),
                    // Ionic .profile-avatar-badge (camera) when editable
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
          ),
          ListenableBuilder(
            listenable: Listenable.merge([firstName, lastName]),
            builder: (context, _) {
              final name = '${firstName.text} ${lastName.text}'.trim();
              if (name.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 21.6, fontWeight: FontWeight.w600, height: 1.2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
