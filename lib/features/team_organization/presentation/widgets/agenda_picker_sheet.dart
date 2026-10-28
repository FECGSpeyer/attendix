import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../team_org_utils.dart';

/// "Themen aufnehmen": picks open topics (and creates new ones inline) and
/// inserts them as TOPs into a Termin's Ablaufplan. Unchecking a TOP that is
/// already planned takes it out of the plan again. Returns the saved plan.
Future<Map<String, dynamic>?> showAgendaPickerSheet(
  BuildContext context, {
  required ProtocolAttendance attendance,
  ProtocolType? type,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AgendaPickerSheet(attendance: attendance, type: type),
  );
}

class _Row {
  _Row({required this.item, required this.selected, required this.inPlan, required this.duration, this.postponedOn});
  final AgendaItem item;
  bool selected;
  final bool inPlan;
  int duration;

  /// null = not postponed; '' = postponed without date.
  final String? postponedOn;
}

class AgendaPickerSheet extends ConsumerStatefulWidget {
  const AgendaPickerSheet({super.key, required this.attendance, this.type});
  final ProtocolAttendance attendance;
  final ProtocolType? type;

  @override
  ConsumerState<AgendaPickerSheet> createState() => _AgendaPickerSheetState();
}

class _AgendaPickerSheetState extends ConsumerState<AgendaPickerSheet> {
  bool _loading = true;
  bool _saving = false;
  String _search = '';
  final _searchController = TextEditingController();
  List<_Row> _postponedRows = [];
  List<_Row> _otherRows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int? _durationInPlan(AgendaItem item) {
    for (final f in widget.attendance.fields) {
      if (fieldId(f) == agendaFieldId(item.id!)) {
        final m = fieldMinutes(f);
        return m > 0 ? m : null;
      }
    }
    return null;
  }

