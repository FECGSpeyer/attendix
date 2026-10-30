import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/providers/group_providers.dart';
import '../../../../../core/providers/church_providers.dart';
import '../../../../../core/providers/parent_providers.dart';
import '../../../../../core/providers/profile_providers.dart';
import '../../../../../core/providers/shift_providers.dart';
import '../../../../../core/providers/teacher_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/tenant_label_utils.dart';
import '../../../../../data/models/parent/parent_model.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../data/models/shift/shift_plan.dart';
import '../../../../../data/models/tenant/tenant.dart';
import '../ion/ion_widgets.dart';
import '../../../../../shared/widgets/sheets/field_editor_sheet.dart';
import '../../../../../shared/widgets/sheets/selection_sheet.dart';
import '../church_picker_sheet.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../core/utils/error_message.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';

/// Ionic VoS "Andere Orchester" options
const otherOrchestraOptions = ['SoS', 'GoS', 'BoS'];

/// Person extra fields: organisation fields first, then tenant fields not
/// overridden by the organisation (Ionic getPersonExtraFields).
List<ExtraField> personExtraFields(WidgetRef ref, Tenant? tenant) {
  final all = ref.watch(personExtraFieldsProvider).valueOrNull;
  if (all == null) return tenant?.additionalFields ?? const [];
  return all
      .map((f) => ExtraField(
            id: f.id,
            name: f.name,
            type: f.type,
            defaultValue: f.defaultValue,
            options: f.options,
            visibleToPlayers: f.visibleToPlayers,
            editableByPlayers: f.editableByPlayers,
          ))
      .toList();
}

/// Callback type for person field changes.
typedef PersonFieldChanged = void Function(String field, dynamic value);

