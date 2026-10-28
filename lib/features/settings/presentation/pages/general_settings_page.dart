import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/event_list_utils.dart'; // ATTENDANCE_SIGNOUT
import '../widgets/reasons_list_editor.dart'; // ATTENDANCE_SIGNOUT
import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/providers/group_providers.dart'; // SETTINGS2
import '../../../../data/models/tenant/tenant.dart';
import '../widgets/critical_rule_card.dart';
import '../widgets/critical_rule_sheet.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/page_reload.dart'; // LOGIC_SETTINGS
import '../widgets/settings_list.dart'; // UX_SETTINGS
import '../widgets/ion_condense.dart'; // UX_SETTINGS (WAVE 8)
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2

/// German holiday regions
const _holidayRegions = [
  ('', 'Keine Feiertage'),
  ('BW', 'Baden-Württemberg'),
  ('BY', 'Bayern'),
  ('BE', 'Berlin'),
  ('BB', 'Brandenburg'),
  ('HB', 'Bremen'),
  ('HH', 'Hamburg'),
  ('HE', 'Hessen'),
  ('MV', 'Mecklenburg-Vorpommern'),
  ('NI', 'Niedersachsen'),
  ('NW', 'Nordrhein-Westfalen'),
  ('RP', 'Rheinland-Pfalz'),
  ('SL', 'Saarland'),
  ('SN', 'Sachsen'),
  ('ST', 'Sachsen-Anhalt'),
  ('SH', 'Schleswig-Holstein'),
  ('TH', 'Thüringen'),
];

/// General Settings Page
class GeneralSettingsPage extends ConsumerStatefulWidget {
  const GeneralSettingsPage({super.key});

  @override
  ConsumerState<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends ConsumerState<GeneralSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  // Basic info
  final _shortNameController = TextEditingController();
  final _longNameController = TextEditingController();

  // Times
  final _practiceStartController = TextEditingController();
  final _practiceEndController = TextEditingController();

  // Settings
  DateTime? _seasonStart;
  String _selectedRegion = '';
  bool _maintainTeachers = false;
  bool _parents = false;
  bool _showMembersList = false;
  bool _showHolidays = false;
  bool _dutyView = false; // DUTY: "Meine Termine" als Dienstplan-Ansicht
  bool _shiftExcusedAsPresent = false; // SETTINGS2

  // ATTENDANCE_SIGNOUT: show all Termine + absence/late reasons
  bool _showAllAttendances = false;
  final _showAllInfoTextController = TextEditingController();
  List<String> _absenceReasons = [];
  List<String> _lateReasons = [];

  // Sharing
  bool _songSharingEnabled = false;
  String? _songSharingId;
  bool _registrationEnabled = false;
  String? _registerId;
  bool _autoApproveRegistrations = false;
  List<String> _selectedRegistrationFields = [];

  // Critical rules
  List<CriticalRule> _criticalRules = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _shortNameController.dispose();
    _longNameController.dispose();
    _practiceStartController.dispose();
    _practiceEndController.dispose();
    _showAllInfoTextController.dispose(); // ATTENDANCE_SIGNOUT
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final tenant = ref.read(currentTenantProvider);
      if (tenant == null) {
        throw Exception('Kein Tenant ausgewählt');
      }

