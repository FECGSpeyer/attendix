import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/type_circle.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/repositories/attendance_type_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart' show rdInputDecoration;
import '../../../redesign/presentation/widgets/manage/rd_settings_sheets.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../settings/presentation/pages/attendance_type_edit_page.dart' show buildNewAttendanceType;
import '../../team_org_utils.dart';
import 'quick_create_attendance.dart';

/// Who belongs to a Besprechung: groups and single persons (both empty =
/// everyone).
typedef MeetingCircle = ({List<int> groups, List<int> persons});

/// Beta "Neue Besprechung": the day and who is part of it, in one sheet.
/// The first Besprechung of a group also creates its Terminart (with
/// "Protokoll & Tagesordnung"), so nothing has to be set up before.
/// Returns the id of the new Termin, or null.
Future<int?> showNewMeetingSheet(BuildContext context) =>
    showRdSettingsSheet<int>(context, (_) => const _NewMeetingSheet());

class _NewMeetingSheet extends ConsumerStatefulWidget {
  const _NewMeetingSheet();

  @override
  ConsumerState<_NewMeetingSheet> createState() => _NewMeetingSheetState();
}

class _NewMeetingSheetState extends ConsumerState<_NewMeetingSheet> {
  late DateTime _day = _today;
  String? _typeId;

  /// The circle as edited here; null = the type's stored circle.
  MeetingCircle? _circle;
  bool _busy = false;
  bool _failed = false;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDay() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _day,
      firstDate: _today,
      lastDate: DateTime(_today.year + 5),
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<MeetingCircle?> _pickCircle(MeetingCircle current) => showRdSettingsSheet<MeetingCircle>(
        context,
        (_) => _CircleSheet(initial: current),
      );

  Future<void> _create(AttendanceType? type, MeetingCircle stored) async {
    if (_busy) return;
    final l10n = context.l10n;
    // UI_TENANT_HOIST: bind container + repository before the first await.
    final container = ProviderScope.containerOf(context, listen: false);
    final typeRepo = ref.read(attendanceTypeRepositoryWithTenantProvider);
    final tenantId = ref.read(currentTenantIdProvider);
    var circle = _circle;
    if (type == null && circle == null) {
      // The first Besprechung: who is part of it is a deliberate choice.
      circle = await _pickCircle(stored);
      if (circle == null || !mounted) return;
      setState(() => _circle = circle);
    }
    // The picker was open in between: never write into another group.
    if (tenantId == null || container.read(currentTenantIdProvider) != tenantId) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      var target = type;
      if (target == null) {
        target = await typeRepo.createTypeFromData({
          ...AttendanceTypeRepository.buildInsertData(
            buildNewAttendanceType(l10n.rdTeamMeetingTypeName)
                .copyWith(relevantGroups: circle!.groups, includeInAverage: false),
            typeRepo.currentTenantId,
          ),
          'relevant_persons': circle.persons,
          'enable_protocol': true,
        });
      } else if (circle != null && !_sameCircle(circle, stored)) {
        await typeRepo.updateCircle(target.id!, groups: circle.groups, persons: circle.persons);
        target = target.copyWith(relevantGroups: circle.groups);
      }
      container
        ..invalidate(attendanceTypesProvider)
        ..invalidate(protocolTypesProvider)
        ..invalidate(typeCirclePersonsProvider);
      final id = await createProtocolAttendance(container, target, _day, tenantId: tenantId);
      if (mounted) Navigator.of(context).pop(id);
    } catch (_) {
      container
        ..invalidate(attendanceTypesProvider)
        ..invalidate(protocolTypesProvider)
        ..invalidate(typeCirclePersonsProvider);
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  bool _sameCircle(MeetingCircle a, MeetingCircle b) =>
      a.groups.toSet().containsAll(b.groups) &&
      b.groups.toSet().containsAll(a.groups) &&
      a.persons.toSet().containsAll(b.persons) &&
      b.persons.toSet().containsAll(a.persons);

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final allTypes = ref.watch(attendanceTypesProvider);
    final protocolTypes = ref.watch(protocolTypesProvider);
    final circles = ref.watch(typeCirclePersonsProvider);
    final groups = ref.watch(groupsMapProvider).valueOrNull ?? const <int, String>{};
    final ready = allTypes.hasValue && protocolTypes.hasValue && circles.hasValue;
    final types = ready
        ? protocolAttendanceTypes(allTypes.requireValue, protocolTypes.requireValue)
        : const <AttendanceType>[];
    AttendanceType? type;
    for (final t in types) {
      if (t.id == _typeId) type = t;
    }
    type ??= types.firstOrNull;
    final MeetingCircle stored = (
      groups: type?.relevantGroups ?? const <int>[],
      persons: circles.valueOrNull?[type?.id] ?? const <int>[],
    );
    final circle = _circle ?? stored;

    String circleValue() {
      if (type == null && _circle == null) return l10n.rdTeamCircleChoose;
      if (typeCircleIsEveryone(circle.groups, circle.persons)) return l10n.rdTeamCircleEveryone;
      return [
        for (final id in circle.groups)
          if (groups[id] != null) groups[id]!,
        if (circle.persons.isNotEmpty) l10n.rdTeamCirclePersonsCount(circle.persons.length),
      ].join(', ');
    }

    final failedLoad = allTypes.hasError || protocolTypes.hasError || circles.hasError;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        RdSheetHead(
          title: l10n.rdTeamNewMeeting,
          doneLabel: l10n.commonCreate,
          onDone: !ready || _busy ? null : () => _create(type, stored),
        ),
        if (!ready)
          Padding(
            padding: const EdgeInsets.all(24),
            child: failedLoad
                ? Text(l10n.rdTeamLoadFailed, style: RdType.meta(p), textAlign: TextAlign.center)
                : const Center(child: CircularProgressIndicator.adaptive()),
          )
        else ...[
          RdGroupedList(
            children: [
              if (types.length > 1)
                RdListRow(
                  key: const ValueKey('rd-new-meeting-type'),
                  title: l10n.rdTeamMeetingKind,
                  value: type?.name,
                  onTap: _busy
                      ? null
                      : () async {
                          final picked = await showRdChoiceSheet<String>(
                            context,
                            title: l10n.rdTeamMeetingKind,
                            options: [for (final t in types) (t.id!, t.name)],
                            selected: type?.id,
                          );
                          if (picked != null && mounted) {
                            setState(() {
                              _typeId = picked;
                              _circle = null;
                            });
                          }
                        },
                ),
              RdListRow(
                key: const ValueKey('rd-new-meeting-day'),
                title: l10n.rdTeamMeetingDay,
                value: formatShortWeekdayDate(_day.toIso8601String()),
                onTap: _busy ? null : _pickDay,
              ),
              RdListRow(
                key: const ValueKey('rd-new-meeting-circle'),
                title: l10n.rdTeamWhoIsIn,
                value: circleValue(),
                onTap: _busy
                    ? null
                    : () async {
                        final picked = await _pickCircle(circle);
                        if (picked != null && mounted) setState(() => _circle = picked);
                      },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              type == null ? l10n.rdTeamWhoIsInHint : '${l10n.rdTeamWhoIsInHint} ${l10n.rdTeamCircleAppliesToType}',
              style: RdType.meta(p, size: 13),
            ),
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(l10n.dateDialogCreateFailed, style: RdType.meta(p, size: 13).copyWith(color: p.absent)),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
        ],
      ],
    );
  }
}

