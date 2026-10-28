import 'package:flutter/material.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/person/person.dart';
import 'attendance_person_tile.dart';

/// Grid view of persons grouped by instrument
class AttendanceGrid extends StatelessWidget {
  const AttendanceGrid({
    super.key,
    required this.persons,
    required this.localStatuses,
    required this.personNotes,
    required this.availableStatuses,
    required this.onStatusChanged,
    required this.onNoteChanged,
    required this.onShowModifierInfo,
    required this.onRemoveFromAttendance,
    this.clickMode = false,
    this.registrationSummaries = const {},
    this.onEditRegistrationFields,
    this.showAvatars = true,
    this.extraLines,
    this.onSendReminder,
    this.showModifierInfo = true,
  });

  final List<Person> persons;
  final Map<int, AttendanceStatus> localStatuses;
  final Map<int, String?> personNotes;
  final List<AttendanceStatus> availableStatuses;
  final void Function(int personId, AttendanceStatus status) onStatusChanged;
  final void Function(int personId, String? notes) onNoteChanged;
  final void Function(int personId) onShowModifierInfo;
  final void Function(int personId) onRemoveFromAttendance;
  final bool clickMode;
  final Map<int, String> registrationSummaries;
  final void Function(int personId)? onEditRegistrationFields;
  // ATT_DETAIL
  final bool showAvatars;

  /// Flat (sorted) mode: persons are shown in the given order without group
  /// headers; the value is the extra line under the name.
  final Map<int, String>? extraLines;
  final void Function(int personId)? onSendReminder;
  final bool showModifierInfo;

  @override
  Widget build(BuildContext context) {
    if (persons.isEmpty) {
      return const Center(
        child: Text('Keine Personen gefunden'),
      );
    }

    // ATT_DETAIL: sorted by an extra field -> one flat list
    if (extraLines != null) {
      return _InstrumentGroupSection(
        groupName: null,
        persons: persons,
        localStatuses: localStatuses,
        personNotes: personNotes,
        availableStatuses: availableStatuses,
        onStatusChanged: onStatusChanged,
        onNoteChanged: onNoteChanged,
        onShowModifierInfo: onShowModifierInfo,
        registrationSummaries: registrationSummaries,
        onEditRegistrationFields: onEditRegistrationFields,
        onRemoveFromAttendance: onRemoveFromAttendance,
        clickMode: clickMode,
        showAvatars: showAvatars,
        extraLines: extraLines,
        onSendReminder: onSendReminder,
        showModifierInfo: showModifierInfo,
      );
    }

    // Group persons by instrument/group
    final grouped = _groupByInstrument(persons);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final group = grouped[index];
        return _InstrumentGroupSection(
          groupName: group.groupName,
          persons: group.persons,
          localStatuses: localStatuses,
          personNotes: personNotes,
          availableStatuses: availableStatuses,
          onStatusChanged: onStatusChanged,
          onNoteChanged: onNoteChanged,
          onShowModifierInfo: onShowModifierInfo,
          registrationSummaries: registrationSummaries,
          onEditRegistrationFields: onEditRegistrationFields,
          onRemoveFromAttendance: onRemoveFromAttendance,
          clickMode: clickMode,
          showAvatars: showAvatars,
          onSendReminder: onSendReminder,
          showModifierInfo: showModifierInfo,
        );
      },
    );
  }

  List<_InstrumentGroup> _groupByInstrument(List<Person> persons) {
    final Map<String, List<Person>> grouped = {};

    for (final person in persons) {
      final groupName = person.groupName ?? 'Unbekannt';
      grouped.putIfAbsent(groupName, () => []).add(person);
    }

    return grouped.entries
        .map((e) => _InstrumentGroup(groupName: e.key, persons: e.value))
        .toList()
      ..sort((a, b) => a.groupName.compareTo(b.groupName));
  }
}

class _InstrumentGroup {
  final String groupName;
  final List<Person> persons;

  _InstrumentGroup({required this.groupName, required this.persons});
}

class _InstrumentGroupSection extends StatelessWidget {
  const _InstrumentGroupSection({
    required this.groupName,
    required this.persons,
    required this.localStatuses,
    required this.personNotes,
    required this.availableStatuses,
    required this.onStatusChanged,
    required this.onNoteChanged,
    required this.onShowModifierInfo,
    required this.onRemoveFromAttendance,
    this.clickMode = false,
    this.registrationSummaries = const {},
    this.onEditRegistrationFields,
    this.showAvatars = true,
    this.extraLines,
    this.onSendReminder,
    this.showModifierInfo = true,
  });

  final String? groupName;
  final List<Person> persons;
  final Map<int, AttendanceStatus> localStatuses;
  final Map<int, String?> personNotes;
  final List<AttendanceStatus> availableStatuses;
  final void Function(int personId, AttendanceStatus status) onStatusChanged;
  final void Function(int personId, String? notes) onNoteChanged;
  final void Function(int personId) onShowModifierInfo;
  final void Function(int personId) onRemoveFromAttendance;
  final bool clickMode;
  final Map<int, String> registrationSummaries;
  final void Function(int personId)? onEditRegistrationFields;
  // ATT_DETAIL
  final bool showAvatars;

  /// Flat (sorted) mode: persons are shown in the given order without group
  /// headers; the value is the extra line under the name.
  final Map<int, String>? extraLines;
  final void Function(int personId)? onSendReminder;
  final bool showModifierInfo;

  @override
  Widget build(BuildContext context) {
    // Count present persons (present, late, or lateExcused)
    final presentCount = persons.where((p) {
      final status = localStatuses[p.id];
      return status == AttendanceStatus.present ||
             status == AttendanceStatus.late ||
             status == AttendanceStatus.lateExcused;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (groupName != null)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          child: Row(
            children: [
              Text(
                groupName!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppDimensions.paddingS),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$presentCount/${persons.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...persons.map((person) {
          final status = localStatuses[person.id] ?? AttendanceStatus.neutral;
          final notes = personNotes[person.id];

          return AttendancePersonTile(
            person: person,
            status: status,
            notes: notes,
            availableStatuses: availableStatuses,
            clickMode: clickMode,
            registrationSummary: registrationSummaries[person.id],
            showAvatar: showAvatars,
            extraLine: extraLines?[person.id],
            showModifierInfo: showModifierInfo,
            onSendReminder: onSendReminder == null || person.id == null
                ? null
                : () => onSendReminder!(person.id!),
            onEditRegistrationFields: onEditRegistrationFields == null || person.id == null
                ? null
                : () => onEditRegistrationFields!(person.id!),
            onStatusChanged: (newStatus) {
              if (person.id != null) {
                onStatusChanged(person.id!, newStatus);
              }
            },
            onNoteChanged: (newNotes) {
              if (person.id != null) {
                onNoteChanged(person.id!, newNotes);
              }
            },
            onShowModifierInfo: () {
              if (person.id != null) {
                onShowModifierInfo(person.id!);
              }
            },
            onRemoveFromAttendance: () {
              if (person.id != null) {
                onRemoveFromAttendance(person.id!);
              }
            },
          );
        }),
        const SizedBox(height: AppDimensions.paddingS),
      ],
    );
  }
}
