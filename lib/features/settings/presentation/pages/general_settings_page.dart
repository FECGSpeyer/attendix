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
import '../../../../core/providers/organisation_providers.dart';
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

  // Extra fields
  List<ExtraField> _extraFields = [];
  Set<String> _originalExtraFieldIds = {};

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
      _extraFields = List.from(tenant.additionalFields ?? []);
      _originalExtraFieldIds = _extraFields.map((f) => f.id).toSet();
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

  Future<void> _saveSettings() async {
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
        // ATTENDANCE_SIGNOUT
        'show_all_attendances': _showAllAttendances,
        'show_all_attendances_info_text': _showAllInfoTextController.text.trim().isNotEmpty
            ? _showAllInfoTextController.text.trim()
            : null,
        'absence_reasons': _absenceReasons,
        'late_reasons': _lateReasons,
        'song_sharing_id': _songSharingEnabled ? (_songSharingId ?? const Uuid().v4()) : null,
        'register_id': _registrationEnabled ? (_registerId ?? const Uuid().v4()) : null,
        'auto_approve_registrations': _autoApproveRegistrations,
        'registration_fields': _registrationEnabled ? _selectedRegistrationFields : null,
        'additional_fields': _extraFields.map((f) => {
          'id': f.id,
          'name': f.name,
          'type': f.type,
          'defaultValue': f.defaultValue,
          if (f.options != null) 'options': f.options,
        }).toList(),
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

      // Refresh tenant data
      ref.invalidate(currentTenantProvider);
      ref.invalidate(userTenantsProvider);

      // B7-017: Sanitize player additional_fields for removed fields
      final currentFieldIds = _extraFields.map((f) => f.id).toSet();
      final removedFieldIds = _originalExtraFieldIds.difference(currentFieldIds);
      if (removedFieldIds.isNotEmpty) {
        await _sanitizePlayerFields(removedFieldIds, tenantId);
        _originalExtraFieldIds = currentFieldIds;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Einstellungen gespeichert. Lade die App neu, damit alle Änderungen wirksam werden.'),
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
    final extraFieldChips = _extraFields.map((f) =>
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dirigenten verwalten'),
                    subtitle: const Text('Separate Dirigenten-Liste führen'),
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

                  // Extra fields section
                  _buildSectionHeader('Zusatzfelder für Personen'),
                  Text(
                    'Definiere zusätzliche Felder für Personendaten.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.medium,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),

                  // List of extra fields
                  if (_extraFields.isNotEmpty) ...[
                    ...List.generate(_extraFields.length, (index) {
                      final field = _extraFields[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
                        child: ListTile(
                          leading: Icon(_getFieldTypeIcon(field.type)),
                          title: Text(field.name),
                          subtitle: Text(
                            field.type == 'select' && field.options != null
                                ? '${_getFieldTypeLabel(field.type)} (${field.options!.length} Optionen)'
                                : _getFieldTypeLabel(field.type),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditExtraFieldDialog(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: AppColors.danger),
                                onPressed: () => _confirmDeleteExtraField(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],

                  // Add field button
                  OutlinedButton.icon(
                    onPressed: _showAddExtraFieldDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Feld hinzufügen'),
                  ),

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

  // Extra field helper methods
  IconData _getFieldTypeIcon(String type) {
    switch (type) {
      case 'text':
        return Icons.text_fields;
      case 'textarea':
        return Icons.notes;
      case 'number':
        return Icons.numbers;
      case 'date':
        return Icons.calendar_today;
      case 'boolean':
        return Icons.toggle_on;
      case 'select':
        return Icons.list;
      default:
        return Icons.text_fields;
    }
  }

  String _getFieldTypeLabel(String type) {
    switch (type) {
      case 'text':
        return 'Text';
      case 'textarea':
        return 'Mehrzeiliger Text';
      case 'number':
        return 'Zahl';
      case 'date':
        return 'Datum';
      case 'boolean':
        return 'Ja/Nein';
      case 'select':
        return 'Auswahl';
      default:
        return type;
    }
  }

  String _generateFieldId(String name) {
    // Generate base ID from name (Issue #10)
    String baseId = name.trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');

    // Handle empty base ID
    if (baseId.isEmpty) baseId = 'field';

    // Add counter if collision exists
    String finalId = baseId;
    int counter = 1;
    while (_extraFields.any((f) => f.id == finalId)) {
      finalId = '${baseId}_$counter';
      counter++;
    }
    return finalId;
  }

  Future<void> _showAddExtraFieldDialog() async {
    String selectedType = 'text';
    final nameController = TextEditingController();
    List<String> options = [];
    final optionController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: AppDimensions.paddingM,
            right: AppDimensions.paddingM,
            top: AppDimensions.paddingM,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Neues Zusatzfeld',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingM),

              // Type selector
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Feldtyp',
                ),
                items: const [
                  DropdownMenuItem(value: 'text', child: Text('Text')),
                  DropdownMenuItem(value: 'textarea', child: Text('Mehrzeiliger Text')),
                  DropdownMenuItem(value: 'number', child: Text('Zahl')),
                  DropdownMenuItem(value: 'date', child: Text('Datum')),
                  DropdownMenuItem(value: 'boolean', child: Text('Ja/Nein')),
                  DropdownMenuItem(value: 'select', child: Text('Auswahl')),
                ],
                onChanged: (v) {
                  setSheetState(() {
                    selectedType = v ?? 'text';
                    options = [];
                  });
                },
              ),
              const SizedBox(height: AppDimensions.paddingM),

              // Name input
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Feldname *',
                  hintText: 'z.B. Mitgliedsnummer',
                ),
                autofocus: true,
              ),
              const SizedBox(height: AppDimensions.paddingM),

              // Options for select type
              if (selectedType == 'select') ...[
                Text(
                  'Optionen',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: AppDimensions.paddingS),
                ...options.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.paddingXS),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.value)),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        onPressed: () {
                          setSheetState(() => options.removeAt(entry.key));
                        },
                      ),
                    ],
                  ),
                )),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: optionController,
                        decoration: const InputDecoration(
                          hintText: 'Neue Option',
                          isDense: true,
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            setSheetState(() {
                              options.add(value.trim());
                              optionController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (optionController.text.trim().isNotEmpty) {
                          setSheetState(() {
                            options.add(optionController.text.trim());
                            optionController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.paddingM),
              ],

              // Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ToastHelper.showError(ctx, 'Bitte gib einen Namen ein');
                      return;
                    }

                    final id = _generateFieldId(name);
                    if (_extraFields.any((f) => f.id == id)) {
                      ToastHelper.showError(ctx, 'Ein Feld mit dieser ID existiert bereits');
                      return;
                    }

                    if (selectedType == 'select' && options.isEmpty) {
                      ToastHelper.showError(ctx, 'Bitte füge mindestens eine Option hinzu');
                      return;
                    }

                    dynamic defaultValue;
                    switch (selectedType) {
                      case 'text':
                      case 'textarea':
                        defaultValue = '';
                        break;
                      case 'number':
                        defaultValue = 0;
                        break;
                      case 'boolean':
                        defaultValue = false;
                        break;
                      case 'date':
                        defaultValue = DateTime.now().toIso8601String().split('T')[0];
                        break;
                      case 'select':
                        // Safe access with guard (Issue #7)
                        defaultValue = options.isNotEmpty ? options.first : '';
                        break;
                    }

                    setState(() {
                      _extraFields.add(ExtraField(
                        id: id,
                        name: name,
                        type: selectedType,
                        defaultValue: defaultValue,
                        options: selectedType == 'select' ? options : null,
                      ));
                      _markChanged();
                    });

                    Navigator.of(ctx).pop();
                    if (context.mounted) {
                      ToastHelper.showSuccess(context, 'Feld hinzugefügt');
                    }
                  },
                  child: const Text('Feld hinzufügen'),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingM),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      // Dispose controllers to prevent memory leak (Issue #22)
      nameController.dispose();
      optionController.dispose();
    });
  }

  Future<void> _showEditExtraFieldDialog(int index) async {
    final field = _extraFields[index];
    final nameController = TextEditingController(text: field.name);
    List<String> options = List.from(field.options ?? []);
    final optionController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: AppDimensions.paddingM,
            right: AppDimensions.paddingM,
            top: AppDimensions.paddingM,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Zusatzfeld bearbeiten',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingM),

              // Type (read-only)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Feldtyp',
                ),
                child: Row(
                  children: [
                    Icon(_getFieldTypeIcon(field.type), size: 20),
                    const SizedBox(width: AppDimensions.paddingS),
                    Text(_getFieldTypeLabel(field.type)),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.paddingM),

              // Name input
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Feldname *',
                ),
              ),
              const SizedBox(height: AppDimensions.paddingM),

              // Options for select type
              if (field.type == 'select') ...[
                Text(
                  'Optionen',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: AppDimensions.paddingS),
                ...options.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.paddingXS),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.value)),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        onPressed: options.length > 1 ? () {
                          setSheetState(() => options.removeAt(entry.key));
                        } : null,
                      ),
                    ],
                  ),
                )),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: optionController,
                        decoration: const InputDecoration(
                          hintText: 'Neue Option',
                          isDense: true,
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            setSheetState(() {
                              options.add(value.trim());
                              optionController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (optionController.text.trim().isNotEmpty) {
                          setSheetState(() {
                            options.add(optionController.text.trim());
                            optionController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.paddingM),
              ],

              // Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ToastHelper.showError(ctx, 'Bitte gib einen Namen ein');
                      return;
                    }

                    if (field.type == 'select' && options.isEmpty) {
                      ToastHelper.showError(ctx, 'Mindestens eine Option erforderlich');
                      return;
                    }

                    setState(() {
                      _extraFields[index] = ExtraField(
                        id: field.id, // Keep original ID
                        name: name,
                        type: field.type,
                        // Safe access with guard (Issue #7)
                        defaultValue: field.type == 'select' && options.isNotEmpty
                            ? options.first
                            : field.defaultValue,
                        options: field.type == 'select' ? options : null,
                      );
                      _markChanged();
                    });

                    Navigator.of(ctx).pop();
                    if (context.mounted) {
                      ToastHelper.showSuccess(context, 'Feld aktualisiert');
                    }
                  },
                  child: const Text('Speichern'),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingM),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      // Dispose controllers to prevent memory leak (Issue #22)
      nameController.dispose();
      optionController.dispose();
    });
  }

  Future<void> _confirmDeleteExtraField(int index) async {
    final field = _extraFields[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zusatzfeld löschen?'),
        content: Text('Möchtest du das Feld "${field.name}" wirklich löschen? '
            'Die Werte dieses Feldes werden bei allen Personen entfernt.'),
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
        _extraFields.removeAt(index);
        _markChanged();
      });
      if (mounted) {
        ToastHelper.showSuccess(context, 'Feld gelöscht');
      }
    }
  }

  /// B7-017: Remove stale field keys from all player additional_fields
  Future<void> _sanitizePlayerFields(Set<String> removedFieldIds, int tenantId) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      // Fetch all players with non-null additional_fields
      final response = await supabase
          .from('player')
          .select('id, additional_fields')
          .eq('tenantId', tenantId)
          .not('additional_fields', 'is', null);

      final players = response as List;
      for (final player in players) {
        final fields = player['additional_fields'] as Map<String, dynamic>?;
        if (fields == null) continue;

        final cleaned = Map<String, dynamic>.from(fields);
        var changed = false;
        for (final removedId in removedFieldIds) {
          if (cleaned.containsKey(removedId)) {
            cleaned.remove(removedId);
            changed = true;
          }
        }

        if (changed) {
          await supabase
              .from('player')
              .update({'additional_fields': cleaned.isEmpty ? null : cleaned})
              .eq('id', player['id'])
              .eq('tenantId', tenantId);
        }
      }
    } catch (e) {
      debugPrint('Error sanitizing player fields: $e');
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
