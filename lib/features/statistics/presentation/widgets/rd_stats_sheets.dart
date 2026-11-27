import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_providers.dart' show playerAttendancePercentagesProvider;
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/redesign/rd_words.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'
    show AppActionSheetAction, showAppActionSheet, showAppDatePicker;
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../settings/presentation/widgets/manage/rd_settings_sheets.dart' show RdListNote;
import '../../../today/data/providers/rd_today_providers.dart' show rdEventInfo;
import '../../data/providers/rd_stats_providers.dart';
import '../../data/rd_stats_logic.dart';
import 'rd_stats_figures.dart';
import 'rd_stats_rows.dart' show rdStatsPersonSortLabel, rdStatsSortLabel;

/// Sheet of one Termin: how the people split up and who was missing, by
/// status, with the reason. One action: "Termin öffnen".
Future<void> showRdStatsEventSheet(BuildContext context, RdStatsEvent event, List<Group> groups) {
  final router = GoRouter.of(context);
  return showRdSheet<void>(context, _EventSheet(event: event, groups: groups, router: router));
}

class _EventSheet extends StatelessWidget {
  const _EventSheet({required this.event, required this.groups, required this.router});

  final RdStatsEvent event;
  final List<Group> groups;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final info = rdEventInfo(event.attendance, event.type);
    final groupName = {for (final g in groups) if (g.id != null) g.id!: g.name};
    String name(PersonAttendance pa) => '${pa.firstName ?? ''} ${pa.lastName ?? ''}'.trim();
    final missing = [
      (l10n.commonStatusAbsent, [for (final pa in event.rows) if (pa.status == AttendanceStatus.absent) pa]),
      (l10n.commonStatusExcused, [for (final pa in event.rows) if (pa.status == AttendanceStatus.excused) pa]),
      (l10n.commonStatusLateShort, [
        for (final pa in event.rows)
          if (pa.status == AttendanceStatus.late || pa.status == AttendanceStatus.lateExcused) pa,
      ]),
      (l10n.commonStatusNeutral, [for (final pa in event.rows) if (pa.status == AttendanceStatus.neutral) pa]),
    ];
    for (final (_, list) in missing) {
      list.sort((a, b) => name(a).toLowerCase().compareTo(name(b).toLowerCase()));
    }
    final id = event.attendance.id;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Semantics(
          header: true,
          child: Text('${info.title} · ${rdStatsDay(event.date)}', style: RdType.cardTitle(p)),
        ),
        const SizedBox(height: 2),
        Text(
          [rdPercent(event.percent), if (info.timeRange.isNotEmpty) info.timeRange].join(' · '),
          style: RdType.meta(p, size: 14),
        ),
        const SizedBox(height: 12),
        RdStatsSplitBar(counts: event.counts),
        if (missing.every((m) => m.$2.isEmpty)) ...[
          const SizedBox(height: 16),
          Text(event.rows.isEmpty ? l10n.rdStatsEventEmpty : l10n.rdStatsEventAllThere, style: RdType.body(p)),
        ],
        for (final (label, list) in missing)
          if (list.isNotEmpty) ...[
            const SizedBox(height: 16),
            RdGroupLabel(l10n.rdStatsEventGroup(label, list.length)),
            RdGroupedList(
              children: [
                for (final pa in list)
                  RdListRow(
                    title: name(pa),
                    subtitle: (pa.notes ?? '').trim().isEmpty ? null : pa.notes!.trim(),
                    value: groupName[pa.instrument],
                  ),
              ],
            ),
          ],
        if (id != null) ...[
          const SizedBox(height: 20),
          RdPrimaryButton(
            label: l10n.rdStatsEventOpen,
            onPressed: () {
              Navigator.of(context).pop();
              router.push(RedesignRoutes.event(id));
            },
          ),
        ],
      ],
    );
  }
}

/// Which list the "Sortieren" row of the filter sheet orders.
enum RdStatsSortFor { events, people }

