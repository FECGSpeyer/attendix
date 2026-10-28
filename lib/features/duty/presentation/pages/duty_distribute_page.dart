import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/duty_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duty_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/duty/person_unavailability.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';

/// Opens "Dienste verteilen". Returns true when assignments were saved.
Future<bool> openDutyDistributePage(BuildContext context) async {
  final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => const DutyDistributePage(),
  ));
  return result ?? false;
}

class _PreviewRow {
  _PreviewRow({
    required this.termin,
    required this.existing,
    required this.picked,
    required this.candidates,
  });

  final DutyTermin termin;

  /// Already occupying persons (kept as they are)
  final List<PersonAttendance> existing;

  /// Newly picked persons of this run
  List<PersonAttendance> picked;
  final List<PersonAttendance> candidates;

  int get missing => (termin.required - existing.length - picked.length).clamp(0, 999);
}

/// "Dienste verteilen": fills the open places of duty Termine in a period
/// fairly (fewest duties first), shows a preview that can be changed, and
/// assigns on save (everyone gets a push and confirms as usual).
class DutyDistributePage extends ConsumerStatefulWidget {
  const DutyDistributePage({super.key});

  @override
  ConsumerState<DutyDistributePage> createState() => _DutyDistributePageState();
}

class _DutyDistributePageState extends ConsumerState<DutyDistributePage> {
  bool _preview = false;
  late DateTime _from;
  late DateTime _to;
  Set<String> _selectedTypeIds = {};
  int _maxPerPerson = 2;
  bool _notTwiceSameDay = true;
  bool _loading = false;
  bool _saving = false;

  List<_PreviewRow> _rows = [];
  List<DutyTermin> _termine = [];

