import '../../../../core/providers/user_registration_providers.dart'; // AUTH
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
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

  String get _nameKey =>
      '${_firstNameController.text.trim()}|${_lastNameController.text.trim()}';

  void _onNameInput() {
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 250), _lookupByName);
  }

  Future<void> _lookupByName() async {
    if (!mounted) return;
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
      final matches = await ref
          .read(crossTenantPersonRepositoryWithTenantProvider)
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
    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w-\.+]+@([\w-]+\.)+[\w-]{2,}$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) return;
    if (email == _lastEmailLookup) return;
    _lastEmailLookup = email;

    List<CrossTenantPersonCandidate> matches;
    try {
      final linkedIds = await ref.read(linkedTenantIdsProvider.future);
      matches = await ref
          .read(crossTenantPersonRepositoryWithTenantProvider)
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

    return Scaffold(
      // Ionic person.page (create): title "Person hinzufügen", save via the
      // person-add FAB.
      appBar: AppBar(
        title: Text(context.l10n.attendanceAddPerson),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('person_create_save'),
        tooltip: context.l10n.commonSave,
        onPressed: _isLoading ? null : _save,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.person_add_alt_1_outlined),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppDimensions.paddingM,
              AppDimensions.paddingM, AppDimensions.paddingM, 96),
          children: [
            // First Name
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: '${context.l10n.peopleFirstName} *',
                hintText: 'Max',
                prefixIcon: const Icon(Icons.person),
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
            const SizedBox(height: AppDimensions.paddingM),

            // Last Name
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: '${context.l10n.peopleLastName} *',
                hintText: 'Mustermann',
                prefixIcon: const Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.peopleFlutterLastNameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Cross-tenant name suggestions
            if (_nameSuggestions.isNotEmpty) ...[
              PersonMatchSuggestions(
                matches: _nameSuggestions,
                onSelected: _applyMatchedPerson,
                onDismiss: _dismissNameSuggestions,
              ),
              const SizedBox(height: AppDimensions.paddingM),
            ],

            // Instrument Dropdown
            instrumentsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(context.l10n.peopleFlutterErrorWith(e)),
              data: (instruments) {
                final label = groupLabel(tenant?.type);
                return DropdownButtonFormField<int>(
                value: _selectedInstrument,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: const Icon(Icons.music_note),
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
            const SizedBox(height: AppDimensions.paddingM),

            // Birthday
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake),
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
            const Divider(),

            // Email
            TextFormField(
              controller: _emailController,
              focusNode: _emailFocus,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.l10n.peopleFlutterOptional(context.l10n.peopleEmail),
                hintText: 'max@example.com',
                prefixIcon: const Icon(Icons.email),
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
            const SizedBox(height: AppDimensions.paddingM),

            // Phone
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: context.l10n.peopleFlutterOptional(context.l10n.peoplePhone),
                hintText: '+49 123 456789',
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppDimensions.paddingM),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: context.l10n.peopleFlutterOptional(context.l10n.peopleNotes),
                hintText: context.l10n.peopleFlutterNotesHint,
                prefixIcon: const Icon(Icons.note),
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
        return SwitchListTile(
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
            final date = await showDatePicker(
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
            child: Text(churchLabel(_additionalFieldValues[field.id], churches)),
          ),
        );

      case 'select':
        final options = field.options ?? [];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<String>(
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

  /// Ionic: "Möchtest du gleich ein Konto für die Person anlegen?" — the
  /// account is created server-side via AuthService.createAccountForPerson.
  Future<void> _offerAccountCreation(Person created) async {
    final create = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.personEmailAdded),
        content: Text(context.l10n.personCreateAccountNow),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonNo),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.commonYes),
          ),
        ],
      ),
    );
    if (create != true || !mounted) return;
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return;
    try {
      // AUTH: server-side account creation (attendix-user Edge Function)
      await ref.read(accountCreationNotifierProvider.notifier).createAccount(created);
      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.personAccountCreated);
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(e));
    }
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
      leading: Icon(icon),
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
        final picked = await showDatePicker(
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
    const gap = SizedBox(height: AppDimensions.paddingM);

    return [
      gap,
      if (isChoir) ...[
        TextFormField(
          controller: _rangeController,
          decoration: InputDecoration(
            labelText: context.l10n.personVocalRange,
            prefixIcon: const Icon(Icons.music_note_outlined),
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
        DropdownButtonFormField<int?>(
          value: _parentId,
          decoration: InputDecoration(
            labelText: context.l10n.personParents,
            prefixIcon: const Icon(Icons.family_restroom),
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.personPlaysWithTeacher),
          value: _hasTeacher,
          onChanged: (v) => setState(() {
            _hasTeacher = v;
            if (!v) _teacherId = null;
          }),
        ),
        if (_hasTeacher)
          DropdownButtonFormField<int?>(
            value: teachers.any((t) => t.id == _teacherId) ? _teacherId : null,
            decoration: InputDecoration(
              labelText: context.l10n.peopleTeacher,
              prefixIcon: const Icon(Icons.school),
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
        SwitchListTile(
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
            prefixIcon: const Icon(Icons.piano_outlined),
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.peopleCandidate),
          value: _examinee,
          onChanged: (v) => setState(() => _examinee = v),
        ),
        TextFormField(
          controller: _testResultController,
          decoration: InputDecoration(
            labelText: context.l10n.peopleTestResult,
            prefixIcon: const Icon(Icons.assignment_outlined),
          ),
        ),
        gap,
      ],
      if (shifts.isNotEmpty) ...[
        DropdownButtonFormField<String?>(
          value: _shiftId,
          decoration: InputDecoration(
            labelText: context.l10n.personShiftPlan,
            prefixIcon: const Icon(Icons.schedule),
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
          DropdownButtonFormField<String?>(
            value: _shiftName,
            decoration: InputDecoration(
              labelText: context.l10n.personShift,
              prefixIcon: const Icon(Icons.access_time),
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
          prefixIcon: const Icon(Icons.work_outline),
        ),
        textCapitalization: TextCapitalization.sentences,
      ),
    ];
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
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

      final created = await repo.createPlayer(person);
      ref.read(trackingServiceProvider).track(TrackingEvent.playerAdded, properties: {'instrumentId': person.instrument});
      // Ionic addPlayer → addPlayerToAttendancesByDate (best effort)
      try {
        await repo.addPlayerToAttendancesByDate(created);
      } catch (_) {}
      if (mounted && created.email != null && created.email!.isNotEmpty) {
        await _offerAccountCreation(created);
      }

      // Invalidate the people list to trigger refresh
      ref.invalidate(realtimePlayersProvider);
      ref.invalidate(playersProvider);

      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.personAdded);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.peopleFlutterErrorWith(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
