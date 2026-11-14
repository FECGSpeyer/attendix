import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/utils/tenant_label_utils.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/cross_tenant_person_providers.dart';
import '../../../../core/utils/person_matcher.dart';
import '../../../../data/repositories/cross_tenant_person_repository.dart';
import '../widgets/person_match_suggestions.dart';
import '../widgets/person_image_picker.dart';
import '../../../../core/providers/church_providers.dart';
import '../../../../core/utils/extra_field_utils.dart' show parseExtraFieldNumber;
import '../../../../data/models/church/church.dart';
import '../../../../data/repositories/extra_fields_repository.dart' show extraFieldDefaultValue;
import '../../../../core/providers/parent_providers.dart';
import '../../../../core/providers/shift_providers.dart';
import '../../../../core/providers/teacher_providers.dart';
import '../../../../data/models/shift/shift_plan.dart';
import '../widgets/church_picker_sheet.dart';
import '../widgets/person_detail/date_input_row.dart';
import '../widgets/person_detail/allgemein_accordion.dart'
    show otherOrchestraOptions, personExtraFields;
import '../../person_write.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/ion/ion_widgets.dart';
import '../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import '../../../../core/utils/error_message.dart';
import '../widgets/person_detail/account_accordion.dart' show showAccountHelpSheet;
import '../../../../data/models/instrument/instrument.dart' show Group;
import 'package:intl/intl.dart';
import '../../person_create_prefill.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Page for creating a new person
class PersonCreatePage extends ConsumerStatefulWidget {
  const PersonCreatePage({super.key, this.prefill});

  /// Start values from the chat assistant (saving stays here).
  final PersonCreatePrefill? prefill;

  @override
  ConsumerState<PersonCreatePage> createState() => _PersonCreatePageState();
}

class _PersonCreatePageState extends ConsumerState<PersonCreatePage> {
  final _formKey = GlobalKey<FormState>();