  /// SOL_FIX2: duties of the other duty types in the period; only used to
  /// block days ("Nicht zweimal am selben Tag"), never filled.
  List<DutyTermin> _otherTermine = [];
  Map<int, int> _baseCounts = {};
  List<PersonUnavailability> _unavailability = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month + 1, 1);
    _to = DateTime(now.year, now.month + 2, 0);
    _selectedTypeIds = ref.read(dutyTypesProvider).map((t) => t.id).whereType<String>().toSet();
  }

  String _fmt(DateTime d) => DateFormat(dateFmt()).format(d);

  String _dateLabel(DutyTermin t) {
    final d = DateTime.tryParse(t.attendance.date)?.toLocal();
    if (d == null) return t.attendance.date;
    final time = (t.attendance.startTime ?? t.type.startTime ?? '');
    final timeLabel = time.length >= 5 ? ' · ${time.substring(0, 5)}' : '';
    return '${weekdayShortNames[d.weekday - 1]}, ${d.day}.${d.month}.$timeLabel';
  }

  Future<void> _pickDate(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => from ? _from = picked : _to = picked);
  }

  Future<void> _calculate() async {
    if (_selectedTypeIds.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.dutyChooseTypeMin);
      return;
    }
    final l10n = context.l10n;
    setState(() => _loading = true);
    try {
      final repo = ref.read(dutyRepositoryWithTenantProvider);
      final dutyTypes = ref.read(dutyTypesProvider);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final fromDay = DateTime(_from.year, _from.month, _from.day);
      final toDay = DateTime(_to.year, _to.month, _to.day, 23, 59, 59);
      // SOL_FIX2: load all duty types so assignments of every duty in the
      // period count for the same-day lock; only selected types are filled.
      final results = await Future.wait([
        repo.getUpcomingDutyTermine(dutyTypes, from: fromDay.isBefore(today) ? today : fromDay, until: toDay),
        repo.getUnavailabilityForTenant(),
      ]);
      final all = results[0] as List<DutyTermin>;
      _termine = all.where((t) => _selectedTypeIds.contains(t.type.id)).toList();
      _otherTermine = all.where((t) => !_selectedTypeIds.contains(t.type.id)).toList();
      _unavailability = results[1] as List<PersonUnavailability>;
      final personIds = _termine
          .expand((t) => t.persons.map((p) => p.personId))
          .whereType<int>()
          .toSet()
          .toList();
      // Fairness looks at the whole period, also at duties of other duty types.
      _baseCounts = await repo.getDutyCounts(
        personIds,
        fromDay,
        toDay,
        typeIds: dutyTypes.map((t) => t.id).whereType<String>().toList(),
      );
      _run();
      setState(() => _preview = true);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, l10n.dutyFlutterErrorWith(friendlyErrorMessage(e)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PersonAttendance> _candidatesOf(DutyTermin t) => t.persons
      .where((p) =>
          (p.dutyState ?? '').isEmpty &&
          !isCancelled(p) &&
          p.personId != null &&
          matchingUnavailability(_unavailability, p.personId!, t.attendance.date, t.attendance.typeId) == null)
      .toList();

  /// (Re-)runs the distribution; ties are random, so every run can differ.
  void _run() {
    // SOL_FIX2: fully staffed duties stay in (open: 0) so their people count
    // for "Nicht zweimal am selben Tag" (Ionic dropped them before computing).
    final slots = _termine
        .where((t) => t.attendance.id != null)
        .map((t) => DutySlot(
              attendanceId: t.attendance.id!,
              date: t.attendance.date,
              candidates: _candidatesOf(t).map((p) => p.personId!).toList(),
              occupied: t.persons.where(occupiesDuty).map((p) => p.personId).whereType<int>().toList(),
              open: max(0, t.required - t.occupied),
            ))
        .toList()
      ..addAll(_otherTermine.where((t) => t.attendance.id != null).map((t) => DutySlot(
            attendanceId: t.attendance.id!,
            date: t.attendance.date,
            candidates: const [],
            occupied: t.persons.where(occupiesDuty).map((p) => p.personId).whereType<int>().toList(),
            open: 0,
          )));
    final result = distributeDuties(
      slots,
      _baseCounts,
      maxPerPerson: _maxPerPerson,
      notTwiceSameDay: _notTwiceSameDay,
    );
    setState(() {
      _rows = _termine.map((t) {
        final pickedIds = result[t.attendance.id] ?? const <int>[];
        return _PreviewRow(
          termin: t,
          existing: t.persons.where(occupiesDuty).toList(),
          picked: pickedIds
              .map((id) => t.persons.where((p) => p.personId == id).firstOrNull)
              .whereType<PersonAttendance>()
              .toList(),
          candidates: _candidatesOf(t),
        );
      }).toList();
    });
  }

  /// Duties per person id: existing in the period plus planned in this run.
  Map<int, ({int count, int planned})> _countsById() {
    final result = <int, ({int count, int planned})>{
      for (final e in _baseCounts.entries) e.key: (count: e.value, planned: 0),
    };
    for (final row in _rows) {
      for (final pa in row.picked) {
        final id = pa.personId!;
        final c = result[id] ?? (count: 0, planned: 0);
        result[id] = (count: c.count + 1, planned: c.planned + 1);
      }
    }
    return result;
  }

  int get _plannedTotal => _rows.fold(0, (sum, r) => sum + r.picked.length);
  int get _missingTotal => _rows.fold(0, (sum, r) => sum + r.missing);

  /// Swap or remove a picked person, or fill a still missing place.
  Future<void> _change(_PreviewRow row, [PersonAttendance? current]) async {
    final taken = row.picked.map((p) => p.personId).toSet();
    final counts = _countsById();
    int countOf(PersonAttendance pa) => counts[pa.personId]?.count ?? 0;
    final options = row.candidates.where((c) => !taken.contains(c.personId)).toList()
      ..sort((a, b) {
        final c = countOf(a).compareTo(countOf(b));
        return c != 0 ? c : a.fullName.compareTo(b.fullName);
      });
    if (options.isEmpty && current == null) {
      ToastHelper.showWarning(context, context.l10n.dutyNobodyElse);
      return;
    }
    const none = '__none';
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(current != null ? context.l10n.dutySwap(current.firstName ?? '') : context.l10n.dutyChoosePerson),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('${row.termin.title} · ${_dateLabel(row.termin)}',
                style: const TextStyle(color: AppColors.medium)),
          ),
          if (current != null)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(none),
              child: Text(context.l10n.dutyNobody),
            ),
          for (final o in options)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(o.id),
              child: Text('${o.fullName} (${countOf(o)})'),
            ),
        ],
      ),
    );
    if (value == null) return;
    final next = value == none ? null : options.where((o) => o.id == value).firstOrNull;
    setState(() {
      row.picked = [
        ...row.picked.where((p) => p != current),
        if (next != null) next,
      ];
    });
  }

  Future<void> _save() async {
    if (_plannedTotal == 0) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _saving = true);
    final notifier = ref.read(dutyNotifierProvider.notifier);
    var ok = true;
    for (final row in _rows.where((r) => r.picked.isNotEmpty)) {
      ok = await notifier.assign(
            row.picked.map((p) => p.id).whereType<String>().toList(),
            row.termin.attendance.id!,
          ) &&
          ok;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      ToastHelper.showError(context, context.l10n.svcAssignFailed);
      return;
    }
    final total = _plannedTotal;
    ToastHelper.showSuccess(
      context,
      context.l10n.dutyAssignedToast(total),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _preview
            ? IconButton(
                icon: const BackButtonIcon(),
                tooltip: context.l10n.commonBack,
                onPressed: () => setState(() => _preview = false),
              )
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.commonCancel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
        title: Text(_preview ? context.l10n.teamOrgProposal : context.l10n.attListDistributeDuties),
        actions: [
          if (_preview)
            IconButton(
              icon: const Icon(Icons.shuffle),
              tooltip: context.l10n.dutyRedistribute,
              onPressed: _run,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _preview
              ? _buildPreview()
              : _buildRules(),
      bottomNavigationBar: _preview && _rows.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: FilledButton(
                  onPressed: _saving || _plannedTotal == 0 ? null : _save,
                  child: Text(_plannedTotal > 0
                      ? context.l10n.dutyFlutterSaveAssignments(_plannedTotal)
                      : context.l10n.dutyFlutterNothingToDistribute),
                ),
              ),
            )
          : null,
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _buildRules() {
    final dutyTypes = ref.watch(dutyTypesProvider);
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: [
        _header(context.l10n.dutyPeriod),
        Card(
          child: Column(children: [
            ListTile(title: Text(context.l10n.dutyFrom), trailing: Text(_fmt(_from)), onTap: () => _pickDate(true)),
            ListTile(title: Text(context.l10n.dutyTo), trailing: Text(_fmt(_to)), onTap: () => _pickDate(false)),
          ]),
        ),
        if (dutyTypes.length > 1) ...[
          _header(context.l10n.dutyEventTypes),
          Card(
            child: Column(children: [
              for (final t in dutyTypes)
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _selectedTypeIds.contains(t.id),
                  title: Text(t.name),
                  onChanged: (_) => setState(() {
                    if (!_selectedTypeIds.remove(t.id)) _selectedTypeIds.add(t.id!);
                  }),
                ),
            ]),
          ),
        ],
        _header(context.l10n.dutyRules),
        Card(
          child: Column(children: [
            ListTile(
              title: Text(context.l10n.dutyMaxPerPerson),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: context.l10n.attListLess,
                    onPressed: _maxPerPerson <= 1 ? null : () => setState(() => _maxPerPerson--),
                  ),
                  Text('$_maxPerPerson'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: context.l10n.attListMore,
                    onPressed: _maxPerPerson >= 10 ? null : () => setState(() => _maxPerPerson++),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              title: Text(context.l10n.dutyNotTwiceSameDay),
              value: _notTwiceSameDay,
              onChanged: (v) => setState(() => _notTwiceSameDay = v),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingS),
          child: Text(
            context.l10n.dutyDistributeHint,
            style: const TextStyle(color: AppColors.medium, fontSize: 13),
          ),
        ),
        const SizedBox(height: AppDimensions.paddingM),
        FilledButton(onPressed: _calculate, child: Text(context.l10n.dutyCalculate)),
      ],
    );
  }

  Widget _buildPreview() {
    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Text(context.l10n.dutyNoDutyEvents, textAlign: TextAlign.center),
        ),
      );
    }
    final planned = _plannedTotal;
    final missing = _missingTotal;
    final summary = missing > 0
        ? context.l10n.dutyPlannedSummaryMissing(planned, missing)
        : context.l10n.dutyPlannedSummary(planned);

    final names = <int, String>{
      for (final t in _termine)
        for (final p in t.persons)
          if (p.personId != null) p.personId!: p.fullName,
    };
    final counts = _countsById().entries.where((e) => names.containsKey(e.key)).toList()
      ..sort((a, b) {
        final c = b.value.count.compareTo(a.value.count);
        return c != 0 ? c : names[a.key]!.compareTo(names[b.key]!);
      });

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: [
        Text('$summary ${context.l10n.dutyTapToSwap}', style: const TextStyle(color: AppColors.medium)),
        const SizedBox(height: AppDimensions.paddingS),
        Card(
          child: Column(children: [
            for (final row in _rows)
              ListTile(
                title: Text(_dateLabel(row.termin)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${row.termin.title} · ${row.existing.length + row.picked.length}/${row.termin.required}'),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final pa in row.existing)
                          Chip(
                            label: Text(pa.firstName ?? ''),
                            backgroundColor: AppColors.medium.withAlpha(31),
                            visualDensity: VisualDensity.compact,
                          ),
                        for (final pa in row.picked)
                          ActionChip(
                            label: Text(pa.firstName ?? '', style: const TextStyle(color: Colors.white)),
                            backgroundColor: AppColors.primary,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _change(row, pa),
                          ),
                        for (var i = 0; i < row.missing; i++)
                          ActionChip(
                            label: Text(context.l10n.dutyOpen, style: const TextStyle(color: AppColors.danger)),
                            side: const BorderSide(color: AppColors.danger),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _change(row),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ]),
        ),
        _header(context.l10n.dutyDutiesPerPerson),
        Card(
          child: Column(children: [
            for (final e in counts)
              ListTile(
                dense: true,
                title: Text(names[e.key]!),
                trailing: Text('${e.value.count}${e.value.planned > 0 ? ' ${context.l10n.dutyFlutterPlannedNew(e.value.planned)}' : ''}'),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingS),
          child: Text(context.l10n.dutyGreyHint,
              style: const TextStyle(color: AppColors.medium, fontSize: 13)),
        ),
      ],
    );
  }
}