/// "Wer ist dabei?": everyone, or groups and single persons.
class _CircleSheet extends ConsumerStatefulWidget {
  const _CircleSheet({required this.initial});

  final MeetingCircle initial;

  @override
  ConsumerState<_CircleSheet> createState() => _CircleSheetState();
}

class _CircleSheetState extends ConsumerState<_CircleSheet> {
  late final Set<int> _groups = {...widget.initial.groups};
  late final Set<int> _persons = {...widget.initial.persons};
  String _query = '';

  Widget _check(bool on) {
    final p = context.rd;
    return Icon(
      on ? Icons.check_circle : Icons.radio_button_unchecked,
      size: 24,
      color: on ? p.primary : p.text2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final groupsAsync = ref.watch(groupsProvider);
    final playersAsync = ref.watch(playersProvider);
    // "Fertig" only with both lists loaded: an empty list would drop the
    // stored groups and persons and turn the circle into "everyone".
    final loaded = groupsAsync.hasValue && playersAsync.hasValue;
    final groups = (groupsAsync.valueOrNull ?? const <Group>[]).where((g) => g.id != null).toList();
    final players = (playersAsync.valueOrNull ?? const <Person>[])
        .where((x) => x.id != null && !x.pending && (x.left == null || x.left!.isEmpty))
        .toList()
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final x in players)
        if (query.isEmpty || x.fullName.toLowerCase().contains(query)) x,
    ];
    final everyone = _groups.isEmpty && _persons.isEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RdSheetHead(
          title: l10n.rdTeamWhoIsIn,
          onDone: !loaded
              ? null
              : () => Navigator.of(context).pop<MeetingCircle>((
            // Ids of groups and persons that no longer exist are dropped.
            groups: [for (final g in groups) if (_groups.contains(g.id)) g.id!],
                    persons: [for (final x in players) if (_persons.contains(x.id)) x.id!],
                  )),
        ),
        if (!loaded)
          Padding(
            padding: const EdgeInsets.all(24),
            child: groupsAsync.hasError || playersAsync.hasError
                ? Text(l10n.rdTeamLoadFailed, style: RdType.meta(p), textAlign: TextAlign.center)
                : const Center(child: CircularProgressIndicator.adaptive()),
          )
        else
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              RdGroupedList(
                children: [
                  RdListRow(
                    key: const ValueKey('rd-circle-everyone'),
                    title: l10n.rdTeamCircleEveryone,
                    showChevron: false,
                    trailing: _check(everyone),
                    onTap: () => setState(() {
                      _groups.clear();
                      _persons.clear();
                    }),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(l10n.rdTeamCircleLeadersHint, style: RdType.meta(p, size: 13)),
              ),
              if (groups.isNotEmpty) ...[
                const SizedBox(height: 18),
                RdGroupLabel(l10n.rdTeamCircleGroups),
                RdGroupedList(
                  children: [
                    for (final g in groups)
                      RdListRow(
                        key: ValueKey('rd-circle-group-${g.id}'),
                        title: g.name,
                        showChevron: false,
                        trailing: _check(_groups.contains(g.id)),
                        onTap: () => setState(() => _groups.contains(g.id) ? _groups.remove(g.id) : _groups.add(g.id!)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              RdGroupLabel(l10n.rdTeamCirclePersons),
              RdGroupedList(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                    child: TextField(
                      key: const ValueKey('rd-circle-search'),
                      style: TextStyle(fontSize: 17, color: p.text),
                      decoration: rdInputDecoration(p, l10n.rdTeamCircleSearch),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  for (final x in shown)
                    RdListRow(
                      key: ValueKey('rd-circle-person-${x.id}'),
                      title: x.fullName,
                      showChevron: false,
                      trailing: _check(_persons.contains(x.id)),
                      onTap: () => setState(() => _persons.contains(x.id) ? _persons.remove(x.id) : _persons.add(x.id!)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