      _shortNameController.text = tenant.shortName;
      _longNameController.text = tenant.longName;
      _practiceStartController.text = tenant.practiceStart ?? '';
      _practiceEndController.text = tenant.practiceEnd ?? '';
      _seasonStart = tenant.seasonStart != null ? DateTime.tryParse(tenant.seasonStart!) : null;
      _selectedRegion = tenant.region ?? '';
      _maintainTeachers = tenant.maintainTeachers;
      _parents = tenant.parents ?? false;
      _showMembersList = tenant.showMembersList;
      _showHolidays = tenant.showHolidays;
      // ATTENDANCE_SIGNOUT
      _showAllAttendances = tenant.showAllAttendances;
      _showAllInfoTextController.text = tenant.showAllAttendancesInfoText ?? '';
      _absenceReasons = EventListUtils.absenceReasonsOf(tenant.absenceReasons);
      _lateReasons = EventListUtils.lateReasonsOf(tenant.lateReasons);
      _dutyView = tenant.dutyView; // DUTY
      _shiftExcusedAsPresent = tenant.shiftExcusedAsPresent; // SETTINGS2
      _songSharingEnabled = tenant.songSharingId != null && tenant.songSharingId!.isNotEmpty;
      _songSharingId = tenant.songSharingId;
      _registrationEnabled = tenant.registerId != null && tenant.registerId!.isNotEmpty;
      _registerId = tenant.registerId;
      _autoApproveRegistrations = tenant.autoApproveRegistrations;
      _selectedRegistrationFields = List.from(
        tenant.registrationFields ?? ['firstName', 'lastName', 'birthDate', 'group'],
      );
      // Ensure required fields are always included
      for (final required in ['firstName', 'lastName', 'group']) {
        if (!_selectedRegistrationFields.contains(required)) {
          _selectedRegistrationFields.add(required);
        }
      }
      _criticalRules = List.from(tenant.criticalRules ?? []);

    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.settingsFlutterLoadFailed(friendlyErrorMessage(e)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasChanges = false;
        });
      }
    }
  }

  /// SETTINGS2: Ionic `hasSelectableGroups` — at least one non-main group.
  bool get _hasSelectableGroups =>
      (ref.read(groupsProvider).valueOrNull ?? const []).any((g) => g.maingroup != true);

  Future<void> _saveSettings() async {
    final defaultInfoText = context.l10n.defaultsShowAllInfoText; // LOGIC_SETTINGS
    // SETTINGS2: Ionic saveGeneralSettings validation toasts
    if (_longNameController.text.trim().isEmpty) {
      ToastHelper.showError(context, context.l10n.generalSettingsGroupNameEmpty);
      return;
    }
    if (_shortNameController.text.trim().isEmpty) {
      ToastHelper.showError(context, context.l10n.generalSettingsShortNameEmpty);
      return;
    }
    if (_registrationEnabled) {
      final groups = await ref.read(groupsProvider.future);
      if (!mounted) return;
      if (!groups.any((g) => g.maingroup != true)) {
        ToastHelper.showError(
          context,
          context.l10n.generalSettingsRegisterNoGroups,
        );
        return;
      }
    }
    if (!_formKey.currentState!.validate()) return;
    if (DemoGuard.blocked()) return; // DEMO_GUARD

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final tenant = ref.read(currentTenantProvider);

      // Safe tenant.id access (Issue #16 RT-004)
      final tenantId = tenant?.id;
      if (tenantId == null) {
        throw Exception('Kein Tenant ausgewählt');
      }

      await supabase.from('tenants').update({
        'shortName': _shortNameController.text.trim(),
        'longName': _longNameController.text.trim(),
        'practiceStart': _practiceStartController.text.trim().isNotEmpty
            ? _practiceStartController.text.trim() : null,
        'practiceEnd': _practiceEndController.text.trim().isNotEmpty
            ? _practiceEndController.text.trim() : null,
        'seasonStart': _seasonStart?.toIso8601String().split('T')[0],
        'region': _selectedRegion.isNotEmpty ? _selectedRegion : null,
        'showHolidays': _showHolidays,
        'maintainTeachers': _maintainTeachers,
        'parents': _parents,
        'showMembersList': _showMembersList, // DB_FIX: column is camelCase
        'shift_excused_as_present': _shiftExcusedAsPresent, // SETTINGS2
        // ATTENDANCE_SIGNOUT
        'show_all_attendances': _showAllAttendances,
        // LOGIC_SETTINGS: Ionic — null when off, otherwise trimmed or default
        'show_all_attendances_info_text': normalizeShowAllInfoText(
          enabled: _showAllAttendances,
          text: _showAllInfoTextController.text,
          defaultText: defaultInfoText,
        ),
        // LOGIC_SETTINGS: Ionic filters empty reasons; empty list -> null
        'absence_reasons': normalizeReasons(_absenceReasons),
        'late_reasons': normalizeReasons(_lateReasons),
        // DUTY: only sent when the tenant uses the Dienstplan at all
        if (ref.read(hasDutyTypesProvider)) 'duty_view': _dutyView,
        'song_sharing_id': _songSharingEnabled ? (_songSharingId ?? const Uuid().v4()) : null,
        'register_id': _registrationEnabled ? (_registerId ?? const Uuid().v4()) : null,
        // Ionic general.page: registration off → no auto approve, no fields
        'auto_approve_registrations':
            _registrationEnabled ? _autoApproveRegistrations : false,
        'registration_fields':
            _registrationEnabled ? _selectedRegistrationFields : <String>[],
        // SETTINGS_EXT: additional_fields werden auf der Seite "Zusatzfelder" gepflegt
        'critical_rules': _criticalRules.map((r) => {
          'id': r.id,
          if (r.name != null) 'name': r.name,
          'attendance_type_ids': r.attendanceTypeIds,
          'statuses': r.statuses,
          'threshold_type': r.thresholdType.name,
          'threshold_value': r.thresholdValue,
          if (r.periodType != null) 'period_type': r.periodType!.name == 'allTime' ? 'all' : r.periodType!.name,
          if (r.periodDays != null) 'period_days': r.periodDays,
          'operator': r.operator == CriticalRuleOperator.and ? 'AND' : 'OR',
        }).toList(),
      }).eq('id', tenantId);

      // SETTINGS2: Ionic re-evaluates the Problemfall rules right away
      try {
        await supabase.functions.invoke('evaluate-critical-rules');
      } catch (e) {
        debugPrint('Could not trigger critical rules evaluation: $e');
      }

      // Refresh tenant data
      ref.invalidate(currentTenantProvider);
      ref.invalidate(userTenantsProvider);

      if (mounted) {
        setState(() => _hasChanges = false);
        // LOGIC_SETTINGS: Ionic success toast + alert with "Neu laden"
        ToastHelper.showSuccess(context, context.l10n.generalSettingsSaved);
        final reload = await showAppDialog<bool>(
          context: context,
          builder: (dialogContext) => AppAlertDialog(
            title: Text(dialogContext.l10n.generalSettingsSaved),
            content: Text(dialogContext.l10n.generalSettingsSavedReload),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(dialogContext.l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(dialogContext.l10n.generalSettingsReload),
              ),
            ],
          ),
        );
        if (reload == true) reloadPage();
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.generalSettingsSaveFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _selectSeasonStart() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _seasonStart ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('de', 'DE'),
    );
    if (picked != null) {
      // Fix double setState (Issue #13) - set both values in one setState
      setState(() {
        _seasonStart = picked;
        _hasChanges = true;
      });
    }
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final initialTime = _parseTime(controller.text) ?? const TimeOfDay(hour: 19, minute: 0);
    final picked = await showAppTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      controller.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _markChanged();
    }
  }

  TimeOfDay? _parseTime(String time) {
    if (time.isEmpty) return null;
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  List<Widget> _buildRegistrationFieldChips() {
    // Base fields: firstName and lastName are always required (disabled)
    final baseFields = [
      (key: 'firstName', label: context.l10n.peopleFirstName, required: true),
      (key: 'lastName', label: context.l10n.peopleLastName, required: true),
      (key: 'group', label: context.l10n.peopleGroup, required: true),
      (key: 'picture', label: context.l10n.settingsPassPhoto, required: false),
      (key: 'birthDate', label: context.l10n.peopleBirthday, required: false),
      (key: 'phone', label: context.l10n.settingsMobile, required: false),
    ];

    // Add any extra fields defined for the tenant
    final extraFieldChips = (ref.watch(currentTenantProvider)?.additionalFields ?? const []).map((f) =>
      (key: f.id, label: f.name, required: false),
    );

    final allFields = [...baseFields, ...extraFieldChips];

    return allFields.map((field) {
      final isSelected = _selectedRegistrationFields.contains(field.key);
      return FilterChip(
        label: Text(field.label),
        selected: isSelected,
        onSelected: field.required
            ? null // Cannot deselect required fields
            : (selected) {
                setState(() {
                  if (selected) {
                    _selectedRegistrationFields.add(field.key);
                  } else {
                    _selectedRegistrationFields.remove(field.key);
                  }
                });
                _markChanged();
              },
      );
    }).toList();
  }

  Future<void> _copyLink(String baseUrl, String? id) async {
    if (id == null) return;
    final link = '$baseUrl$id';
    try {
      await Clipboard.setData(ClipboardData(text: link));
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.settingsFlutterCopyLinkFailed);
      return;
    }
    if (mounted) {
      ToastHelper.showSuccess(context, context.l10n.settingsLinkCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showUnsavedChangesDialog();
      },
      // UX_SETTINGS (WAVE 8): ion-header collapse="condense" + arrow-back
      child: IonCondense(builder: (context, collapsed) => Scaffold(
      appBar: AppBar(
        title: IonCondenseTitle(context.l10n.settingsSettings, collapsed: collapsed),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_hasChanges) {
              _showUnsavedChangesDialog();
            } else {
              context.pop();
            }
          },
        ),
      ),
      // UX_SETTINGS: Ionic saves via FAB (save-outline)
      floatingActionButton: TabBarFab.wrap(_isLoading
          ? null
          : FloatingActionButton(
              onPressed: _isSaving ? null : _saveSettings,
              tooltip: context.l10n.commonSave,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: AppSpinner(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined),
            )),
      body: _isLoading
          ? const Center(child: AppSpinner())
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppDimensions.paddingM,
                  ionIsIos(context) ? 0 : AppDimensions.paddingM,
                  AppDimensions.paddingM,
                  scrollEndPadding(context, base: 16, fabRoom: 80),
                ),
                children: [
                  IonLargeTitle(context.l10n.settingsSettings, padding: const EdgeInsets.only(bottom: 4)),
                  if (ionIsIos(context)) const SizedBox(height: 16),
                  // UX_SETTINGS: sections in Ionic order (general.page.html)
                  // ============ ALLGEMEIN ============
                  SettingsListSection(
                    title: context.l10n.generalSettingsGeneral,
                    icons: false,
                    children: [
                      IonStackedField(
                        label: context.l10n.generalSettingsTenantName,
                        builder: (decoration) => TextFormField(
                          controller: _longNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: decoration,
                          onChanged: (_) => _markChanged(),
                        ),
                      ),
                      IonStackedField(
                        label: context.l10n.generalSettingsTenantShort,
                        helper: context.l10n.generalSettingsShortNameHelper,
                        builder: (decoration) => TextFormField(
                          controller: _shortNameController,
                          decoration: decoration,
                          validator: (v) => v?.trim().isEmpty ?? true ? context.l10n.generalSettingsShortNameEmpty : null,
                          onChanged: (_) => _markChanged(),
                        ),
                      ),
                    ],
                  ),

                  // ============ ANWESENHEITEN ============
                  SettingsListSection(
                    title: context.l10n.generalSettingsAttendance,
                    icons: false,
                    children: [
                      IonStackedValue(
                        label: context.l10n.generalSettingsSeasonStart,
                        value: _seasonStart != null
                            ? DateFormat(dateFmt()).format(_seasonStart!)
                            : context.l10n.personNotSet,
                        helper: context.l10n.generalSettingsSeasonHelper,
                        trailing: ionIsIos(context) ? null : const Icon(Icons.calendar_today_outlined),
                        onTap: _selectSeasonStart,
                      ),
                      // Flutter: Probenzeiten (Standardzeiten für neue Termine)
                      IonStackedField(
                        label: context.l10n.generalSettingsFlutterPracticeStart,
                        hint: '19:00',
                        builder: (decoration) => TextFormField(
                          controller: _practiceStartController,
                          decoration: decoration,
                          readOnly: true,
                          onTap: () => _selectTime(_practiceStartController),
                        ),
                      ),
                      IonStackedField(
                        label: context.l10n.generalSettingsFlutterPracticeEnd,
                        hint: '21:30',
                        builder: (decoration) => TextFormField(
                          controller: _practiceEndController,
                          decoration: decoration,
                          readOnly: true,
                          onTap: () => _selectTime(_practiceEndController),
                        ),
                      ),
                      SettingsListTile(
                        title: context.l10n.generalSettingsAttTypes,
                        onTap: () => context.push('/settings/types'),
                      ),
                      SettingsListTile(
                        title: context.l10n.generalSettingsShiftPlans,
                        onTap: () => context.push('/settings/shifts'),
                      ),
                      SettingsListTile(
                        title: context.l10n.generalSettingsBranding,
                        onTap: () => context.push('/settings/general/branding'),
                      ),
                      _toggle(
                        context.l10n.generalSettingsShiftPresent,
                        context.l10n.generalSettingsShiftPresentHelper,
                        _shiftExcusedAsPresent,
                        (v) => _shiftExcusedAsPresent = v,
                      ),
                      _toggle(
                        context.l10n.generalSettingsAllEvents,
                        context.l10n.generalSettingsAllEventsHelper,
                        _showAllAttendances,
                        (v) => _showAllAttendances = v,
                      ),
                      // DUTY: Dienstplan-Ansicht (only when a type uses Dienst-Modus)
                      if (ref.watch(hasDutyTypesProvider))
                        _toggle(
                          context.l10n.generalSettingsDutyView,
                          context.l10n.generalSettingsDutyViewHelper,
                          _dutyView,
                          (v) => _dutyView = v,
                        ),
                      if (_showAllAttendances)
                        IonStackedField(
                          label: context.l10n.generalSettingsForeignInfo,
                          hint: context.l10n.generalSettingsForeignInfoPh,
                          builder: (decoration) => TextFormField(
                            controller: _showAllInfoTextController,
                            decoration: decoration,
                            onChanged: (_) => _markChanged(),
                          ),
                        ),
                    ],
                  ),

                  // ============ ABWESENHEITS- & VERSPÄTUNGSGRÜNDE ============
                  SettingsListSection(
                    title: context.l10n.generalSettingsReasons,
                    icons: false,
                    children: [
                      ReasonsListEditor(
                        title: context.l10n.generalSettingsAbsenceReasons,
                        reasons: _absenceReasons,
                        defaults: EventListUtils.defaultAbsenceReasons,
                        onChanged: (list) {
                          setState(() => _absenceReasons = list);
                          _markChanged();
                        },
                      ),
                      ReasonsListEditor(
                        title: context.l10n.generalSettingsLateReasons,
                        reasons: _lateReasons,
                        defaults: EventListUtils.defaultLateReasons,
                        onChanged: (list) {
                          setState(() => _lateReasons = list);
                          _markChanged();
                        },
                      ),
                    ],
                  ),

                  // ============ REGISTRIERUNG ============
                  SettingsListSection(
                    title: context.l10n.generalSettingsRegistration,
                    icons: false,
                    children: [
                      _toggle(
                        context.l10n.generalSettingsAllowRegister,
                        context.l10n.generalSettingsRegisterHelper,
                        _registrationEnabled,
                        (v) {
                          _registrationEnabled = v;
                          if (v && _registerId == null) _registerId = const Uuid().v4();
                        },
                      ),
                      // SETTINGS2: Ionic noGroupsYet hint
                      if (_registrationEnabled &&
                          ref.watch(groupsProvider).hasValue &&
                          !_hasSelectableGroups)
                        Container(
                          color: AppColors.warning,
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber_outlined, color: Colors.black87),
                            title: Text(
                              context.l10n.generalSettingsNoGroupsYet,
                              style: TextStyle(color: Colors.black87),
                            ),
                          ),
                        ),
                      // Ionic: link only once saved (tenant.register_id)
                      if (_registrationEnabled &&
                          (ref.watch(currentTenantProvider)?.registerId ?? '').isNotEmpty)
                        ListTile(
                          title: Text(context.l10n.settingsCopyLink, style: const TextStyle(color: AppColors.primary)),
                          onTap: () => _copyLink('https://attendix.de/register/', _registerId),
                        ),
                      if (_registrationEnabled) ...[
                        _toggle(
                          context.l10n.generalSettingsAutoApprove,
                          context.l10n.generalSettingsAutoApproveHelper,
                          _autoApproveRegistrations,
                          (v) => _autoApproveRegistrations = v,
                        ),
                        _padded(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.generalSettingsRegisterFields,
                              style: ionIsIos(context)
                                  ? const TextStyle(fontSize: 14)
                                  : const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: AppDimensions.paddingS),
                            Wrap(
                              spacing: AppDimensions.paddingS,
                              runSpacing: AppDimensions.paddingXS,
                              children: _buildRegistrationFieldChips(),
                            ),
                            const SizedBox(height: AppDimensions.paddingS),
                            Text(
                              context.l10n.generalSettingsRegisterFieldsHint,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.medium),
                            ),
                          ],
                        )),
                      ],
                    ],
                  ),

                  // ============ WERK-DATENBANK ============
                  SettingsListSection(
                    title: context.l10n.generalSettingsSongDb,
                    icons: false,
                    children: [
                      _toggle(
                        context.l10n.generalSettingsShareSongs,
                        context.l10n.generalSettingsShareSongsHelper,
                        _songSharingEnabled,
                        (v) {
                          _songSharingEnabled = v;
                          if (v && _songSharingId == null) _songSharingId = const Uuid().v4();
                        },
                      ),
                      if ((ref.watch(currentTenantProvider)?.songSharingId ?? '').isNotEmpty)
                        ListTile(
                          title: Text(context.l10n.settingsCopyLink, style: const TextStyle(color: AppColors.primary)),
                          onTap: () => _copyLink('https://attendix.de/', _songSharingId),
                        ),
                    ],
                  ),

                  // ============ SONSTIGES ============
                  SettingsListSection(
                    title: context.l10n.generalSettingsOther,
                    icons: false,
                    children: [
                      Builder(builder: (context) {
                        final t = ref.watch(currentTenantProvider);
                        final total = (t?.additionalFields?.length ?? 0) + (t?.songAdditionalFields?.length ?? 0);
                        return SettingsListTile(
                          title: context.l10n.settingsExtraFields,
                          trailing: IonNote(
                            total == 0 ? context.l10n.generalSettingsNone : context.l10n.generalSettingsFlutterFieldsCount(total),
                          ),
                          onTap: () => context.push('/settings/general/extra-fields'),
                        );
                      }),
                      // SETTINGS2: Ionic "Lehrer pflegen" (only for orchestras)
                      if (ref.watch(currentTenantProvider)?.type == 'orchestra')
                        _toggle(
                          context.l10n.generalSettingsMaintainTeachers,
                          context.l10n.generalSettingsTeachersHelper,
                          _maintainTeachers,
                          (v) => _maintainTeachers = v,
                        ),
                      _toggle(
                        context.l10n.generalSettingsParentsFeature,
                        context.l10n.generalSettingsParentsHelper,
                        _parents,
                        (v) => _parents = v,
                      ),
                      _toggle(
                        context.l10n.generalSettingsMembersList,
                        context.l10n.generalSettingsMembersListHelper,
                        _showMembersList,
                        (v) => _showMembersList = v,
                      ),
                      _toggle(
                        context.l10n.generalSettingsShowHolidays,
                        context.l10n.generalSettingsHolidaysHelper,
                        _showHolidays,
                        (v) => _showHolidays = v,
                      ),
                      if (_showHolidays)
                        IonStackedField(
                          label: context.l10n.generalSettingsHolidayState,
                          builder: (decoration) => DropdownButtonFormField<String>(
                          value: _selectedRegion,
                          decoration: decoration,
                          items: _holidayRegions
                              .map((r) => DropdownMenuItem(
                                  value: r.$1,
                                  child: Text(r.$1.isEmpty ? context.l10n.generalSettingsFlutterNoHolidays : r.$2)))
                              .toList(),
                          onChanged: (v) {
                            setState(() => _selectedRegion = v ?? '');
                            _markChanged();
                          },
                        )),
                    ],
                  ),

                  // ============ PROBLEMFALL-REGELN ============
                  SettingsListSection(
                    title: context.l10n.generalSettingsCriticalRules,
                    icons: false,
                    headerAction: IconButton(
                      icon: const Icon(Icons.add, color: AppColors.primary),
                      tooltip: context.l10n.generalSettingsNewRule,
                      onPressed: _showAddCriticalRuleSheet,
                    ),
                    children: [
                      if (_criticalRules.isEmpty)
                        ListTile(
                          // Ionic: <ion-label><p> (grey 14px)
                          title: Text(
                            context.l10n.generalSettingsNoRules,
                            style: TextStyle(
                              fontSize: 14,
                              color: ionIsIos(context) ? IonIos.labelP(context) : AppColors.medium,
                            ),
                          ),
                        ),
                      for (var index = 0; index < _criticalRules.length; index++)
                        CriticalRuleCard(
                          rule: _criticalRules[index],
                          onEdit: () => _showEditCriticalRuleSheet(index),
                          onDelete: () => _confirmDeleteCriticalRule(index),
                        ),
                    ],
                  ),
                ],
              ),
            ),
    )),
    );
  }

  Widget _padded(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
        child: child,
      );

  /// Ionic `ion-toggle` with `helperText`.
  Widget _toggle(String title, String helper, bool value, void Function(bool) apply) => IonToggleItem(
        title: title,
        helper: helper,
        value: value,
        onChanged: (v) {
          setState(() => apply(v));
          _markChanged();
        },
      );

  // Critical rule methods
  Future<void> _showAddCriticalRuleSheet() async {
    // Ensure attendance types are loaded
    final attendanceTypes = await ref.read(attendanceTypesProvider.future);

    if (attendanceTypes.isEmpty) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.generalSettingsFlutterNoTypes);
      }
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      builder: (ctx) => CriticalRuleSheet(
        attendanceTypes: attendanceTypes,
        onSave: (rule) {
          setState(() {
            _criticalRules.add(rule);
            _markChanged();
          });
          ToastHelper.showSuccess(context, context.l10n.generalSettingsFlutterRuleAdded);
        },
      ),
    );
  }

  Future<void> _showEditCriticalRuleSheet(int index) async {
    final rule = _criticalRules[index];
    // Ensure attendance types are loaded
    final attendanceTypes = await ref.read(attendanceTypesProvider.future);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      builder: (ctx) => CriticalRuleSheet(
        rule: rule,
        attendanceTypes: attendanceTypes,
        onSave: (updatedRule) {
          setState(() {
            _criticalRules[index] = updatedRule;
            _markChanged();
          });
          ToastHelper.showSuccess(context, context.l10n.generalSettingsFlutterRuleUpdated);
        },
      ),
    );
  }

  Future<void> _confirmDeleteCriticalRule(int index) async {
    final rule = _criticalRules[index];
    final ruleName = rule.displayName;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.generalSettingsDeleteRule),
        content: Text(
          context.l10n.generalSettingsFlutterDeleteRuleNamed(ruleName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _criticalRules.removeAt(index);
        _markChanged();
      });
      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.generalSettingsFlutterRuleDeleted);
      }
    }
  }

  Future<void> _showUnsavedChangesDialog() async {
    final result = await showAppDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.rolePermUnsaved),
        content: Text(context.l10n.rolePermUnsavedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(context.l10n.rolePermDiscard),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
    if (result == null || result == 'cancel') return;
    if (result == 'save') {
      await _saveSettings();
    }
    if (mounted) {
      context.pop();
    }
  }
}

/// LOGIC_SETTINGS: Ionic saveGeneralSettings — empty/blank reasons are
/// filtered out; an empty result is stored as null.
List<String>? normalizeReasons(List<String> reasons) {
  final filtered = reasons.where((r) => r.trim().isNotEmpty).toList();
  return filtered.isEmpty ? null : filtered;
}

/// LOGIC_SETTINGS: Ionic saveGeneralSettings — `show_all_attendances_info_text`
/// is null when the feature is off, otherwise the trimmed text or the default.
String? normalizeShowAllInfoText({
  required bool enabled,
  required String text,
  required String defaultText,
}) {
  if (!enabled) return null;
  final trimmed = text.trim();
  return trimmed.isNotEmpty ? trimmed : defaultText;
}