  /// E2E PERSONEN-23: after a failed save the hints update while typing
  /// (and disappear once a field is valid) instead of staying until the
  /// next save.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  int? _selectedInstrument;
  // Ionic newPlayer: birthday, playsSince and joined = today (UTC midnight),
  // correctBirthday false until the birthday is edited (warning colour).
  DateTime? _birthday = _today();
  bool _birthdayEdited = false;
  bool _isLoading = false;
  final Map<String, dynamic> _additionalFieldValues = {};
  final Set<String> _defaultedFields = {};

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
  DateTime? _playsSince = _today();
  DateTime _joined = _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Ionic dayjs(date).startOf('day').utc(true).toISOString().
  static String _utcMidnightIso(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).toIso8601String();
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
    final prefill = widget.prefill;
    if (prefill != null) {
      _firstNameController.text = prefill.firstName;
      _lastNameController.text = prefill.lastName ?? '';
      if (prefill.groupId != null) _selectedInstrument = prefill.groupId;
      if (prefill.birthday != null) {
        _birthday = prefill.birthday;
        _birthdayEdited = true;
      }
    }
    _firstNameController.addListener(_onNameInput);
    _lastNameController.addListener(_onNameInput);
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _onEmailBlur();
    });
    // The cross-instance lookup also runs for prefilled names.
    if (prefill != null) _onNameInput();
  }

  /// Ionic person.page `hasChanges` for a new person: something was entered.
  bool get _hasInput =>
      _pickedImage != null ||
      _inputControllers.any((c) => c.text.trim().isNotEmpty);

  List<TextEditingController> get _inputControllers => [
        _firstNameController,
        _lastNameController,
        _emailController,
        _phoneController,
        _notesController,
        _rangeController,
        _instrumentsController,
        _testResultController,
        _otherExerciseController,
      ];

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
      // Ionic CrossTenantService.getPossiblePersonsByName: error toast.
      if (mounted) ToastHelper.showError(context, context.l10n.dbLoadPeopleFailed);
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
      // Ionic getPossiblePersonsByEmail: error toast.
      if (mounted) ToastHelper.showError(context, context.l10n.dbLoadPeopleFailed);
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
    // Ionic person.page: a new person starts in the first group
    // (db.groups()[0]); the select offers no "none" entry.
    _selectedInstrument ??= instrumentsAsync.valueOrNull?.firstOrNull?.id;
    final tenant = ref.watch(currentTenantProvider);
    final extraFields = personExtraFields(ref, tenant);

    // Ionic person.page (new person): getFieldTypeDefaultValue(type,
    // field.defaultValue, options, churches) – Gemeinde = first church, so
    // wait for the churches when such a field exists.
    final hasChurchField = extraFields.any((f) => f.type == 'bfecg_church');
    final churchesAsync = hasChurchField ? ref.watch(churchesProvider) : null;
    // Per field, so organisation fields loaded later still get their
    // default; typed values are never overwritten (sol review).
    if (extraFields.any((f) => !_defaultedFields.contains(f.id)) &&
        (churchesAsync == null || !churchesAsync.isLoading)) {
      final churchIds = <Object>[
        for (final c in churchesAsync?.valueOrNull ?? const <Church>[])
          if (c.id != null) c.id!,
      ];
      for (final field in extraFields) {
        if (!_defaultedFields.add(field.id)) continue;
        _additionalFieldValues[field.id] ??= extraFieldDefaultValue(
          field.type,
          defaultValue: field.defaultValue,
          options: field.options,
          churchIds: churchIds,
        );
      }
    }

    final ios = ionIsIos(context);
    final gap = SizedBox(height: ios ? 0 : AppDimensions.paddingM);
    // Beta-Skin: fields in cards, "Sichern" in the header instead of the FAB.
    final rd = context.rdSkin;

    // Swipe-down / back with input asks "Änderungen verwerfen?" like the
    // close button (Ionic dismiss()).
    return ListenableBuilder(
      listenable: Listenable.merge(_inputControllers),
      builder: (context, child) => PopScope(
        canPop: !_hasInput,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: child!,
      ),
      child: Scaffold(
      // Ionic person.page (create): title "Person hinzufügen", close button
      // at the end, save via the person-add FAB. UX_PEOPLE: modalBackground.
      backgroundColor: rd?.bg ?? ionContentBackground(context),
      appBar: AppBar(
        title: Text(context.l10n.attendanceAddPerson),
        automaticallyImplyLeading: false,
        actions: [
          if (rd != null)
            TextButton(
              key: const Key('person_create_save'),
              onPressed: _isLoading || !_canEdit ? null : _save,
              child: Text(context.l10n.commonSave),
            ),
          // PEO-10: Ionic modal close (iOS glass circle).
          IonCloseButton(onPressed: _close),
        ],
      ),
      // IOS_SHELL2: iOS → ion-fab in the tab bar row
      floatingActionButton: rd != null ? null : TabBarFab(
        child: IonFabButton(
          key: const Key('person_create_save'),
          tooltip: context.l10n.commonSave,
          onPressed: _isLoading || !_canEdit ? null : _save,
          icon: AppIcons.personAddAlt1Outlined,
        ),
      ),
      // Ionic person.page readOnly (= not admin/responsible): the create form
      // is shown locked (disabled inputs) for viewers.
      body: ExcludeFocus(
        excluding: !_canEdit,
        child: IgnorePointer(
        ignoring: !_canEdit,
        child: Opacity(
          opacity: _canEdit ? 1 : 0.5,
          child: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: IonFormTheme(
          child: context.rdSkin == null
              ? ListView(
                  // PEO-06: the create modal is the person page template.
                  padding: EdgeInsets.only(
                      bottom: scrollEndPadding(context, base: 16, fabRoom: 80)),
                  children: _buildClassicForm(instrumentsAsync, tenant, extraFields),
                )
              : ListView(
          padding: rd != null
              ? EdgeInsets.only(bottom: scrollEndPadding(context, base: 16))
              : ios
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

            ...ionBetaGroup(context, [
            // First Name
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: '${context.l10n.peopleFirstName} *',
                hintText: 'Max',
                prefixIcon: ionIsIos(context) ? null : Icon(AppIcons.person),
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
                prefixIcon: ionIsIos(context) ? null : Icon(AppIcons.person),
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
                  interface: AppSelectInterface.alert,
                value: _selectedInstrument,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: ionIsIos(context) ? null : Icon(AppIcons.musicNote),
                ),
                items: [
                  ...instruments.map((i) => DropdownMenuItem<int>(
                    value: i.id,
                    child: Text(i.name),
                  )),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selectedInstrument = value);
                },
              );
              },
            ),
            gap,

            // Birthday (Ionic: warning colour until edited)
            _dateTile(
              icon: AppIcons.cake,
              label: context.l10n.peopleBirthday,
              value: _birthday,
              highlight: !_birthdayEdited,
              onChanged: (d) => setState(() {
                _birthday = d;
                _birthdayEdited = true;
              }),
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
                prefixIcon: ionIsIos(context) ? null : Icon(AppIcons.email),
              ),
              // E2E PERSONEN-28: an invalid e-mail used to reach the account
              // sign-up (HTTP 400, "Fehler beim Erstellen des Accounts");
              // check it at the field before anything is sent.
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isNotEmpty && !isValidPersonEmail(email)) {
                  return context.l10n.personInvalidEmail;
                }
                return null;
              },
              keyboardType: TextInputType.emailAddress,
            ),
            gap,

            // Phone
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: context.l10n.peopleFlutterOptional(context.l10n.peoplePhone),
                hintText: '+49 123 456789',
                prefixIcon: ionIsIos(context) ? null : Icon(AppIcons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            gap,

            // Ionic: "Notizen" only for existing persons (existingPlayer && isAdmin).
            ..._buildIonicFields(tenant),
            ]),

            // Account help (Ionic person.accountHelp / existingUserHint)
            Padding(
              padding: rd != null
                  ? const EdgeInsets.fromLTRB(20, 0, 20, 12)
                  : EdgeInsets.only(top: AppDimensions.paddingM),
              child: Text(
                '${context.l10n.personAccountHelp}\n${context.l10n.personExistingUserHint}',
                style: TextStyle(fontSize: 12, color: AppColors.medium),
              ),
            ),

            // Extra Fields Section - as ExpansionTile like Ionic Accordion
            if (extraFields.isNotEmpty)
              ...ionBetaGroup(context, [
                if (rd != null)
                  ExpansionTile(
                    title: Text(context.l10n.peopleExtraFields),
                    initiallyExpanded: true,
                    tilePadding: EdgeInsets.zero,
                    children: extraFields.map((field) => _buildExtraFieldInput(field)).toList(),
                  )
                else
                  IonAccordionTile(
                    title: Text(context.l10n.peopleExtraFields),
                    initiallyExpanded: true,
                    headerPadding: EdgeInsets.zero,
                    children: extraFields.map((field) => _buildExtraFieldInput(field)).toList(),
                  ),
              ]),

            const SizedBox(height: AppDimensions.paddingL),
          ],
        ),
        ),
      ),
        ),
      ),
      ),
      ),
    );
  }

  /// PEO-06: which accordion of the create form is open (Ionic
  /// `ion-accordion-group [value]="existingPlayer && !readOnly ? '' : 'more'"`
  /// → "Allgemein" starts open for a new person).
  String? _openSection = 'general';

  void _toggle(String key) =>
      setState(() => _openSection = _openSection == key ? null : key);

  /// Ionic `ion-item` + stacked `ion-label` + `ion-input` as a form field
  /// (keeps the validator; the error text shows below the input).
  Widget _ionField({
    required String label,
    required TextEditingController controller,
    FormFieldValidator<String>? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    FocusNode? focusNode,
    bool lines = true,
    bool autocorrect = true,
  }) {
    final ios = ionIsIos(context);
    final fg = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(
        constraints: BoxConstraints(minHeight: ios ? 68 : 72),
        decoration: BoxDecoration(
          border: lines
              ? Border(
                  bottom: BorderSide(
                      color: ionLineColor(context), width: ios ? 0.55 : 1),
                )
              : null,
        ),
        padding: const EdgeInsets.only(right: 16, top: 10, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: ios ? 14 : 12,
                    color: ios ? fg : AppColors.medium)),
            TextFormField(
              controller: controller,
              focusNode: focusNode,
              validator: validator,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              autocorrect: autocorrect,
              style: TextStyle(fontSize: ios ? 17 : 16, color: fg),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PEO-06: Ionic person page (new person) – names side by side, then the
  /// accordions "Allgemein", "Account" and "Zusatzfelder" with the same
  /// rows as the person page.
  List<Widget> _buildClassicForm(
    AsyncValue<List<Group>> instrumentsAsync,
    Tenant? tenant,
    List<ExtraField> extraFields,
  ) {
    final l10n = context.l10n;
    final groups = instrumentsAsync.valueOrNull ?? const <Group>[];
    return [
      _CreateProfileHeader(
        firstName: _firstNameController,
        lastName: _lastNameController,
        imageBytes: _pickedImage,
        imageUrl: _adoptedImg,
        onTap: _onProfileImageTap,
      ),
      // Ionic ion-grid: Vorname | Nachname, `ion-item lines="none"`, no
      // placeholder.
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ionField(
                label: l10n.peopleFirstName,
                controller: _firstNameController,
                lines: false,
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().isEmpty
                    ? l10n.peopleFlutterFirstNameRequired
                    : null,
              ),
            ),
            Expanded(
              child: _ionField(
                label: l10n.peopleLastName,
                controller: _lastNameController,
                lines: false,
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().isEmpty
                    ? l10n.peopleFlutterLastNameRequired
                    : null,
              ),
            ),
          ],
        ),
      ),
      if (_nameSuggestions.isNotEmpty)
        PersonMatchSuggestions(
          matches: _nameSuggestions,
          onSelected: _applyMatchedPerson,
          onDismiss: _dismissNameSuggestions,
        ),
      const SizedBox(height: 8),
      IonAccordion(
        title: l10n.attendanceGeneral,
        expanded: _openSection == 'general',
        onToggle: () => _toggle('general'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ionic: `ion-select interface="modal" [label]` (no "none").
            IonSelectRow<int>(
              label: groupLabel(tenant?.type),
              value: _selectedInstrument,
              interface: AppSelectInterface.modal,
              options: [
                for (final g in groups)
                  if (g.id != null) AppSelectOption<int>(value: g.id!, label: g.name),
              ],
              onChanged: (v) => setState(() => _selectedInstrument = v),
            ),
            ..._buildClassicGeneralRows(tenant),
          ],
        ),
      ),
      IonAccordion(
        title: l10n.personAccount,
        expanded: _openSection == 'account',
        onToggle: () => _toggle('account'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ionField(
              label: l10n.peopleEmail,
              controller: _emailController,
              focusNode: _emailFocus,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              // E2E PERSONEN-28: check the e-mail at the field before the
              // account sign-up is sent.
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isNotEmpty && !isValidPersonEmail(email)) {
                  return l10n.personInvalidEmail;
                }
                return null;
              },
            ),
            // Ionic: `ion-button fill="clear" size="small"` "Hilfe" → sheet.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: IonButton(
                  fill: IonButtonFill.clear,
                  small: true,
                  icon: AppIcons.helpOutline,
                  label: l10n.personHelp,
                  onPressed: () => showAccountHelpSheet(context),
                ),
              ),
            ),
          ],
        ),
      ),
      if (extraFields.isNotEmpty)
        IonAccordion(
          title: l10n.peopleExtraFields,
          expanded: _openSection == 'extra',
          onToggle: () => _toggle('extra'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final f in extraFields) _buildClassicExtraField(f)],
          ),
        ),
    ];
  }

  /// Rows of the "Allgemein" accordion after the group (Ionic order).
  List<Widget> _buildClassicGeneralRows(Tenant? tenant) {
    final l10n = context.l10n;
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
    final ios = ionIsIos(context);

    return [
      if (isChoir)
        _ionField(label: l10n.personVocalRange, controller: _rangeController),
      _ionField(
        label: l10n.peoplePhone,
        controller: _phoneController,
        keyboardType: TextInputType.phone,
      ),
      _dateTile(
        icon: AppIcons.cake,
        label: l10n.peopleBirthday,
        value: _birthday,
        highlight: !_birthdayEdited,
        onChanged: (d) => setState(() {
          _birthday = d;
          _birthdayEdited = true;
        }),
      ),
      if (!isGeneral && !isChoir && !isMain)
        _dateTile(
          icon: AppIcons.musicNote,
          label: l10n.personPlaysSince,
          value: _playsSince,
          lastDate: DateTime.now(),
          onChanged: (d) => setState(() => _playsSince = d),
        ),
      _dateTile(
        icon: AppIcons.login,
        label: l10n.personJoinedOn,
        value: _joined,
        clearable: false,
        onChanged: (d) => setState(() => _joined = d ?? _joined),
      ),
      if ((tenant?.parents ?? false) && !isMain)
        IonSelectRow<int?>(
          label: l10n.personParents,
          stacked: true,
          value: _parentId,
          interface: AppSelectInterface.modal,
          options: [
            AppSelectOption<int?>(value: null, label: l10n.personNotSet),
            for (final p in parents)
              if (p.id != null) AppSelectOption<int?>(value: p.id, label: p.fullName),
          ],
          onChanged: (v) => setState(() => _parentId = v),
        ),
      if ((tenant?.maintainTeachers ?? false) && !isMain) ...[
        IonToggleRow(
          label: l10n.personPlaysWithTeacher,
          value: _hasTeacher,
          editable: true,
          onChanged: (v) => setState(() {
            _hasTeacher = v;
            if (!v) _teacherId = null;
          }),
        ),
        if (_hasTeacher)
          IonSelectRow<int?>(
            label: l10n.peopleTeacher,
            value: teachers.any((t) => t.id == _teacherId) ? _teacherId : null,
            interface: AppSelectInterface.modal,
            options: [
              AppSelectOption<int?>(value: null, label: l10n.peopleNoTeacher),
              for (final t in teachers)
                if (t.id != null) AppSelectOption<int?>(value: t.id, label: t.name),
            ],
            onChanged: (v) => setState(() => _teacherId = v),
          ),
      ],
      if (!isGeneral && !isMain)
        IonToggleRow(
          label: l10n.peopleVoiceLeader,
          value: _isLeader,
          editable: true,
          onChanged: (v) => setState(() => _isLeader = v),
        ),
      if (!isMain && isChoir)
        _ionField(label: l10n.peopleInstruments, controller: _instrumentsController),
      if (!isMain && isVoS) ...[
        // Ionic `ion-select multiple [label]` → checkbox alert (OK).
        _OtherOrchestrasRow(
          label: l10n.personOtherOrchestras,
          values: _otherOrchestras,
          onChanged: (v) => setState(() => _otherOrchestras = v),
        ),
        IonToggleRow(
          label: l10n.peopleCandidate,
          value: _examinee,
          editable: true,
          onChanged: (v) => setState(() => _examinee = v),
        ),
        _ionField(label: l10n.peopleTestResult, controller: _testResultController),
      ],
      if (shifts.isNotEmpty) ...[
        IonSelectRow<String?>(
          label: l10n.personShiftPlan,
          value: _shiftId,
          options: [
            AppSelectOption<String?>(value: null, label: l10n.personNoShift),
            for (final sp in shifts)
              if (sp.id != null) AppSelectOption<String?>(value: sp.id, label: sp.name),
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
          IonSelectRow<String>(
            label: l10n.personShift,
            value: _shiftName,
            options: [
              for (final name in shift.shifts.map((x) => x.name).toSet())
                AppSelectOption<String>(value: name, label: name),
            ],
            onChanged: (v) => setState(() => _shiftName = v),
          ),
        if (shift != null && !shift.hasNamedShifts)
          // Ionic `ion-label` + `ion-datetime-button`.
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Container(
              constraints: BoxConstraints(minHeight: ios ? 44 : 48),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: ionLineColor(context), width: ios ? 0.55 : 1),
                ),
              ),
              padding: const EdgeInsets.only(right: 16, top: 6, bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(l10n.personStartDate,
                        style: TextStyle(fontSize: ios ? 17 : 16)),
                  ),
                  IonDatetimeButton(
                    date: DateFormat(dateFmt()).format(_shiftStart ?? DateTime.now()),
                    onDateTap: () async {
                      final d = await showAppDatePicker(
                        context: context,
                        initialDate: _shiftStart ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null && mounted) setState(() => _shiftStart = d);
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
      _ionField(label: l10n.peopleOtherDuties, controller: _otherExerciseController),
    ];
  }

  /// Ionic "Zusatzfelder" items of the person page (classic design).
  Widget _buildClassicExtraField(ExtraField field) {
    final value = _additionalFieldValues[field.id];
    switch (field.type) {
      case 'text':
      case 'textarea':
        return IonInputRow(
          label: field.name,
          value: value?.toString(),
          textarea: field.type == 'textarea',
          onChanged: (v) => _additionalFieldValues[field.id] = v,
        );
      case 'number':
        return IonInputRow(
          label: field.name,
          value: value?.toString(),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: true),
          onChanged: (v) =>
              _additionalFieldValues[field.id] = parseExtraFieldNumber(v),
        );
      case 'boolean':
        return IonToggleRow(
          label: field.name,
          value: value as bool? ?? true,
          editable: true,
          onChanged: (v) => setState(() => _additionalFieldValues[field.id] = v),
        );
      case 'select':
        return IonSelectRow<String>(
          label: field.name,
          value: value?.toString(),
          options: [
            for (final o in field.options ?? const <String>[])
              AppSelectOption<String>(value: o, label: o),
          ],
          onChanged: (v) => setState(() => _additionalFieldValues[field.id] = v),
        );
      case 'bfecg_church':
        final churches = ref.watch(churchesProvider).valueOrNull ?? const [];
        final ios = ionIsIos(context);
        return Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Container(
            constraints: BoxConstraints(minHeight: ios ? 44 : 48),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: ionLineColor(context), width: ios ? 0.55 : 1),
              ),
            ),
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(field.name, style: TextStyle(fontSize: ios ? 17 : 16)),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IonButton(
                      fill: IonButtonFill.clear,
                      label: churchLabel(value, churches),
                      onPressed: () async {
                        final selected = await showChurchPickerSheet(
                          context,
                          title: field.name,
                          churches: churches,
                          selectedId: value?.toString(),
                        );
                        if (selected != null) {
                          setState(() => _additionalFieldValues[field.id] = selected);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        // date (and unknown types) as before
        return _buildExtraFieldInput(field);
    }
  }

  bool get _canEdit {
    final role = ref.watch(currentRoleProvider);
    return role.isAdmin || role.isResponsible;
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            initialValue: _additionalFieldValues[field.id]?.toString() ?? '',
            onChanged: (value) => _additionalFieldValues[field.id] = parseExtraFieldNumber(value),
          ),
        );

      case 'boolean':
        return SwitchListTile.adaptive(
          title: Text(field.name),
          value: _additionalFieldValues[field.id] as bool? ?? true,
          onChanged: (value) => setState(() => _additionalFieldValues[field.id] = value),
        );

      case 'date':
        return DateInputRow(
          label: field.name,
          value: _additionalFieldValues[field.id]?.toString(),
          lastDate: DateTime.now(),
          onChanged: (iso) => setState(() => _additionalFieldValues[field.id] = iso),
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
            interface: AppSelectInterface.alert,
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

  /// Ionic date item: typed TT.MM.JJJJ (on blur) + calendar button.
  Widget _dateTile({
    required IconData icon,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    bool clearable = true,
    DateTime? lastDate,
    bool highlight = false,
  }) {
    return DateInputRow(
      label: label,
      value: value == null ? null : _utcMidnightIso(value),
      highlight: highlight,
      lastDate: lastDate ?? DateTime.now(),
      onChanged: (iso) {
        final d = DateTime.parse(iso);
        onChanged(DateTime(d.year, d.month, d.day));
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
            prefixIcon: ionIsIos(context) ? null : Icon(AppIcons.musicNoteOutlined),
          ),
        ),
        gap,
      ],
      if (!isGeneral && !isChoir && !isMain)
        _dateTile(
          icon: AppIcons.musicNote,
          label: context.l10n.personPlaysSince,
          value: _playsSince,
          lastDate: DateTime.now(),
          onChanged: (d) => setState(() => _playsSince = d),
        ),
      _dateTile(
        icon: AppIcons.login,
        label: context.l10n.personJoinedOn,
        value: _joined,
        clearable: false,
        onChanged: (d) => setState(() => _joined = d ?? _joined),
      ),
      if ((tenant?.parents ?? false) && !isMain)
        AppDropdownFormField<int?>(
          interface: AppSelectInterface.alert,
          value: _parentId,
          decoration: InputDecoration(
            labelText: context.l10n.personParents,
            prefixIcon: ionIsIos(context) ? null : Icon(AppIcons.familyRestroom),
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
            interface: AppSelectInterface.alert,
            value: teachers.any((t) => t.id == _teacherId) ? _teacherId : null,
            decoration: InputDecoration(
              labelText: context.l10n.peopleTeacher,
              prefixIcon: ionIsIos(context) ? null : Icon(AppIcons.school),
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
            prefixIcon: ionIsIos(context) ? null : Icon(AppIcons.pianoOutlined),
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
            prefixIcon: ionIsIos(context) ? null : Icon(AppIcons.assignmentOutlined),
          ),
        ),
        gap,
      ],
      if (shifts.isNotEmpty) ...[
        AppDropdownFormField<String?>(
          interface: AppSelectInterface.alert,
          value: _shiftId,
          decoration: InputDecoration(
            labelText: context.l10n.personShiftPlan,
            prefixIcon: ionIsIos(context) ? null : Icon(AppIcons.schedule),
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
            interface: AppSelectInterface.alert,
            value: _shiftName,
            decoration: InputDecoration(
              labelText: context.l10n.personShift,
              prefixIcon: ionIsIos(context) ? null : Icon(AppIcons.accessTime),
            ),
            items: [
              for (final name in shift.shifts.map((x) => x.name).toSet())
                DropdownMenuItem<String?>(value: name, child: Text(name)),
            ],
            onChanged: (v) => setState(() => _shiftName = v),
          ),
        if (shift != null && !shift.hasNamedShifts)
          _dateTile(
            icon: AppIcons.calendarToday,
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
          prefixIcon: ionIsIos(context) ? null : Icon(AppIcons.workOutline),
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
          icon: AppIcons.photoCameraOutlined,
          label: context.l10n.personReplace,
        ),
        AppActionSheetAction(
          value: 'remove',
          icon: AppIcons.deleteOutline,
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
      final image = await pickPersonImage(context, ref);
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

  Future<void> _save() async {
    // Ionic readOnly: only admins and responsibles can create persons.
    final role = ref.read(currentRoleProvider);
    if (!(role.isAdmin || role.isResponsible) || _isLoading) return;
    // Bind the tenant repository before the first await (tenant switch).
    final repo = ref.read(playerRepositoryWithTenantProvider);
    // Commit a typed date (applied on focus loss) before reading the form.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _isLoading = true);

    try {
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
        birthday: _birthday == null ? null : _utcMidnightIso(_birthday!),
        joined: _utcMidnightIso(_joined),
        additionalFields: _additionalFieldValues.isNotEmpty ? _additionalFieldValues : null,
        img: _adoptedImg,
        otherExercise: _textOrNull(_otherExerciseController),
        range: _textOrNull(_rangeController),
        instruments: _textOrNull(_instrumentsController),
        testResult: _textOrNull(_testResultController),
        playsSince: _playsSince == null ? null : _utcMidnightIso(_playsSince!),
        hasTeacher: _hasTeacher,
        teacher: _hasTeacher ? _teacherId : null,
        isLeader: _isLeader,
        parentId: _parentId,
        examinee: _examinee,
        otherOrchestras: _otherOrchestras.isEmpty ? null : _otherOrchestras,
        shiftId: _shiftId,
        shiftName: _shiftName,
        shiftStart: _shiftStart?.toIso8601String(),
        correctBirthday: _birthdayEdited,
      );

      // B3-015 duplicate check + LOGIC_PEOPLE: Ionic addPerson →
      // db.addPlayer(player, Boolean(email), role): the account is
      // registered right away when an e-mail is set (RESPONSIBLE for the
      // main group, else PLAYER), an existing row of the same account is
      // reactivated instead of duplicated, and the person is added to all
      // Termine since the join date. ASTRA_PHOTO: the Passbild is uploaded
      // after the insert; a failure keeps the person.
      final created = await createPersonWithChecks(
        context,
        ref,
        person,
        isMainGroup: _isMainGroup,
        imageBytes: _pickedImage,
        repo: repo,
        // Like before: a page closed at the duplicate check still creates.
        createWhenGone: true,
      );
      if (created == null) return;

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
        AppIcons.person,
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
                        child: Icon(AppIcons.cameraAlt,
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

/// Ionic `ion-select multiple [label]` "Andere Orchester": label at the
/// start, the chosen values + select icon at the end; opens the checkbox
/// alert (Abbrechen / OK).
class _OtherOrchestrasRow extends StatelessWidget {
  const _OtherOrchestrasRow({
    required this.label,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return IonSelectRow<String>(
      label: label,
      value: null,
      selectedText: values.join(', '),
      options: const [],
      onTap: () async {
        final result = await showAppCheckboxAlert<String>(
          context,
          title: label,
          options: [for (final o in otherOrchestraOptions) AppAlertOption(o, o)],
          initialValues: values,
        );
        if (result != null) {
          onChanged(otherOrchestraOptions.where(result.contains).toList());
        }
      },
    );
  }
}
