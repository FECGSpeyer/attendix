import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/providers/group_providers.dart';
import '../../../../../core/logic/words.dart';
import '../../../../../core/theme/design_theme.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/components/components.dart';

export 'person_form_fields.dart' show RdPersonMatchList, RdPersonMoreFields;

/// Form parts shared by "Neue Person" and "Person bearbeiten". Changes are
/// reported as `player` columns, so the create page collects them and the
/// edit page writes them right away.

/// Reports changed `player` columns. [typing] is true while a text is
/// typed (the edit page saves those a moment later).
typedef RdPersonColumnsChanged = void Function(Map<String, dynamic> columns, {bool typing});

/// Reports a changed Zusatzfeld value.
typedef RdPersonExtraChanged = void Function(String fieldId, dynamic value, {bool typing});

/// [person] with the changed [columns] (keys as in the `player` table).
Person applyPersonColumns(Person person, Map<String, dynamic> columns) {
  var p = person;
  for (final e in columns.entries) {
    final v = e.value;
    p = switch (e.key) {
      'firstName' => p.copyWith(firstName: v as String? ?? ''),
      'lastName' => p.copyWith(lastName: v as String? ?? ''),
      'email' => p.copyWith(email: v as String?),
      'phone' => p.copyWith(phone: v as String?),
      'notes' => p.copyWith(notes: v as String?),
      'instrument' => p.copyWith(instrument: v as int?),
      'birthday' => p.copyWith(birthday: v as String?),
      'correctBirthday' => p.copyWith(correctBirthday: v as bool),
      'playsSince' => p.copyWith(playsSince: v as String?),
      'joined' => p.copyWith(joined: v as String?),
      'parent_id' => p.copyWith(parentId: v as int?),
      'hasTeacher' => p.copyWith(hasTeacher: v as bool),
      'teacher' => p.copyWith(teacher: v as int?),
      'isLeader' => p.copyWith(isLeader: v as bool),
      'range' => p.copyWith(range: v as String?),
      'instruments' => p.copyWith(instruments: v as String?),
      'otherOrchestras' => p.copyWith(otherOrchestras: (v as List?)?.cast<String>()),
      'examinee' => p.copyWith(examinee: v as bool),
      'testResult' => p.copyWith(testResult: v as String?),
      'shift_id' => p.copyWith(shiftId: v as String?),
      'shift_name' => p.copyWith(shiftName: v as String?),
      'shift_start' => p.copyWith(shiftStart: v as String?),
      'otherExercise' => p.copyWith(otherExercise: v as String?),
      'img' => p.copyWith(img: v as String?),
      _ => p,
    };
  }
  return p;
}

/// Passbild (or initials) of the name card; tapping picks, replaces or
/// removes it.
class RdPersonAvatar extends StatelessWidget {
  const RdPersonAvatar({super.key, required this.name, required this.onTap, this.imageBytes, this.imageUrl});

  final String name;
  final VoidCallback? onTap;
  final Uint8List? imageBytes;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    const size = 72.0;
    final initials = RdInitials(rdInitialsOf(name.trim().isEmpty ? '?' : name), size: size);
    final url = imageUrl;
    final Widget image = imageBytes != null
        ? Image.memory(imageBytes!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials)
        : url != null && url.isNotEmpty && !url.contains('.svg')
            ? Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials)
            : initials;
    return Semantics(
      button: onTap != null,
      label: context.l10n.peoplePassportPhoto,
      child: GestureDetector(
        key: const Key('rd-person-avatar'),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(child: image),
              if (onTap != null)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: p.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.surface, width: 2),
                    ),
                    child: Icon(Icons.camera_alt, size: 13, color: p.onPrimary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Group chips like in the Werk and Termin forms (Ionic: no "none").
class RdPersonGroupChips extends ConsumerWidget {
  const RdPersonGroupChips({super.key, required this.selected, required this.onSelected, this.onManage});

  final int? selected;
  final ValueChanged<int>? onSelected;

  /// Leads: "Register verwalten" below the chips (Verwaltung › Register).
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final list = groups.valueOrNull;
    if (list == null) {
      return groups.hasError
          ? Text(context.l10n.redesignTodayLoadFailed, style: RdType.meta(context.rd, size: 13))
          : const LinearProgressIndicator();
    }
    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final g in list)
          if (g.id != null)
            RdChoiceChip(
              key: Key('rd-person-group-${g.id}'),
              label: g.name,
              selected: g.id == selected,
              onTap: onSelected == null ? null : () => onSelected!(g.id!),
            ),
      ],
    );
    if (onManage == null) return chips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chips,
        const SizedBox(height: 4),
        RdTextLink(label: context.l10n.rdAdminManageGroups(ref.watch(rdGroupKindProvider)), onTap: onManage!),
      ],
    );
  }
}
