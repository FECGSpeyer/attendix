import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../data/models/church/church.dart';
import '../../../../../data/models/instrument/instrument.dart';
import '../../../../../data/models/tenant/tenant.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../data/providers/rd_members_providers.dart';
import '../../../data/rd_members_list_filter.dart';
import '../rd_widgets.dart';

/// Label of a sort order of the Mitglieder tab.
String rdMembersSortLabel(AppLocalizations l10n, RdMembersSort sort) => switch (sort) {
  RdMembersSort.group => l10n.peopleGroup,
  RdMembersSort.firstName => l10n.peopleFirstName,
  RdMembersSort.lastName => l10n.peopleLastName,
  RdMembersSort.attendanceAsc => l10n.peopleAttendanceAsc,
  RdMembersSort.attendanceDesc => l10n.peopleAttendanceDesc,
  RdMembersSort.birthdayAsc => l10n.peopleBirthdayAsc,
  RdMembersSort.birthdayDesc => l10n.peopleBirthdayDesc,
  RdMembersSort.nextBirthday => l10n.peopleNextBirthday,
  RdMembersSort.joinedAsc => l10n.peopleJoinAsc,
  RdMembersSort.joinedDesc => l10n.peopleJoinDesc,
  RdMembersSort.testResult => l10n.peopleTestResult,
};

/// Label of a yes/no filter of the Mitglieder tab.
String rdMembersOnlyLabel(AppLocalizations l10n, RdMembersOnly only) => switch (only) {
  RdMembersOnly.leaders => l10n.redesignMembersLeader,
  RdMembersOnly.noAccount => l10n.redesignMembersFilterNoAccount,
  RdMembersOnly.examinees => l10n.peopleCandidates,
  RdMembersOnly.newPeople => l10n.peopleNewPlayers,
  RdMembersOnly.noTeacher => l10n.peopleWithoutTeacher,
  RdMembersOnly.noTest => l10n.peopleTestResultMissing,
};

/// Extra field types the list can filter by (Ionic: boolean, select,
/// number, bfecg_church).
bool rdMembersFilterableField(ExtraField f) => const ['boolean', 'select', 'number', 'bfecg_church'].contains(f.type);

/// The choices of a boolean / select / church field as (value, label).
List<(String, String)> rdMembersFieldChoices(AppLocalizations l10n, ExtraField field, List<Church> churches) =>
    switch (field.type) {
      'boolean' => [('true', l10n.commonYes), ('false', l10n.commonNo)],
      'bfecg_church' => [
        for (final c in churches)
          if (c.id != null) (c.id!, c.name),
      ],
      _ => [for (final o in field.options ?? const <String>[]) (o, o)],
    };

/// Shown value of an extra field filter ("Ja", the church name …).
String rdMembersFieldValueLabel(AppLocalizations l10n, ExtraField field, String value, List<Church> churches) {
  for (final (v, label) in rdMembersFieldChoices(l10n, field, churches)) {
    if (v == value) return label;
  }
  return value;
}

/// Number of persons a filter would show (for the button of the sheet).
typedef RdMembersCount = int Function(RdMembersListFilter filter, bool criticalOnly, Set<String>? otherIds);

