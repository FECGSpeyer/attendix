import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/attendance/attendance.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/ion_button_label.dart';

/// Candidates for "Person hinzufügen" (Ionic openAddPersonModal).
class AddPersonCandidates {
  const AddPersonCandidates({required this.matching, required this.others});

  /// Persons matching the Termintyp (relevant groups + extra field filter).
  final List<Person> matching;

  /// All other active persons not in the Termin yet.
  final List<Person> others;

  bool get isEmpty => matching.isEmpty && others.isEmpty;
}

/// Splits the active persons that are not part of the Termin yet into
/// "Passende Personen" and "Andere Personen", sorted by group sort order,
/// then last/first name (Ionic openAddPersonModal).
AddPersonCandidates computeAddPersonCandidates({
  required List<Person> allPersons,
  required Set<int> currentPersonIds,
  required AttendanceType? type,
  required List<Group> groups,
  Map<String, dynamic>? extraFieldDefaults,
}) {
  final notIn = allPersons
      .where((p) =>
          p.id != null &&
          !currentPersonIds.contains(p.id) &&
          !p.paused &&
          (p.left == null || p.left!.isEmpty))
      .toList();

  bool matches(Person p) {
    final relevant = type?.relevantGroups ?? const <int>[];
    if (relevant.isNotEmpty && !relevant.contains(p.instrument)) return false;
    final filter = type?.additionalFieldsFilter;
    final key = filter?['key'] as String?;
    final option = filter?['option'];
    if (key != null && key.isNotEmpty && option != null &&
        (extraFieldDefaults?.containsKey(key) ?? false)) {
      final value = p.additionalFields?[key] ?? extraFieldDefaults![key];
      return value == option;
    }
    return true;
  }

  final sortOrder = {for (final g in groups) g.id: g.sortOrder ?? 999999};
  int compare(Person a, Person b) {
    final ga = sortOrder[a.instrument] ?? 999999;
    final gb = sortOrder[b.instrument] ?? 999999;
    if (ga != gb) return ga.compareTo(gb);
    final ln = a.lastName.compareTo(b.lastName);
    if (ln != 0) return ln;
    return a.firstName.compareTo(b.firstName);
  }

  final matching = notIn.where(matches).toList()..sort(compare);
  final matchingIds = matching.map((p) => p.id).toSet();
  final others = notIn.where((p) => !matchingIds.contains(p.id)).toList()..sort(compare);
  return AddPersonCandidates(matching: matching, others: others);
}

/// Shows the multi-select sheet; returns the selected person ids or null.
Future<List<int>?> showAddPersonsSheet(
  BuildContext context, {
  required AddPersonCandidates candidates,
  required String Function(Person) groupNameOf,
}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, controller) => _AddPersonsView(
        candidates: candidates,
        groupNameOf: groupNameOf,
        scrollController: controller,
      ),
    ),
  );
}

class _AddPersonsView extends StatefulWidget {
  const _AddPersonsView({
    required this.candidates,
    required this.groupNameOf,
    required this.scrollController,
  });

  final AddPersonCandidates candidates;
  final String Function(Person) groupNameOf;
  final ScrollController scrollController;

  @override
  State<_AddPersonsView> createState() => _AddPersonsViewState();
}

class _AddPersonsViewState extends State<_AddPersonsView> {
  final Set<int> _selected = {};
  bool _othersExpanded = false;

  Widget _personTile(Person p) => CheckboxListTile(
        value: _selected.contains(p.id),
        onChanged: (v) => setState(() {
          if (v == true) {
            _selected.add(p.id!);
          } else {
            _selected.remove(p.id);
          }
        }),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text('${p.firstName} ${p.lastName}'),
        subtitle: Text(widget.groupNameOf(p)),
      );

  Widget _sectionHeader(String label, int count, Color color, {VoidCallback? onTap, bool? expanded}) {
    return ListTile(
      onTap: onTap,
      title: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      trailing: expanded == null ? null : Icon(expanded ? Icons.expand_less : Icons.expand_more),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.candidates;
    final count = _selected.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(context.l10n.attendanceAddPerson, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        Expanded(
          child: c.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.l10n.attendanceAllAlreadyIncluded,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.medium),
                    ),
                  ),
                )
              : ListView(
                  controller: widget.scrollController,
                  children: [
                    if (c.matching.isNotEmpty) ...[
                      _sectionHeader(context.l10n.attendanceMatchingPeople, c.matching.length, AppColors.primary),
                      for (final p in c.matching) _personTile(p),
                    ],
                    if (c.others.isNotEmpty) ...[
                      _sectionHeader(
                        context.l10n.attendanceOtherPeople,
                        c.others.length,
                        AppColors.medium,
                        expanded: _othersExpanded || c.matching.isEmpty,
                        onTap: () => setState(() => _othersExpanded = !_othersExpanded),
                      ),
                      if (_othersExpanded || c.matching.isEmpty)
                        for (final p in c.others) _personTile(p),
                    ],
                  ],
                ),
        ),
        if (!c.isEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: count == 0 ? null : () => Navigator.of(context).pop(_selected.toList()),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: IonButtonLabel(count == 0
                      ? context.l10n.attendanceChoosePeople
                      : context.l10n.attendanceAddPersonsCount(count)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
