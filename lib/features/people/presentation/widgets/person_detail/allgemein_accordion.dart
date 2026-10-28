import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/providers/group_providers.dart';
import '../../../../../core/providers/parent_providers.dart';
import '../../../../../core/providers/shift_providers.dart';
import '../../../../../core/providers/teacher_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/tenant_label_utils.dart';
import '../../../../../data/models/parent/parent_model.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../data/models/shift/shift_plan.dart';
import '../../../../../data/models/tenant/tenant.dart';
import '../../../../../shared/widgets/editable/editable_info_row.dart';
import '../../../../../shared/widgets/sheets/field_editor_sheet.dart';
import '../../../../../shared/widgets/sheets/selection_sheet.dart';

/// Callback type for person field changes.
typedef PersonFieldChanged = void Function(String field, dynamic value);

/// Accordion widget displaying general person information with inline editing.
class AllgemeinAccordion extends ConsumerWidget {
  const AllgemeinAccordion({
    super.key,
    required this.person,
    required this.isExpanded,
    required this.onToggle,
    required this.onFieldChanged,
    required this.canEdit,
    this.selectedGroupId,
    this.selectedTeacherId,
    this.selectedShiftId,
    this.selectedShiftName,
    this.shiftStart,
    this.selectedParentId,
    this.isLeader,
    this.hasTeacher,
    this.additionalFieldValues,
  });

  final Person person;
  final bool isExpanded;
  final VoidCallback onToggle;
  final PersonFieldChanged onFieldChanged;
  final bool canEdit;

  // Editable state values (passed from parent to allow draft state)
  final int? selectedGroupId;
  final int? selectedTeacherId;
  final String? selectedShiftId;
  final String? selectedShiftName;
  final DateTime? shiftStart;
  final int? selectedParentId;
  final bool? isLeader;
  final bool? hasTeacher;
  final Map<String, dynamic>? additionalFieldValues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(currentTenantProvider);
    final extraFields = tenant?.additionalFields ?? [];
    final additionalFields = additionalFieldValues ?? person.additionalFields ?? {};

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Allgemein',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: onToggle,
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM,
                0,
                AppDimensions.paddingM,
                AppDimensions.paddingM,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name fields
                  _buildNameFields(context),
                  const Divider(height: 24),

                  // Notes
                  _buildNotesField(context),

                  // Group
                  _buildGroupField(context, ref),

                  // Phone
                  _buildPhoneField(context),

                  // Birthday
                  if (person.birthday != null || canEdit)
                    _buildDateField(
                      context,
                      icon: Icons.cake,
                      label: 'Geburtsdatum',
                      value: person.birthday,
                      fieldKey: 'birthday',
                      highlight: !person.correctBirthday,
                      highlightColor: AppColors.warning,
                    ),

                  // Plays Since
                  if (person.playsSince != null || canEdit)
                    _buildDateField(
                      context,
                      icon: Icons.music_note,
                      label: 'Spielt auf dem Instrument seit',
                      value: person.playsSince,
                      fieldKey: 'playsSince',
                    ),

                  // Joined
                  if (person.joined != null || canEdit)
                    _buildDateField(
                      context,
                      icon: Icons.login,
                      label: 'Beigetreten am',
                      value: person.joined,
                      fieldKey: 'joined',
                    ),

                  // Is Leader toggle
                  _buildIsLeaderField(context),

                  // Has Teacher toggle
                  _buildHasTeacherField(context, ref),

                  // Shift Plan
                  _buildShiftPlanField(context, ref),

                  // Parent
                  _buildParentField(context, ref),

                  // Other Exercise
                  if (person.otherExercise != null || canEdit)
                    _buildOtherExerciseField(context),

                  // Choir-specific: Stimmumfang (range)
                  if (tenant != null && tenant.type == 'choir')
                    _buildRangeField(context),

                  // Choir-specific: Instrumente
                  if (tenant != null && tenant.type == 'choir')
                    _buildInstrumentsField(context),

                  // Non-general: Prüfling (examinee)
                  if (tenant != null && tenant.type != 'general')
                    _buildExamineeField(context),

                  // Non-general: Testergebnis (testResult)
                  if (tenant != null && tenant.type != 'general')
                    _buildTestResultField(context),