/// UX_PEOPLE: the Ionic person page shows these parts in different places:
/// names (inline under the header), notes (above the accordions), the
/// "Allgemein" accordion and the separate "Zusatzfelder" accordion.
enum AllgemeinPart { general, names, notes, extraFields }

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
    this.isMainGroup = false,
    this.otherOrchestras,
    this.part = AllgemeinPart.general,
  });

  /// Which part of the Ionic person page this widget renders.
  final AllgemeinPart part;

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

  /// Selected group is the main group (Ionic isMainGroup)
  final bool isMainGroup;

  /// Draft "Andere Orchester" (VoS)
  final List<String>? otherOrchestras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(currentTenantProvider);
    final extraFields = personExtraFields(ref, tenant);
    final additionalFields = additionalFieldValues ?? person.additionalFields ?? {};
    final isGeneral = tenant?.type == 'general';
    final isChoir = tenant?.type == 'choir';
    final isVoS = tenant?.shortName == 'VoS';

    switch (part) {
      case AllgemeinPart.names:
        // Ionic ion-grid: Vorname | Nachname side by side
        return _buildNameFields(context);
      case AllgemeinPart.notes:
        // Ionic: "Notizen" textarea above the accordions (existing && isAdmin)
        return _buildNotesField(context);
      case AllgemeinPart.extraFields:
        // Ionic accordion "Zusatzfelder"
        if (extraFields.isEmpty) return const SizedBox.shrink();
        return IonAccordion(
          title: context.l10n.peopleExtraFields,
          expanded: isExpanded,
          onToggle: onToggle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: extraFields
                .map((field) => _buildExtraField(context, field, additionalFields))
                .toList(),
          ),
        );
      case AllgemeinPart.general:
        break;
    }

    // Ionic accordion "Allgemein", field order of person.page.html
    return IonAccordion(
      title: context.l10n.attendanceGeneral,
      expanded: isExpanded,
      onToggle: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gruppe
          _buildGroupField(context, ref),

          // Stimmumfang (choir)
          if (isChoir) _buildRangeField(context),

          // Telefonnummer
          _buildPhoneField(context),

          // Geburtstag (warning item when not confirmed)
          if (person.birthday != null || canEdit)
            _buildDateField(
              context,
              icon: Icons.cake,
              label: context.l10n.peopleBirthday,
              value: person.birthday,
              fieldKey: 'birthday',
              highlight: !person.correctBirthday && canEdit,
              highlightColor: AppColors.warning,
            ),

          // Spielt seit (!general && !choir && !mainGroup)
          if ((person.playsSince != null || canEdit) &&
              !isGeneral &&
              !isChoir &&
              !isMainGroup)
            _buildDateField(
              context,
              icon: Icons.music_note,
              label: context.l10n.personPlaysSince,
              value: person.playsSince,
              fieldKey: 'playsSince',
            ),

          // Beigetreten am
          if (person.joined != null || canEdit)
            _buildDateField(
              context,
              icon: Icons.login,
              label: context.l10n.personJoinedOn,
              value: person.joined,
              fieldKey: 'joined',
            ),

          // Eltern (parents enabled && !mainGroup)
          if ((tenant?.parents ?? false) && !isMainGroup)
            _buildParentField(context, ref),

          // Spielt bei Lehrer + Lehrer (maintainTeachers && !mainGroup)
          if ((tenant?.maintainTeachers ?? false) && !isMainGroup)
            _buildHasTeacherField(context, ref),

          // Stimmführer (!general && !mainGroup)
          if (!isGeneral && !isMainGroup) _buildIsLeaderField(context),

          // Instrumente (choir && !mainGroup)
          if (isChoir && !isMainGroup) _buildInstrumentsField(context),

          // Andere Orchester (VoS)
          if (isVoS && !isMainGroup &&
              (canEdit ||
                  (otherOrchestras ?? person.otherOrchestras ?? []).isNotEmpty))
            _buildOtherOrchestrasField(context),

          // Prüfling (VoS && !mainGroup && (!readOnly || examinee))
          if (isVoS && !isMainGroup && (canEdit || person.examinee))
            _buildExamineeField(context),

          // Testergebnis (VoS && !mainGroup)
          if (isVoS && !isMainGroup) _buildTestResultField(context),

          // Schichtplan / Schicht
          _buildShiftPlanField(context, ref),

          // Sonstige Dienste (!readOnly || otherExercise)
          if (person.otherExercise != null || canEdit)
            _buildOtherExerciseField(context),
        ],
      ),
    );
  }

  Widget _buildNameFields(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: IonFieldRow(
            icon: Icons.person,
            label: context.l10n.peopleFirstName,
            value: person.firstName,
            editable: canEdit,
            onEdit: () => _editTextField(
              context,
              title: context.l10n.peopleFirstName,
              initialValue: person.firstName,
              fieldKey: 'firstName',
              textCapitalization: TextCapitalization.words,
              validator: (v) => v?.isEmpty ?? true ? context.l10n.personFlutterRequired : null,
            ),
          ),
        ),
        Expanded(
          child: IonFieldRow(
            icon: Icons.person_outline,
            label: context.l10n.peopleLastName,
            value: person.lastName,
            editable: canEdit,
            onEdit: () => _editTextField(
              context,
              title: context.l10n.peopleLastName,
              initialValue: person.lastName,
              fieldKey: 'lastName',
              textCapitalization: TextCapitalization.words,
              validator: (v) => v?.isEmpty ?? true ? context.l10n.personFlutterRequired : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField(BuildContext context) {
    final notes = person.notes;
    if (notes == null && !canEdit) return const SizedBox.shrink();

    return IonFieldRow(
      icon: Icons.notes,
      label: context.l10n.peopleNotes,
      value: notes ?? context.l10n.personFlutterNoNotes,
      editable: canEdit,
      onEdit: () => _editTextField(
        context,
        title: context.l10n.peopleNotes,
        initialValue: notes ?? '',
        fieldKey: 'notes',
        maxLines: 4,
        hint: context.l10n.personFlutterNotesHint,
      ),
    );
  }

  Widget _buildGroupField(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsMapProvider);
    final currentGroupId = selectedGroupId ?? person.instrument;
    final tenantType = ref.watch(currentTenantProvider)?.type;

    return groupsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e))),
      data: (groups) {
        final groupName = currentGroupId != null
            ? groups[currentGroupId] ?? context.l10n.commonUnknown
            : context.l10n.personFlutterNotAssigned;

        return IonFieldRow(
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
              title: context.l10n.personFlutterChooseLabel(groupLabel(tenantType)),
              items: items,
              selectedValue: currentGroupId,
              noneLabel: context.l10n.personFlutterNoneLabel(groupLabel(tenantType)),
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

    return IonFieldRow(
      icon: Icons.phone,
      label: context.l10n.peoplePhone,
      value: phone ?? context.l10n.personFlutterNotSpecified,
      editable: canEdit,
      onTap: phone != null ? () => _launchPhone(phone) : null,
      onEdit: () => _editTextField(
        context,
        title: context.l10n.peoplePhone,
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
    final displayValue = value != null ? _formatDate(value) : context.l10n.personFlutterNotSpecified;

    return IonFieldRow(
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

    return IonToggleRow(
      icon: Icons.star,
      label: context.l10n.peopleVoiceLeader,
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
        IonToggleRow(
          icon: Icons.school,
          label: context.l10n.personPlaysWithTeacher,
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
      error: (e, _) => Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e))),
      data: (teachers) {
        final teacher = teachers.where((t) => t.id == teacherId).firstOrNull;
        final teacherName = teacher?.name ?? context.l10n.personFlutterNotSelected;

        return Padding(
          padding: EdgeInsets.zero,
          child: IonFieldRow(
            icon: Icons.person,
            label: context.l10n.peopleTeacher,
            value: teacherName,
            editable: canEdit,
            onEdit: () async {
              final items = teachers
                  .map((t) => SelectionItem(value: t.id!, label: t.name))
                  .toList();

              final result = await SelectionSheet.show<int>(
                context,
                title: context.l10n.personFlutterChooseLabel(context.l10n.peopleTeacher),
                items: items,
                selectedValue: teacherId,
                noneLabel: context.l10n.peopleNoTeacher,
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
      error: (e, _) => Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e))),
      data: (shifts) {
        final shift = shifts.where((s) => s.id == currentShiftId).firstOrNull;
        final shiftName = shift?.name ?? context.l10n.personFlutterNoShiftPlan;

        return Column(
          children: [
            IonFieldRow(
              icon: Icons.schedule,
              label: context.l10n.personShiftPlan,
              value: shiftName,
              editable: canEdit,
              onEdit: () async {
                final items = shifts
                    .map((s) => SelectionItem(value: s.id!, label: s.name))
                    .toList();

                final result = await SelectionSheet.show<String>(
                  context,
                  title: context.l10n.personFlutterChooseLabel(context.l10n.personShiftPlan),
                  items: items,
                  selectedValue: currentShiftId,
                  noneLabel: context.l10n.personFlutterNoShiftPlan,
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
      child: IonFieldRow(
        icon: Icons.access_time,
        label: context.l10n.personShift,
        value: currentShiftName ?? context.l10n.personFlutterNotSelected,
        editable: canEdit,
        onEdit: () async {
          final items = uniqueShiftNames
              .map((name) => SelectionItem(value: name, label: name))
              .toList();

          final result = await SelectionSheet.show<String>(
            context,
            title: context.l10n.personFlutterChooseLabel(context.l10n.personShift),
            items: items,
            selectedValue: currentShiftName,
            noneLabel: context.l10n.personNoShift,
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
        ? DateFormat(dateFmt()).format(currentShiftStart)
        : context.l10n.personFlutterNotSpecified;

    return Padding(
      padding: const EdgeInsets.only(left: AppDimensions.paddingL),
      child: IonFieldRow(
        icon: Icons.calendar_today,
        label: context.l10n.personStartDate,
        value: displayValue,
        editable: canEdit,
        onEdit: () async {
          final date = await DateEditorSheet.show(
            context,
            title: context.l10n.personStartDate,
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
      error: (e, _) => Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(e))),
      data: (parents) {
        final parent = parents.where((p) => p.id == currentParentId).firstOrNull;
        final parentName = parent?.fullName ?? context.l10n.personFlutterNotAssigned;

        return IonFieldRow(
          icon: Icons.family_restroom,
          label: context.l10n.personParents,
          value: parentName,
          editable: canEdit,
          onEdit: () async {
            final items = parents
                .map((p) => SelectionItem(value: p.id!, label: p.fullName))
                .toList();

            final result = await SelectionSheet.show<int>(
              context,
              title: context.l10n.personFlutterChooseLabel(context.l10n.personParents),
              items: items,
              selectedValue: currentParentId,
              noneLabel: context.l10n.personNotSet,
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

    return IonFieldRow(
      icon: Icons.work,
      label: context.l10n.peopleOtherDuties,
      value: otherExercise ?? context.l10n.personFlutterNotSpecified,
      editable: canEdit,
      onEdit: () => _editTextField(
        context,
        title: context.l10n.peopleOtherDuties,
        initialValue: otherExercise ?? '',
        fieldKey: 'otherExercise',
        hint: context.l10n.personFlutterOtherDutiesHint,
      ),
    );
  }

  Widget _buildOtherOrchestrasField(BuildContext context) {
    final selected = otherOrchestras ?? person.otherOrchestras ?? const [];
    return IonFieldRow(
      icon: Icons.groups_2_outlined,
      label: context.l10n.personOtherOrchestras,
      value: selected.isEmpty ? context.l10n.generalSettingsNone : selected.join(', '),
      editable: canEdit,
      onEdit: () async {
        final current = Set<String>.from(selected);
        final result = await showAppDialog<List<String>>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setState) => AppAlertDialog(
              title: Text(context.l10n.personOtherOrchestras),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final o in otherOrchestraOptions)
                    CheckboxListTile(
                      title: Text(o),
                      value: current.contains(o),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          current.add(o);
                        } else {
                          current.remove(o);
                        }
                      }),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    ctx,
                    otherOrchestraOptions.where(current.contains).toList(),
                  ),
                  child: Text(context.l10n.commonApply),
                ),
              ],
            ),
          ),
        );
        if (result != null) onFieldChanged('otherOrchestras', result);
      },
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

    if (field.type == 'bfecg_church') {
      return Consumer(
        builder: (context, ref, _) {
          final churches = ref.watch(churchesProvider).valueOrNull ?? const [];
          return IonFieldRow(
            icon: Icons.church_outlined,
            label: field.name,
            value: churchLabel(value, churches),
            editable: canEdit,
            onEdit: () async {
              final selected = await showChurchPickerSheet(
                context,
                title: field.name,
                churches: churches,
                selectedId: value?.toString(),
              );
              if (selected != null) {
                onFieldChanged('additionalFields.${field.id}', selected);
              }
            },
          );
        },
      );
    }

    if (field.type == 'boolean') {
      return IonToggleRow(
        icon: icon,
        label: field.name,
        value: value == true,
        editable: canEdit,
        onChanged: (v) => onFieldChanged('additionalFields.${field.id}', v),
      );
    }

    return IonFieldRow(
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

    return IonFieldRow(
      icon: Icons.music_note_outlined,
      label: context.l10n.personVocalRange,
      value: rangeValue ?? context.l10n.personFlutterNotSpecified,
      editable: canEdit,
      onEdit: () => _editTextField(
        context,
        title: context.l10n.personVocalRange,
        initialValue: rangeValue ?? '',
        fieldKey: 'range',
        hint: context.l10n.personFlutterRangeHint,
      ),
    );
  }

  Widget _buildInstrumentsField(BuildContext context) {
    final instrumentsValue = person.instruments;
    if (instrumentsValue == null && !canEdit) return const SizedBox.shrink();

    return IonFieldRow(
      icon: Icons.piano_outlined,
      label: context.l10n.peopleInstruments,
      value: instrumentsValue ?? context.l10n.personFlutterNotSpecified,
      editable: canEdit,
      onEdit: () => _editTextField(
        context,
        title: context.l10n.peopleInstruments,
        initialValue: instrumentsValue ?? '',
        fieldKey: 'instruments',
        hint: context.l10n.personFlutterInstrumentsHint,
      ),
    );
  }

  Widget _buildExamineeField(BuildContext context) {
    return IonToggleRow(
      icon: Icons.school_outlined,
      label: context.l10n.peopleCandidate,
      value: person.examinee,
      editable: canEdit,
      onChanged: (v) => onFieldChanged('examinee', v),
    );
  }

  Widget _buildTestResultField(BuildContext context) {
    final testResultValue = person.testResult;
    if (testResultValue == null && !canEdit) return const SizedBox.shrink();

    return IonFieldRow(
      icon: Icons.assignment_outlined,
      label: context.l10n.peopleTestResult,
      value: testResultValue ?? context.l10n.personFlutterNotSpecified,
      editable: canEdit,
      onEdit: () => _editTextField(
        context,
        title: context.l10n.peopleTestResult,
        initialValue: testResultValue ?? '',
        fieldKey: 'testResult',
        hint: context.l10n.personFlutterTestResultHint,
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
    return DateFormat(dateFmt()).format(date);
  }

  String _formatExtraFieldValue(ExtraField field, dynamic value) {
    if (value == null) return l10nWithoutContext.personFlutterNotSpecified;

    switch (field.type) {
      case 'boolean':
        return value == true ? l10nWithoutContext.commonYes : l10nWithoutContext.commonNo;
      case 'date':
        final date = DateTime.tryParse(value.toString());
        if (date != null) {
          return DateFormat(dateFmt()).format(date);
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