  Future<void> _load() async {
    try {
      final items = await ref.read(agendaItemRepositoryWithTenantProvider).getAgendaItems();
      final protocols = await ref.read(protocolRepositoryWithTenantProvider).getProtocols();
      final postponed = postponedAgendaItemIds(protocols);
      final postponedDate = <String, String>{};
      for (final p in protocols) {
        for (final e in p.outcomes.entries) {
          final id = e.key.replaceFirst(RegExp('^agenda-'), '');
          if (e.value == 'postponed' && postponed.contains(id) && !postponedDate.containsKey(id) && p.attendance?.date != null) {
            postponedDate[id] = p.attendance!.date!;
          }
        }
      }
      final inPlan = widget.attendance.fields.map(fieldAgendaItemId).whereType<String>().toSet();
      final usePostponed = widget.type?.suggestPostponed != false;
      final sorted = sortTopicsForPlanning(items, usePostponed ? postponed : <String>{});
      final rows = sorted
          .map((item) => _Row(
                item: item,
                selected: inPlan.contains(item.id),
                inPlan: inPlan.contains(item.id),
                duration: _durationInPlan(item) ?? defaultTopicDuration(item, widget.type),
                postponedOn: postponed.contains(item.id) ? (postponedDate[item.id] ?? '') : null,
              ))
          .toList();
      setState(() {
        _postponedRows = usePostponed ? rows.where((r) => r.postponedOn != null).toList() : [];
        _otherRows = usePostponed ? rows.where((r) => r.postponedOn == null).toList() : rows;
      });
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Themen konnten nicht geladen werden');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matches(_Row r) {
    final term = _search.trim().toLowerCase();
    return term.isEmpty ||
        r.item.title.toLowerCase().contains(term) ||
        (r.item.description ?? '').toLowerCase().contains(term);
  }

  List<_Row> get _all => [..._postponedRows, ..._otherRows];
  List<_Row> get _newSelections => _all.where((r) => r.selected && !r.inPlan).toList();
  List<_Row> get _removals => _all.where((r) => r.inPlan && !r.selected).toList();
  bool get _hasChanges => _newSelections.isNotEmpty || _removals.isNotEmpty;

  bool get _canCreateFromSearch {
    final term = _search.trim().toLowerCase();
    return term.isNotEmpty && !_all.any((r) => r.item.title.trim().toLowerCase() == term);
  }

  String get _confirmLabel {
    final added = _newSelections.length;
    final removed = _removals.length;
    final minutes = _newSelections.fold<int>(0, (s, r) => s + r.duration);
    final parts = <String>[];
    if (added > 0) parts.add('$added ${added == 1 ? 'Thema' : 'Themen'} aufnehmen · $minutes min');
    if (removed > 0) parts.add('$removed ${removed == 1 ? 'Thema' : 'Themen'} entfernen');
    return parts.isEmpty ? 'Themen auswählen' : parts.join(' · ');
  }

  String get _insertHint {
    final after = insertAfterName(widget.attendance.fields);
    final where = after != null ? 'Wird nach „$after“ eingefügt' : 'Wird am Anfang eingefügt';
    if (!_hasChanges) return where;
    final plan = planWithTopics(
      widget.attendance,
      widget.type,
      _newSelections.map((r) => (item: r.item, duration: r.duration)).toList(),
      removeIds: _removals.map((r) => r.item.id!).toList(),
    );
    final end = DateTime.tryParse(plan['end']?.toString() ?? '');
    return end != null ? '$where · Ende neu ${DateFormat('HH:mm').format(end)}' : where;
  }

  Future<void> _createFromSearch() async {
    final title = _search.trim();
    if (title.isEmpty) return;
    try {
      final item = await ref
          .read(agendaItemNotifierProvider.notifier)
          .create(AgendaItem(title: title, status: 'open', priority: 'medium'));
      setState(() {
        _otherRows = [
          _Row(item: item, selected: true, inPlan: false, duration: defaultTopicDuration(item, widget.type)),
          ..._otherRows,
        ];
        _search = '';
        _searchController.clear();
      });
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Thema konnte nicht angelegt werden');
    }
  }

  Future<void> _confirm() async {
    final selections = _newSelections.map((r) => (item: r.item, duration: r.duration)).toList();
    final removeIds = _removals.map((r) => r.item.id!).toList();
    if ((selections.isEmpty && removeIds.isEmpty) || _saving) return;
    setState(() => _saving = true);
    try {
      final plan = await addTopicsToAttendance(
        ref.read(protocolRepositoryWithTenantProvider),
        widget.attendance,
        widget.type,
        selections,
        removeIds: removeIds,
      );
      ref.invalidate(upcomingProtocolAttendancesProvider);
      if (!mounted) return;
      final added = selections.length;
      final removed = removeIds.length;
      final text = removed == 0
          ? (added == 1 ? 'Thema aufgenommen' : '$added Themen aufgenommen')
          : added == 0
              ? (removed == 1 ? 'Thema aus dem Ablaufplan entfernt' : '$removed Themen aus dem Ablaufplan entfernt')
              : 'Tagesordnung aktualisiert';
      ToastHelper.showSuccess(context, text);
      Navigator.of(context).pop(plan);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Ablaufplan konnte nicht gespeichert werden');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _rowTile(_Row row) {
    final parts = <String>[
      if (row.item.responsiblePerson.fullName.isNotEmpty) row.item.responsiblePerson.fullName,
      priorityLabels[row.item.priority] ?? '',
      if (row.inPlan) row.selected ? 'bereits im Ablaufplan' : 'wird aus dem Ablaufplan entfernt',
    ].where((s) => s.isNotEmpty).toList();
    String? postponedLabel;
    if (row.postponedOn != null) {
      final d = DateTime.tryParse(row.postponedOn!)?.toLocal();
      postponedLabel = d != null ? 'Vertagt ${DateFormat('dd.MM.').format(d)}' : 'Vertagt';
    }
    return ListTile(
      onTap: () => setState(() => row.selected = !row.selected),
      leading: Icon(
        row.selected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: row.selected ? AppColors.primary : AppColors.medium,
      ),
      title: Text(row.item.title),
      subtitle: Text([if (postponedLabel != null) postponedLabel, ...parts].join(' · ')),
      trailing: row.selected && !row.inPlan
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Kürzer',
                  icon: const Icon(Icons.remove),
                  onPressed: () => setState(() => row.duration = (row.duration - 5).clamp(5, 999)),
                ),
                Text('${row.duration} min'),
                IconButton(
                  tooltip: 'Länger',
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => row.duration += 5),
                ),
              ],
            )
          : Text('${row.duration} min'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visiblePostponed = _postponedRows.where(_matches).toList();
    final visibleOthers = _otherRows.where(_matches).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Schließen',
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Themen aufnehmen'),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Thema suchen oder neu anlegen',
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      if (_canCreateFromSearch)
                        ListTile(
                          leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                          title: Text('„${_search.trim()}“ als neues Thema anlegen',
                              style: const TextStyle(color: AppColors.primary)),
                          onTap: _createFromSearch,
                        ),
                      if (visiblePostponed.isNotEmpty) ...[
                        const _Header('Vertagt aus letzter Sitzung'),
                        ...visiblePostponed.map(_rowTile),
                      ],
                      const _Header('Themenspeicher'),
                      ...visibleOthers.map(_rowTile),
                      if (visibleOthers.isEmpty)
                        ListTile(
                          title: Text(
                            _search.trim().isNotEmpty
                                ? 'Kein passendes Thema gefunden.'
                                : 'Keine offenen Themen. Lege oben ein neues an.',
                            style: const TextStyle(color: AppColors.medium),
                          ),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_insertHint, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppDimensions.paddingS),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: !_hasChanges || _saving ? null : _confirm,
                      child: Text(_confirmLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}