/// "Filter" of the Auswertung: Terminarten and Register, with [sort] also
/// the order of the Termine or the Personen ("Sortieren & Filtern").
/// Changes apply at once; the button shows how many Termine are left.
Future<void> showRdStatsFilterSheet(
  BuildContext context, {
  required List<AttendanceType> types,
  required List<Group> groups,
  RdStatsSortFor? sort,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.rd.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (sheet, controller) => _FilterSheet(controller: controller, types: types, groups: groups, sort: sort),
    ),
  );
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.controller, required this.types, required this.groups, required this.sort});

  final ScrollController controller;
  final List<AttendanceType> types;
  final List<Group> groups;
  final RdStatsSortFor? sort;

  Future<void> _pickSort<T>(
    BuildContext context,
    WidgetRef ref,
    StateProvider<T> provider,
    List<T> values,
    String Function(T) label,
  ) async {
    final current = ref.read(provider);
    final choice = await showAppActionSheet<T>(
      context,
      title: context.l10n.redesignWorksSort,
      actions: [
        for (final s in values)
          AppActionSheetAction(value: s, icon: s == current ? Icons.check : null, label: label(s)),
      ],
    );
    if (choice != null) ref.read(provider.notifier).state = choice;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final filter = ref.watch(rdStatsFilterProvider);
    final shown = rdStatsTypeIds(filter, types);
    final events = ref.watch(rdStatsResultProvider).events.length;
    void set(RdStatsFilter next) => ref.read(rdStatsFilterProvider.notifier).state = next;
    void toggleType(String id) =>
        set(rdStatsFilterWithTypes(filter, shown.contains(id) ? ({...shown}..remove(id)) : {...shown, id}, types));

    return ListView(
      controller: controller,
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
              child: Semantics(
                header: true,
                child: Text(sort != null ? l10n.redesignWorksFilterTitle : l10n.redesignWorksFilter, style: RdType.section(p)),
              ),
            ),
            RdTextLink(
              label: l10n.redesignWorksFilterReset,
              onTap: () {
                set(const RdStatsFilter());
                switch (sort) {
                  case RdStatsSortFor.events:
                    ref.read(rdStatsEventSortProvider.notifier).state = RdStatsEventSort.newest;
                  case RdStatsSortFor.people:
                    ref.read(rdStatsPersonSortProvider.notifier).state = RdStatsPersonSort.fewest;
                  case null:
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (sort != null) ...[
          RdGroupedList(
            children: [
              RdListRow(
                key: const Key('rd-stats-sort'),
                title: l10n.redesignWorksSort,
                value: sort == RdStatsSortFor.events
                    ? rdStatsSortLabel(l10n, ref.watch(rdStatsEventSortProvider))
                    : rdStatsPersonSortLabel(l10n, ref.watch(rdStatsPersonSortProvider)),
                onTap: () => sort == RdStatsSortFor.events
                    ? _pickSort(context, ref, rdStatsEventSortProvider, RdStatsEventSort.values,
                        (s) => rdStatsSortLabel(l10n, s))
                    : _pickSort(context, ref, rdStatsPersonSortProvider, RdStatsPersonSort.values,
                        (s) => rdStatsPersonSortLabel(l10n, s)),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        RdGroupLabel(l10n.rdStatsFilterTypes),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in types)
              if (t.id != null)
                RdChoiceChip(label: t.name, selected: shown.contains(t.id), onTap: () => toggleType(t.id!)),
          ],
        ),
        RdListNote(l10n.rdStatsFilterTypesHint),
        if (rdStatsGroups(groups).length > 1) ...[
          const SizedBox(height: 20),
          RdGroupLabel(l10n.rdWordsGroups(ref.watch(rdGroupKindProvider))),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in rdStatsGroups(groups))
                RdChoiceChip(
                  label: g.name,
                  selected: filter.groupIds.contains(g.id),
                  onTap: () => set(filter.toggleGroup(g.id!)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        RdPrimaryButton(label: l10n.rdStatsFilterShow(events), onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// "Eigener Zeitraum": Von and Bis. Returns the chosen range, null when
/// closed.
Future<DateTimeRange?> showRdStatsRangeSheet(BuildContext context, DateTimeRange initial) =>
    showRdSheet<DateTimeRange>(context, _RangeSheet(initial: initial));

class _RangeSheet extends StatefulWidget {
  const _RangeSheet({required this.initial});

  final DateTimeRange initial;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  late DateTime _from = widget.initial.start;
  late DateTime _to = widget.initial.end;

  Future<void> _pick({required bool from}) async {
    final today = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      // Von ≤ Bis, nothing after today (the Auswertung counts past Termine).
      firstDate: from ? DateTime(2015) : _from,
      lastDate: from ? _to : DateTime(today.year, today.month, today.day),
    );
    if (picked == null || !mounted) return;
    setState(() => from ? _from = picked : _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fmt = DateFormat(dateFmt());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdSheetTitle(l10n.rdStatsRangeTitle),
          RdGroupedList(
            children: [
              RdListRow(title: l10n.rdStatsRangeFrom, value: fmt.format(_from), onTap: () => _pick(from: true)),
              RdListRow(title: l10n.rdStatsRangeTo, value: fmt.format(_to), onTap: () => _pick(from: false)),
            ],
          ),
          const SizedBox(height: 20),
          RdPrimaryButton(
            label: l10n.rdStatsRangeShow,
            onPressed: () => Navigator.of(context).pop(DateTimeRange(start: _from, end: _to)),
          ),
        ],
      ),
    );
  }
}

/// "Zählt zur Anwesenheitsquote" below "So wird gezählt": the Terminarten
/// that count for the percentages everywhere (Mitglieder, Heute,
/// Auswertung). Same value as the switch on the Terminart.
class RdStatsCountedTypes extends ConsumerWidget {
  const RdStatsCountedTypes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final types = rdStatsTypesOf(ref.watch(attendanceTypesProvider), ref.watch(currentTenantIdProvider));
    final names = [for (final t in types) if (t.includeInAverage) t.name];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('rd-stats-counted-types'),
              // Under "Was zur Anwesenheitsquote zählt": just the Terminarten.
              title: l10n.rdStatsCountedTypesRow,
              subtitle: names.isEmpty ? l10n.rdStatsCountedTypesNone : names.join(', '),
              onTap: types.isEmpty ? null : () => showRdSheet<void>(context, const _CountedTypesSheet()),
            ),
          ],
        ),
        RdListNote(l10n.rdStatsCountedTypesHint),
      ],
    );
  }
}