/// "Sortieren & Filtern" of the Mitglieder tab (same sheet as in Werke):
/// changes apply at once, the button shows how many persons are left.
Future<void> showRdMembersFilterSheet(
  BuildContext context, {
  required RdMembersCount countFor,
  required List<Group> groups,
  required List<ExtraField> fields,
  required List<Church> churches,
  required List<Tenant> linkedTenants,
  required bool vos,
  required bool general,
  required bool withCritical,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.rd.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder:
        (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder:
              (sheet, controller) => _FilterSheet(
                controller: controller,
                countFor: countFor,
                groups: groups,
                fields: fields,
                churches: churches,
                linkedTenants: linkedTenants,
                vos: vos,
                general: general,
                withCritical: withCritical,
              ),
        ),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({
    required this.controller,
    required this.countFor,
    required this.groups,
    required this.fields,
    required this.churches,
    required this.linkedTenants,
    required this.vos,
    required this.general,
    required this.withCritical,
  });

  final ScrollController controller;
  final RdMembersCount countFor;
  final List<Group> groups;
  final List<ExtraField> fields;
  final List<Church> churches;
  final List<Tenant> linkedTenants;
  final bool vos;
  final bool general;

  /// "Fehlen oft" (only on Aktiv).
  final bool withCritical;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  /// Number fields: field id → input.
  final _numbers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final filter = ref.read(rdMembersListFilterProvider);
    for (final f in widget.fields.where((f) => f.type == 'number')) {
      _numbers[f.id] = TextEditingController(text: filter.fields[f.id] ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in _numbers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(RdMembersListFilter next) => ref.read(rdMembersListFilterProvider.notifier).state = next;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final filter = ref.watch(rdMembersListFilterProvider);
    final critical = widget.withCritical && ref.watch(rdMembersCriticalOnlyProvider);
    final otherIds =
        filter.otherTenantId == null
            ? null
            : ref.watch(rdOtherInstanceUserIdsProvider(filter.otherTenantId!)).valueOrNull;
    final count = widget.countFor(filter, critical, otherIds);

    final sorts = [
      for (final s in RdMembersSort.values)
        if (widget.vos || !rdMembersVosSorts.contains(s)) s,
    ];
    final onlies = [
      for (final o in RdMembersOnly.values)
        if ((widget.vos || !rdMembersVosOnly.contains(o)) && !(o == RdMembersOnly.leaders && widget.general)) o,
    ];

    return ListView(
      controller: widget.controller,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: p.track, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Semantics(header: true, child: Text(l10n.redesignWorksFilterTitle, style: RdType.section(p))),
            ),
            RdTextLink(
              label: l10n.redesignWorksFilterReset,
              onTap: () {
                _set(const RdMembersListFilter());
                ref.read(rdMembersCriticalOnlyProvider.notifier).state = false;
                for (final c in _numbers.values) {
                  c.clear();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('rd-members-sort'),
              title: l10n.redesignWorksSort,
              value: rdMembersSortLabel(l10n, filter.sort),
              onTap: () async {
                final choice = await showAppActionSheet<RdMembersSort>(
                  context,
                  title: l10n.redesignWorksSort,
                  actions: [
                    for (final s in sorts)
                      AppActionSheetAction(
                        value: s,
                        icon: s == filter.sort ? Icons.check : null,
                        label: rdMembersSortLabel(l10n, s),
                      ),
                  ],
                );
                if (choice != null) _set(ref.read(rdMembersListFilterProvider).copyWith(sort: choice));
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignWorksOnly),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.withCritical)
              RdChoiceChip(
                label: l10n.redesignMembersFilterCritical,
                selected: critical,
                onTap: () => ref.read(rdMembersCriticalOnlyProvider.notifier).state = !critical,
              ),
            for (final o in onlies)
              RdChoiceChip(
                label: rdMembersOnlyLabel(l10n, o),
                selected: filter.only.contains(o),
                onTap: () => _set(ref.read(rdMembersListFilterProvider).toggleOnly(o)),
              ),
          ],
        ),
        if (widget.groups.length > 1) ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.redesignMembersFilterGroups),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in widget.groups)
                if (g.id != null)
                  RdChoiceChip(
                    label: g.name,
                    selected: filter.groupIds.contains(g.id),
                    onTap: () => _set(ref.read(rdMembersListFilterProvider).toggleGroup(g.id!)),
                  ),
            ],
          ),
        ],
        for (final field in widget.fields) ...[
          const SizedBox(height: 20),
          RdGroupLabel(field.name),
          if (field.type == 'number')
            TextField(
              controller: _numbers[field.id],
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (v) => _set(ref.read(rdMembersListFilterProvider).withField(field.id, v.trim())),
              decoration: InputDecoration(
                hintText: l10n.peopleEnterValue,
                filled: true,
                fillColor: p.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(p.buttonRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in rdMembersFieldChoices(l10n, field, widget.churches))
                  RdChoiceChip(
                    label: label,
                    selected: filter.fields[field.id] == value,
                    onTap:
                        () => _set(
                          ref
                              .read(rdMembersListFilterProvider)
                              .withField(field.id, filter.fields[field.id] == value ? null : value),
                        ),
                  ),
              ],
            ),
        ],
        if (widget.linkedTenants.isNotEmpty) ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.redesignMembersFilterOtherInstance),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in widget.linkedTenants)
                if (t.id != null)
                  RdChoiceChip(
                    label: t.shortName.isNotEmpty ? t.shortName : t.longName,
                    selected: filter.otherTenantId == t.id,
                    onTap:
                        () => _set(
                          ref
                              .read(rdMembersListFilterProvider)
                              .copyWith(otherTenantId: () => filter.otherTenantId == t.id ? null : t.id),
                        ),
                  ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        RdPrimaryButton(
          key: const Key('rd-members-filter-show'),
          label: l10n.redesignMembersFilterShow(count),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
