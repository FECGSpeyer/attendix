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
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/group_providers.dart'; // SETTINGS2
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/models/organisation/organisation.dart';
import '../widgets/critical_rule_card.dart';
import '../widgets/critical_rule_sheet.dart';

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
  bool _withExcuses = true;
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
      _withExcuses = tenant.withExcuses;
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
        ToastHelper.showError(context, 'Fehler beim Laden: $e');
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
    // SETTINGS2: Ionic saveGeneralSettings validation toasts
    if (_longNameController.text.trim().isEmpty) {
      ToastHelper.showError(context, 'Der Gruppenname darf nicht leer sein.');
      return;
    }
    if (_shortNameController.text.trim().isEmpty) {
      ToastHelper.showError(context, 'Der Kurzname darf nicht leer sein.');
      return;
    }
    if (_registrationEnabled) {
      final groups = await ref.read(groupsProvider.future);
      if (!mounted) return;
      if (!groups.any((g) => g.maingroup != true)) {
        ToastHelper.showError(
          context,
          'Registrierung kann nicht aktiviert werden: Bitte lege zuerst mindestens eine Gruppe an.',
        );
        return;
      }
    }
    if (!_formKey.currentState!.validate()) return;

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
        'withExcuses': _withExcuses,
        'parents': _parents,
        'show_members_list': _showMembersList,
        'shift_excused_as_present': _shiftExcusedAsPresent, // SETTINGS2
        // ATTENDANCE_SIGNOUT
        'show_all_attendances': _showAllAttendances,
        'show_all_attendances_info_text': _showAllInfoTextController.text.trim().isNotEmpty
            ? _showAllInfoTextController.text.trim()
            : null,
        'absence_reasons': _absenceReasons,
        'late_reasons': _lateReasons,
        // DUTY: only sent when the tenant uses the Dienstplan at all
        if (ref.read(hasDutyTypesProvider)) 'duty_view': _dutyView,
        'song_sharing_id': _songSharingEnabled ? (_songSharingId ?? const Uuid().v4()) : null,
        'register_id': _registrationEnabled ? (_registerId ?? const Uuid().v4()) : null,
        'auto_approve_registrations': _autoApproveRegistrations,
        'registration_fields': _registrationEnabled ? _selectedRegistrationFields : null,
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
          'enabled': r.enabled,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Einstellungen gespeichert. Bitte lade die Seite neu, um die Änderungen zu sehen.'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
        setState(() => _hasChanges = false);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler: $e');
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
    final picked = await showDatePicker(
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
    final picked = await showTimePicker(
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
      (key: 'firstName', label: 'Vorname', required: true),
      (key: 'lastName', label: 'Nachname', required: true),
      (key: 'group', label: 'Gruppe', required: true),
      (key: 'picture', label: 'Passbild', required: false),
      (key: 'birthDate', label: 'Geburtsdatum', required: false),
      (key: 'phone', label: 'Handynummer', required: false),
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
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ToastHelper.showSuccess(context, 'Link kopiert');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showUnsavedChangesDialog();
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Allgemeine Einstellungen'),
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
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Speichern'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                children: [
                  // Basic info section
                  _buildSectionHeader('Grunddaten'),
                  TextFormField(
                    controller: _shortNameController,
                    decoration: const InputDecoration(
                      labelText: 'Kurzname *',
                      helperText: 'Wird in der Navigation angezeigt',
                    ),
                    validator: (v) => v?.trim().isEmpty ?? true ? 'Erforderlich' : null,
                    onChanged: (_) => _markChanged(),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  TextFormField(
                    controller: _longNameController,
                    decoration: const InputDecoration(
                      labelText: 'Vollständiger Name',
                    ),
                    onChanged: (_) => _markChanged(),
                  ),

                  const SizedBox(height: AppDimensions.paddingXL),

                  // Season section
                  _buildSectionHeader('Saison'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Saisonstart'),
                    subtitle: Text(
                      _seasonStart != null
                          ? DateFormat('dd.MM.yyyy').format(_seasonStart!)
                          : 'Nicht festgelegt',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _selectSeasonStart,
                  ),

                  const SizedBox(height: AppDimensions.paddingXL),

                  // Practice times section
                  _buildSectionHeader('Probenzeiten'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _practiceStartController,
                          decoration: const InputDecoration(
                            labelText: 'Beginn',
                            hintText: '19:00',
                          ),
                          readOnly: true,
                          onTap: () => _selectTime(_practiceStartController),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.paddingM),
                      Expanded(
                        child: TextFormField(
                          controller: _practiceEndController,
                          decoration: const InputDecoration(
                            labelText: 'Ende',
                            hintText: '21:30',
                          ),
                          readOnly: true,
                          onTap: () => _selectTime(_practiceEndController),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.paddingXL),

                  // Holidays section
                  _buildSectionHeader('Feiertage'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Feiertage im Kalender anzeigen'),
                    subtitle: const Text('Feiertage werden im Kalender hervorgehoben'),
                    value: _showHolidays,
                    onChanged: (v) {
                      setState(() => _showHolidays = v);
                      _markChanged();
                    },
                  ),
                  if (_showHolidays)
                    DropdownButtonFormField<String>(
                      value: _selectedRegion,
                      decoration: const InputDecoration(
                        labelText: 'Bundesland',
                      ),
                      items: _holidayRegions.map((r) => DropdownMenuItem(
                        value: r.$1,
                        child: Text(r.$2),
                      )).toList(),
                      onChanged: (v) {
                        setState(() => _selectedRegion = v ?? '');
                        _markChanged();
                      },
                    ),

                  const SizedBox(height: AppDimensions.paddingXL),

                  // Features section
                  _buildSectionHeader('Funktionen'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Entschuldigungen'),
                    subtitle: const Text('Erlaubt "Entschuldigt" als Status'),
                    value: _withExcuses,
                    onChanged: (v) {
                      setState(() => _withExcuses = v);
                      _markChanged();
                    },
                  ),
                  // SETTINGS2: Ionic "Lehrer pflegen" (only for orchestras)
                  if (ref.watch(currentTenantProvider)?.type == 'orchestra')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Lehrer pflegen'),
                      subtitle: const Text('Aktivieren, um die Lehrer der Spieler verwalten zu können.'),
                      value: _maintainTeachers,
                      onChanged: (v) {
                        setState(() => _maintainTeachers = v);
                        _markChanged();
                      },
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Eltern-Modus'),
                    subtitle: const Text('Erlaubt Eltern ihre Kinder an-/abzumelden'),
                    value: _parents,
                    onChanged: (v) {
                      setState(() => _parents = v);
                      _markChanged();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mitgliederliste für alle'),
                    subtitle: const Text('Aktivieren, um Mitgliedern (Spieler, Helfer, Stimmführer) eine Übersicht aller Personen anzuzeigen'),
                    value: _showMembersList,
                    onChanged: (v) {
                      setState(() => _showMembersList = v);
                      _markChanged();
                    },
                  ),
                  // SETTINGS2: Ionic "Schicht-/Arbeitsbedingt = Anwesend"
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Schicht-/Arbeitsbedingt = Anwesend'),
                    subtitle: const Text(
                      'Aktivieren, um schicht- oder arbeitsbedingt entschuldigte Abwesenheiten '
                      'als anwesend für die prozentuale Berechnung zu werten.',
                    ),
                    value: _shiftExcusedAsPresent,
                    onChanged: (v) {
                      setState(() => _shiftExcusedAsPresent = v);
                      _markChanged();
                    },
                  ),
                  // ATTENDANCE_SIGNOUT: show all Termine for members
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alle Termine für Mitglieder sichtbar'),
                    subtitle: const Text(
                      'Aktivieren, damit Mitglieder auf der Abmelde-Seite alle Termine der Instanz '
                      'sehen können (nicht nur eigene). Eigene Termine werden hervorgehoben.',
                    ),
                    value: _showAllAttendances,
                    onChanged: (v) {
                      setState(() => _showAllAttendances = v);
                      _markChanged();
                    },
                  ),
                  if (_showAllAttendances)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
                      child: TextFormField(
                        controller: _showAllInfoTextController,
                        decoration: const InputDecoration(
                          labelText: 'Info-Text für fremde Termine',
                          hintText: 'Du bist bei diesem Termin nicht dabei.',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _markChanged(),
                      ),
                    ),

                  const SizedBox(height: AppDimensions.paddingXL),

                  // ATTENDANCE_SIGNOUT: absence / late reasons
                  _buildSectionHeader('Abwesenheits- & Verspätungsgründe'),
                  ReasonsListEditor(
                    title: 'Abwesenheitsgründe',
                    reasons: _absenceReasons,
                    defaults: EventListUtils.defaultAbsenceReasons,
                    onChanged: (list) {
                      setState(() => _absenceReasons = list);
                      _markChanged();
                    },
                  ),
                  ReasonsListEditor(
                    title: 'Verspätungsgründe',
                    reasons: _lateReasons,
                    defaults: EventListUtils.defaultLateReasons,
                    onChanged: (list) {
                      setState(() => _lateReasons = list);
                      _markChanged();
                    },
                  ),
                  // DUTY: Dienstplan-Ansicht (only when a type uses Dienst-Modus)
                  if (ref.watch(hasDutyTypesProvider))
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dienstplan-Ansicht für Meine Termine'),
                      subtitle: const Text(
                        '„Meine Termine“ zeigt für Personen aus einem Dienst-Team zuerst ihre Dienste, offene '
                        'Dienste und Zahlen statt der Anwesenheitsquote. Andere Termine stehen eingeklappt darunter.',
                      ),
                      value: _dutyView,
                      onChanged: (v) {
                        setState(() => _dutyView = v);
                        _markChanged();
                      },
                    ),

                  const SizedBox(height: AppDimensions.paddingXL),

                  // Song sharing section
                  _buildSectionHeader('Lied-Teilen'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktiviert'),
                    subtitle: const Text('Lieder öffentlich über Link teilen'),
                    value: _songSharingEnabled,
                    onChanged: (v) {
                      setState(() {
                        _songSharingEnabled = v;
                        if (v && _songSharingId == null) {
                          _songSharingId = const Uuid().v4();
                        }
                      });
                      _markChanged();
                    },
                  ),
                  if (_songSharingEnabled && _songSharingId != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sharing-Link'),
                      subtitle: Text(
                        'https://attendix.de/songs/$_songSharingId',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copyLink('https://attendix.de/songs/', _songSharingId),
                      ),
                    ),

                  const SizedBox(height: AppDimensions.paddingXL),

                  // Self-registration section
                  _buildSectionHeader('Selbst-Registrierung'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktiviert'),
                    subtitle: const Text('Neue Mitglieder können sich selbst registrieren'),
                    value: _registrationEnabled,
                    onChanged: (v) {
                      setState(() {
                        _registrationEnabled = v;
                        if (v && _registerId == null) {
                          _registerId = const Uuid().v4();
                        }
                      });
                      _markChanged();
                    },
                  ),
                  // SETTINGS2: Ionic noGroupsYet hint
                  if (_registrationEnabled &&
                      ref.watch(groupsProvider).hasValue &&
                      !_hasSelectableGroups)
                    Card(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      child: const ListTile(
                        leading: Icon(Icons.warning_amber_outlined, color: AppColors.warning),
                        title: Text(
                          'Es sind noch keine Gruppen vorhanden. Bitte lege zuerst mindestens eine '
                          'Gruppe an, bevor du die Registrierung aktivierst.',
                        ),
                      ),
                    ),
                  if (_registrationEnabled) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Registrierungs-Link'),
                      subtitle: Text(
                        'https://attendix.de/register/$_registerId',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copyLink('https://attendix.de/register/', _registerId),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Automatisch genehmigen'),
                      subtitle: const Text('Neue Registrierungen sofort freischalten'),
                      value: _autoApproveRegistrations,
                      onChanged: (v) {
                        setState(() => _autoApproveRegistrations = v);
                        _markChanged();
                      },
                    ),
                    const SizedBox(height: AppDimensions.paddingM),
                    const Text(
                      'Registrierungsfelder',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppDimensions.paddingXS),
                    Text(
                      'Alle ausgewählten Felder sind Pflichtfelder bei der Registrierung.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.medium,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    Wrap(
                      spacing: AppDimensions.paddingS,
                      runSpacing: AppDimensions.paddingXS,
                      children: _buildRegistrationFieldChips(),
                    ),
                  ],

                  const SizedBox(height: AppDimensions.paddingXL),

                  // SETTINGS_EXT: Zusatzfelder, Branding, Personen verknüpfen
                  _buildSectionHeader('Sonstiges'),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.dynamic_form_outlined),
                          title: const Text('Zusatzfelder'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if ((ref.watch(currentTenantProvider)?.additionalFields ?? const []).isEmpty)
                                const Text('Keine', style: TextStyle(color: AppColors.medium)),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => context.push('/settings/general/extra-fields'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.palette_outlined),
                          title: const Text('Branding'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/settings/general/branding'),
                        ),
                        if (ref.watch(currentOrganisationProvider).valueOrNull != null)
                          ListTile(
                            leading: const Icon(Icons.merge_type),
                            title: const Text('Personen verknüpfen'),
                            subtitle: const Text('Personen aus verschiedenen Instanzen miteinander verbinden'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/settings/general/link-persons'),
                          ),
                      ],
                    ),
                  ),
                  // END SETTINGS_EXT

                  const SizedBox(height: AppDimensions.paddingXL),

                  // Critical rules section
                  _buildSectionHeader('Problemfall-Regeln'),
                  Text(
                    'Definiere Regeln, wann Personen als Problemfall markiert werden.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.medium,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),

                  // List of critical rules
                  if (_criticalRules.isNotEmpty) ...[
                    ...List.generate(_criticalRules.length, (index) {
                      final rule = _criticalRules[index];
                      return CriticalRuleCard(
                        rule: rule,
                        onEdit: () => _showEditCriticalRuleSheet(index),
                        onDelete: () => _confirmDeleteCriticalRule(index),
                      );
                    }),
                  ],

                  // Add rule button
                  OutlinedButton.icon(
                    onPressed: _showAddCriticalRuleSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('Regel hinzufügen'),
                  ),

                  const SizedBox(height: AppDimensions.paddingXL),

                  // Organisation section
                  _buildSectionHeader('Organisation'),
                  _buildOrganisationSection(),

                  const SizedBox(height: AppDimensions.paddingXL),
                ],
              ),
            ),
    ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildOrganisationSection() {
    final currentOrgAsync = ref.watch(currentOrganisationProvider);

    return currentOrgAsync.when(
      loading: () => const Card(
        child: ListTile(
          leading: CircularProgressIndicator(),
          title: Text('Lade Organisation...'),
        ),
      ),
      error: (e, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.error, color: AppColors.danger),
          title: const Text('Fehler beim Laden'),
          subtitle: Text('$e'),
        ),
      ),
      data: (organisation) => Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.corporate_fare,
                color: organisation != null ? AppColors.primary : AppColors.medium,
              ),
              title: Text(organisation?.name ?? 'Keine Organisation'),
              subtitle: Text(
                organisation != null
                    ? 'Verknüpft mit Organisation'
                    : 'Verknüpfe diesen Mandanten mit einer Organisation, um ihn mit anderen Mandanten zu gruppieren.',
              ),
              trailing: organisation != null
                  ? IconButton(
                      icon: Icon(Icons.link_off, color: AppColors.danger),
                      onPressed: () => _unlinkOrganisation(organisation),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: AppDimensions.paddingM,
                right: AppDimensions.paddingM,
                bottom: AppDimensions.paddingM,
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showOrganisationDialog(organisation),
                  icon: Icon(organisation != null ? Icons.swap_horiz : Icons.add_link),
                  label: Text(organisation != null ? 'Organisation wechseln' : 'Mit Organisation verknüpfen'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOrganisationDialog(Organisation? currentOrg) async {
    final userOrgsAsync = ref.read(userOrganisationsProvider);

    final organisations = await userOrgsAsync.when(
      data: (orgs) async => orgs,
      loading: () async => <Organisation>[],
      error: (_, __) async => <Organisation>[],
    );

    if (!mounted) return;

    final selectedOrgId = await showDialog<int?>(
      context: context,
      builder: (ctx) {
        int? selected = currentOrg?.id;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Organisation auswählen'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (organisations.isEmpty)
                  const Text('Keine existierenden Organisationen gefunden. Erstelle eine neue.')
                else ...[
                  ...organisations.map((org) => RadioListTile<int?>(
                    value: org.id,
                    groupValue: selected,
                    title: Text(org.name),
                    onChanged: (v) => setDialogState(() => selected = v),
                  )),
                  const Divider(),
                ],
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Neue Organisation erstellen'),
                  onTap: () {
                    Navigator.of(ctx).pop(-1); // Special value for "create new"
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Abbrechen'),
              ),
              if (organisations.isNotEmpty)
                ElevatedButton(
                  onPressed: selected != null && selected != currentOrg?.id
                      ? () => Navigator.of(ctx).pop(selected)
                      : null,
                  child: const Text('Verknüpfen'),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;

    if (selectedOrgId == -1) {
      // Create new organisation
      await _showCreateOrganisationDialog();
    } else if (selectedOrgId != null) {
      // Link to existing organisation
      final notifier = ref.read(organisationNotifierProvider.notifier);
      final success = await notifier.linkCurrentTenant(selectedOrgId);
      if (mounted) {
        if (success) {
          ToastHelper.showSuccess(context, 'Organisation verknüpft');
        } else {
          ToastHelper.showError(context, 'Fehler beim Verknüpfen');
        }
      }
    }
  }

  Future<void> _showCreateOrganisationDialog() async {
    final nameController = TextEditingController();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Neue Organisation'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name der Organisation',
              hintText: 'z.B. Musikverein Musterstadt',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Erstellen & Verknüpfen'),
            ),
          ],
        ),
      );

      if (result == true && mounted) {
        final name = nameController.text.trim();
        if (name.isEmpty) {
          ToastHelper.showError(context, 'Name ist erforderlich');
          return;
        }

        final notifier = ref.read(organisationNotifierProvider.notifier);
        final org = await notifier.create(name);
        if (org != null && mounted) {
          await notifier.linkCurrentTenant(org.id!);
          if (mounted) {
            ToastHelper.showSuccess(
                context, 'Organisation erstellt und verknüpft');
          }
        }
      }
    } finally {
      // FN-001: Dispose controller
      nameController.dispose();
    }
  }

  Future<void> _unlinkOrganisation(Organisation organisation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verknüpfung aufheben?'),
        content: Text(
          'Möchtest du die Verknüpfung mit "${organisation.name}" aufheben?\n\n'
          'Wenn keine anderen Mandanten mehr in dieser Organisation sind, '
          'wird die Organisation automatisch gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Aufheben'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final notifier = ref.read(organisationNotifierProvider.notifier);
      final success = await notifier.unlinkCurrentTenant(organisation.id!);
      if (mounted) {
        if (success) {
          ToastHelper.showSuccess(context, 'Verknüpfung aufgehoben');
        } else {
          ToastHelper.showError(context, 'Fehler beim Aufheben');
        }
      }
    }
  }

  // Critical rule methods
  Future<void> _showAddCriticalRuleSheet() async {
    // Ensure attendance types are loaded
    final attendanceTypes = await ref.read(attendanceTypesProvider.future);

    if (attendanceTypes.isEmpty) {
      if (mounted) {
        ToastHelper.showError(context, 'Keine Terminarten vorhanden');
      }
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CriticalRuleSheet(
        attendanceTypes: attendanceTypes,
        onSave: (rule) {
          setState(() {
            _criticalRules.add(rule);
            _markChanged();
          });
          ToastHelper.showSuccess(context, 'Regel hinzugefügt');
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
      isScrollControlled: true,
      builder: (ctx) => CriticalRuleSheet(
        rule: rule,
        attendanceTypes: attendanceTypes,
        onSave: (updatedRule) {
          setState(() {
            _criticalRules[index] = updatedRule;
            _markChanged();
          });
          ToastHelper.showSuccess(context, 'Regel aktualisiert');
        },
      ),
    );
  }

  Future<void> _confirmDeleteCriticalRule(int index) async {
    final rule = _criticalRules[index];
    final ruleName = rule.displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regel löschen?'),
        content: Text(
          'Möchtest du die Regel "$ruleName" wirklich löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
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
        ToastHelper.showSuccess(context, 'Regel gelöscht');
      }
    }
  }

  Future<void> _showUnsavedChangesDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ungespeicherte Änderungen'),
        content: const Text('Du hast ungespeicherte Änderungen. Was möchtest du tun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Verwerfen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('Speichern'),
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