                  // Extra Fields
                  if (extraFields.isNotEmpty) ...[
                    const Divider(height: 32),
                    Text(
                      'Zusatzfelder',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    ...extraFields.map(
                      (field) => _buildExtraField(context, field, additionalFields),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNameFields(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: EditableInfoRow(
            icon: Icons.person,
            label: 'Vorname',
            value: person.firstName,
            editable: canEdit,
            onEdit: () => _editTextField(
              context,
              title: 'Vorname',
              initialValue: person.firstName,
              fieldKey: 'firstName',
              textCapitalization: TextCapitalization.words,
              validator: (v) => v?.isEmpty ?? true ? 'Pflichtfeld' : null,
            ),
          ),
        ),
        Expanded(
          child: EditableInfoRow(
            icon: Icons.person_outline,
            label: 'Nachname',
            value: person.lastName,
            editable: canEdit,
            onEdit: () => _editTextField(
              context,
              title: 'Nachname',
              initialValue: person.lastName,
              fieldKey: 'lastName',
              textCapitalization: TextCapitalization.words,
              validator: (v) => v?.isEmpty ?? true ? 'Pflichtfeld' : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField(BuildContext context) {
    final notes = person.notes;
    if (notes == null && !canEdit) return const SizedBox.shrink();

    return EditableInfoRow(
      icon: Icons.notes,
      label: 'Notizen',
      value: notes ?? 'Keine Notizen',
      editable: canEdit,
      onEdit: () => _editTextField(
        context,
        title: 'Notizen',
        initialValue: notes ?? '',
        fieldKey: 'notes',
        maxLines: 4,
        hint: 'Notizen zur Person...',
      ),
    );
  }

  Widget _buildGroupField(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsMapProvider);
    final currentGroupId = selectedGroupId ?? person.instrument;
    final tenantType = ref.watch(currentTenantProvider)?.type;

    return groupsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Fehler: $e'),
      data: (groups) {
        final groupName = currentGroupId != null
            ? groups[currentGroupId] ?? 'Unbekannt'
            : 'Nicht zugewiesen';

        return EditableInfoRow(
          icon: Icons.group,
          label: groupLabel(tenantType),
          value: groupName,
          editable: canEdit,
          onEdit: () async {
            final items = groups.entries
                .map((e) => SelectionItem(value: e.key, label: e.value))
                .toList();

            final result = await SelectionSheet.show<int>(
              context,
              title: '${groupLabel(tenantType)} auswählen',
              items: items,
              selectedValue: currentGroupId,
              noneLabel: 'Keine ${groupLabel(tenantType)}',
              icon: Icons.group,
            );

            if (result != null) {
              onFieldChanged(
                'instrument',
                result.isNone ? null : result.value,
              );
            }
          },
        );
      },
    );
  }

  Widget _buildPhoneField(BuildContext context) {
    final phone = person.phone;
    if (phone == null && !canEdit) return const SizedBox.shrink();

    return EditableInfoRow(
      icon: Icons.phone,
      label: 'Telefon',
      value: phone ?? 'Nicht angegeben',
      editable: canEdit,
      onTap: phone != null ? () => _launchPhone(phone) : null,
      onEdit: () => _editTextField(
        context,
        title: 'Telefon',
        initialValue: phone ?? '',
        fieldKey: 'phone',
        keyboardType: TextInputType.phone,
        icon: Icons.phone,
      ),
    );
  }

  Widget _buildDateField(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String? value,
    required String fieldKey,
    bool highlight = false,
    Color? highlightColor,
  }) {
    final displayValue = value != null ? _formatDate(value) : 'Nicht angegeben';

    return EditableInfoRow(
      icon: icon,
      label: label,
      value: displayValue,
      editable: canEdit,
      highlight: highlight,
      highlightColor: highlightColor,
      onEdit: () async {
        final initialDate = value != null ? DateTime.tryParse(value) : null;
        final date = await DateEditorSheet.show(
          context,
          title: label,
          initialDate: initialDate,
          lastDate: DateTime.now(),
        );
        if (date != null) {
          onFieldChanged(fieldKey, date.toIso8601String());
        }
      },
    );
  }

  Widget _buildIsLeaderField(BuildContext context) {
    final value = isLeader ?? person.isLeader;

    return EditableToggleRow(
      icon: Icons.star,
      label: 'Stimmführer',
      value: value,
      editable: canEdit,
      onChanged: (v) => onFieldChanged('isLeader', v),
    );
  }

  Widget _buildHasTeacherField(BuildContext context, WidgetRef ref) {
    final hasTeacherValue = hasTeacher ?? person.hasTeacher;
    final teacherId = selectedTeacherId ?? person.teacher;

    return Column(
      children: [
        EditableToggleRow(
          icon: Icons.school,
          label: 'Spielt beim Lehrer',
          value: hasTeacherValue,
          editable: canEdit,
          onChanged: (v) {
            onFieldChanged('hasTeacher', v);
            if (!v) {
              onFieldChanged('teacher', null);
            }
          },
        ),
        if (hasTeacherValue)
          _buildTeacherField(context, ref, teacherId),
      ],
    );
  }

  Widget _buildTeacherField(BuildContext context, WidgetRef ref, int? teacherId) {
    final teachersAsync = ref.watch(teachersProvider);

    return teachersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppDimensions.paddingM),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Fehler: $e'),
      data: (teachers) {
        final teacher = teachers.where((t) => t.id == teacherId).firstOrNull;
        final teacherName = teacher?.name ?? 'Nicht ausgewählt';

        return Padding(
          padding: const EdgeInsets.only(left: AppDimensions.paddingL),
          child: EditableInfoRow(
            icon: Icons.person,
            label: 'Lehrer',
            value: teacherName,
            editable: canEdit,
            onEdit: () async {
              final items = teachers
                  .map((t) => SelectionItem(value: t.id!, label: t.name))
                  .toList();

              final result = await SelectionSheet.show<int>(
                context,
                title: 'Lehrer auswählen',
                items: items,
                selectedValue: teacherId,
                noneLabel: 'Kein Lehrer',
                icon: Icons.school,
              );

              if (result != null) {
                onFieldChanged(
                  'teacher',
                  result.isNone ? null : result.value,
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildShiftPlanField(BuildContext context, WidgetRef ref) {
    final shiftsAsync = ref.watch(shiftsProvider);
    final currentShiftId = selectedShiftId ?? person.shiftId;

    return shiftsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Fehler: $e'),
      data: (shifts) {
        final shift = shifts.where((s) => s.id == currentShiftId).firstOrNull;
        final shiftName = shift?.name ?? 'Kein Schichtplan';

        return Column(
          children: [
            EditableInfoRow(
              icon: Icons.schedule,
              label: 'Schichtplan',
              value: shiftName,
              editable: canEdit,
              onEdit: () async {
                final items = shifts
                    .map((s) => SelectionItem(value: s.id!, label: s.name))
                    .toList();

                final result = await SelectionSheet.show<String>(
                  context,
                  title: 'Schichtplan auswählen',
                  items: items,
                  selectedValue: currentShiftId,
                  noneLabel: 'Kein Schichtplan',
                  icon: Icons.schedule,
                );

                if (result != null) {
                  onFieldChanged(
                    'shiftId',
                    result.isNone ? null : result.value,
                  );
                  // Reset shift name and start when shift changes
                  onFieldChanged('shiftName', null);
                  onFieldChanged('shiftStart', null);
                }
              },
            ),
            // Show sub-shift selection if shift has named shifts
            if (shift != null && shift.hasNamedShifts)
              _buildShiftNameField(context, shift),
            if (shift != null && !shift.hasNamedShifts)
              _buildShiftStartField(context),
          ],
        );
      },
    );
  }

  Widget _buildShiftNameField(BuildContext context, dynamic shift) {
    final currentShiftName = selectedShiftName ?? person.shiftName;
    final uniqueShiftNames = shift.shifts
        .map((s) => s.name as String)
        .toSet()
        .toList();

    return Padding(
      padding: const EdgeInsets.only(left: AppDimensions.paddingL),
      child: EditableInfoRow(
        icon: Icons.access_time,
        label: 'Schicht',
        value: currentShiftName ?? 'Nicht ausgewählt',
        editable: canEdit,
        onEdit: () async {
          final items = uniqueShiftNames
              .map((name) => SelectionItem(value: name, label: name))
              .toList();

          final result = await SelectionSheet.show<String>(
            context,
            title: 'Schicht auswählen',
            items: items,
            selectedValue: currentShiftName,
            noneLabel: 'Keine Schicht',
            icon: Icons.access_time,
          );

          if (result != null) {
            onFieldChanged(
              'shiftName',
              result.isNone ? null : result.value,
            );
          }
        },
      ),
    );
  }

  Widget _buildShiftStartField(BuildContext context) {
    final currentShiftStart = shiftStart ??
        (person.shiftStart != null ? DateTime.tryParse(person.shiftStart!) : null);

    final displayValue = currentShiftStart != null
        ? DateFormat('dd.MM.yyyy').format(currentShiftStart)
        : 'Nicht angegeben';

    return Padding(
      padding: const EdgeInsets.only(left: AppDimensions.paddingL),
      child: EditableInfoRow(
        icon: Icons.calendar_today,
        label: 'Schichtplan-Start',
        value: displayValue,
        editable: canEdit,
        onEdit: () async {
          final date = await DateEditorSheet.show(
            context,
            title: 'Schichtplan-Start',
            initialDate: currentShiftStart,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (date != null) {
            onFieldChanged('shiftStart', date.toIso8601String());
          }
        },
      ),
    );
  }

  Widget _buildParentField(BuildContext context, WidgetRef ref) {
    final parentsAsync = ref.watch(parentsProvider);
    final currentParentId = selectedParentId ?? person.parentId;

    return parentsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Fehler: $e'),
      data: (parents) {
        final parent = parents.where((p) => p.id == currentParentId).firstOrNull;
        final parentName = parent?.fullName ?? 'Nicht zugewiesen';

        return EditableInfoRow(
          icon: Icons.family_restroom,
          label: 'Erziehungsberechtigter',
          value: parentName,
          editable: canEdit,
          onEdit: () async {
            final items = parents
                .map((p) => SelectionItem(value: p.id!, label: p.fullName))
                .toList();

            final result = await SelectionSheet.show<int>(
              context,
              title: 'Erziehungsberechtigten auswählen',
              items: items,
              selectedValue: currentParentId,
              noneLabel: 'Kein Erziehungsberechtigter',
              icon: Icons.family_restroom,
            );

            if (result != null) {
              onFieldChanged(
                'parentId',
                result.isNone ? null : result.value,
              );
            }
          },
        );
      },
    );
  }

  Widget _buildOtherExerciseField(BuildContext context) {
    final otherExercise = person.otherExercise;

    return EditableInfoRow(
      icon: Icons.work,
      label: 'Sonstige Dienste',
      value: otherExercise ?? 'Nicht angegeben',
      editable: canEdit,
      onEdit: () => _editTextField(
        context,
        title: 'Sonstige Dienste',
        initialValue: otherExercise ?? '',
        fieldKey: 'otherExercise',
        hint: 'Weitere Aufgaben...',
      ),
    );
  }

  Widget _buildExtraField(
    BuildContext context,
    ExtraField field,
    Map<String, dynamic> additionalFields,
  ) {
    final value = additionalFields[field.id];
    final displayValue = _formatExtraFieldValue(field, value);
    final icon = _getExtraFieldIcon(field.type);

    if (field.type == 'boolean') {
      return EditableToggleRow(
        icon: icon,
        label: field.name,
        value: value == true,
        editable: canEdit,
        onChanged: (v) => onFieldChanged('additionalFields.${field.id}', v),
      );
    }

    return EditableInfoRow(
      icon: icon,
      label: field.name,
      value: displayValue,
      editable: canEdit,
      onEdit: () => _editExtraField(context, field, value),
    );
  }

  void _editExtraField(BuildContext context, ExtraField field, dynamic currentValue) async {
    switch (field.type) {
      case 'text':
      case 'textarea':
        final result = await FieldEditorSheet.show(
          context,
          title: field.name,
          initialValue: currentValue?.toString() ?? '',
          maxLines: field.type == 'textarea' ? 4 : 1,
        );
        if (result != null) {
          onFieldChanged('additionalFields.${field.id}', result);
        }
        break;

      case 'number':
        final result = await FieldEditorSheet.show(
          context,
          title: field.name,
          initialValue: currentValue?.toString() ?? '',
          keyboardType: TextInputType.number,
        );
        if (result != null) {
          onFieldChanged('additionalFields.${field.id}', int.tryParse(result) ?? 0);
        }
        break;

      case 'date':
        final initialDate = currentValue != null
            ? DateTime.tryParse(currentValue.toString())
            : null;
        final date = await DateEditorSheet.show(
          context,
          title: field.name,
          initialDate: initialDate,
        );
        if (date != null) {
          onFieldChanged(
            'additionalFields.${field.id}',
            date.toIso8601String().split('T')[0],
          );
        }
        break;

      case 'select':
        final options = field.options ?? [];
        final items = options
            .map((opt) => SelectionItem(value: opt, label: opt))
            .toList();
        final result = await SelectionSheet.show<String>(
          context,
          title: field.name,
          items: items,
          selectedValue: currentValue?.toString(),
        );
        if (result != null) {
          onFieldChanged(
            'additionalFields.${field.id}',
            result.isNone ? null : result.value,
          );
        }
        break;
    }
  }

  Widget _buildRangeField(BuildContext context) {
    final rangeValue = person.range;
    if (rangeValue == null && !canEdit) return const SizedBox.shrink();

    return EditableInfoRow(
      icon: Icons.music_note_outlined,
      label: 'Stimmumfang',
      value: rangeValue ?? 'Nicht angegeben',
      editable: canEdit,
      onEdit: () => _editTextField(
        context,
        title: 'Stimmumfang',
        initialValue: rangeValue ?? '',
        fieldKey: 'range',
        hint: 'z.B. C3 - C5',
      ),
    );
  }

  Widget _buildInstrumentsField(BuildContext context) {
    final instrumentsValue = person.instruments;
    if (instrumentsValue == null && !canEdit) return const SizedBox.shrink();

    return EditableInfoRow(
      icon: Icons.piano_outlined,
      label: 'Instrumente',
      value: instrumentsValue ?? 'Nicht angegeben',
      editable: canEdit,
      onEdit: () => _editTextField(
        context,
        title: 'Instrumente',
        initialValue: instrumentsValue ?? '',
        fieldKey: 'instruments',
        hint: 'z.B. Klavier, Gitarre',
      ),
    );
  }

  Widget _buildExamineeField(BuildContext context) {
    return EditableToggleRow(
      icon: Icons.school_outlined,
      label: 'Prüfling',
      value: person.examinee,
      editable: canEdit,
      onChanged: (v) => onFieldChanged('examinee', v),
    );
  }

  Widget _buildTestResultField(BuildContext context) {
    final testResultValue = person.testResult;
    if (testResultValue == null && !canEdit) return const SizedBox.shrink();

    return EditableInfoRow(
      icon: Icons.assignment_outlined,
      label: 'Testergebnis',
      value: testResultValue ?? 'Nicht angegeben',
      editable: canEdit,
      onEdit: () => _editTextField(
        context,
        title: 'Testergebnis',
        initialValue: testResultValue ?? '',
        fieldKey: 'testResult',
        hint: 'Ergebnis eingeben...',
      ),
    );
  }

  Future<void> _editTextField(
    BuildContext context, {
    required String title,
    required String initialValue,
    required String fieldKey,
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    IconData? icon,
    TextCapitalization? textCapitalization,
  }) async {
    final result = await FieldEditorSheet.show(
      context,
      title: title,
      initialValue: initialValue,
      hint: hint,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      icon: icon,
      textCapitalization: textCapitalization,
    );
    if (result != null) {
      onFieldChanged(fieldKey, result.isEmpty ? null : result);
    }
  }

  void _launchPhone(String phone) {
    // TODO: Implement phone launch
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String _formatExtraFieldValue(ExtraField field, dynamic value) {
    if (value == null) return 'Nicht angegeben';

    switch (field.type) {
      case 'boolean':
        return value == true ? 'Ja' : 'Nein';
      case 'date':
        final date = DateTime.tryParse(value.toString());
        if (date != null) {
          return DateFormat('dd.MM.yyyy').format(date);
        }
        return value.toString();
      default:
        return value.toString();
    }
  }

  IconData _getExtraFieldIcon(String type) {
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
}