class _CountedTypesSheet extends ConsumerStatefulWidget {
  const _CountedTypesSheet();

  @override
  ConsumerState<_CountedTypesSheet> createState() => _CountedTypesSheetState();
}

class _CountedTypesSheetState extends ConsumerState<_CountedTypesSheet> {
  /// The type being saved; switches are disabled meanwhile.
  String? _saving;

  /// Saves for the group shown when the change started; aborts when the
  /// group changed meanwhile. Everything used after the await is bound
  /// before it.
  Future<void> _set(AttendanceType type, bool value) async {
    final id = type.id;
    final tenantId = ref.read(currentTenantIdProvider);
    if (_saving != null || id == null || tenantId == null || DemoGuard.blocked()) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = container.read(attendanceTypeNotifierProvider.notifier);
    final failed = context.l10n.rdSettingsSaveFailed;
    setState(() => _saving = id);
    try {
      final saved = await notifier.updateType(id, {'include_in_average': value});
      if (saved == null) {
        if (mounted) ToastHelper.showError(context, failed);
        return;
      }
      // The percentages of the members follow the new choice.
      if (container.read(currentTenantIdProvider) == tenantId) container.invalidate(playerAttendancePercentagesProvider);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, failed);
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final types = rdStatsTypesOf(ref.watch(attendanceTypesProvider), ref.watch(currentTenantIdProvider));
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        RdSheetTitle(l10n.rdStatsCountedTypes),
        RdGroupedList(
          children: [
            for (final t in types)
              if (t.id != null)
                RdSwitchRow(
                  key: ValueKey('rd-stats-counted-${t.id}'),
                  title: t.name,
                  value: t.includeInAverage,
                  onChanged: _saving == null ? (v) => _set(t, v) : null,
                ),
          ],
        ),
        RdListNote(l10n.rdStatsCountedTypesHint),
      ],
    );
  }
}
