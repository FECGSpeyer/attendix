import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../planning/presentation/widgets/ion_items.dart';
import '../../../../l10n/l10n.dart';
import '../../team_org_utils.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

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
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    // Ionic: ion-content color="light".
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
    final agendaItemRepo = ref.read(agendaItemRepositoryWithTenantProvider);
    final protocolRepo = ref.read(protocolRepositoryWithTenantProvider);
    try {
      final items = await agendaItemRepo.getAgendaItems();
      final protocols = await protocolRepo.getProtocols();
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
      if (mounted) ToastHelper.showError(context, context.l10n.agendaLoadFailed);
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
    final l10n = context.l10n;
    final parts = <String>[];
    if (added > 0) parts.add(l10n.agendaAddTopics(added, minutes));
    if (removed > 0) parts.add(l10n.agendaRemoveTopics(removed));
    return parts.isEmpty ? l10n.agendaChooseTopics : parts.join(' · ');
  }

  String get _insertHint {
    final after = insertAfterName(widget.attendance.fields);
    final l10n = context.l10n;
    final where = after != null ? l10n.agendaInsertAfter(after) : l10n.agendaInsertAtStart;
    if (!_hasChanges) return where;
    final plan = planWithTopics(
      widget.attendance,
      widget.type,
      _newSelections.map((r) => (item: r.item, duration: r.duration)).toList(),
      removeIds: _removals.map((r) => r.item.id!).toList(),
    );
    final end = DateTime.tryParse(plan['end']?.toString() ?? '');
    return end != null ? l10n.agendaNewEnd(where, DateFormat('HH:mm').format(end)) : where;
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
      if (mounted) ToastHelper.showError(context, context.l10n.agendaCreateFailed);
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
      final l10n = context.l10n;
      final text = removed == 0
          ? (added == 1 ? l10n.agendaTopicAdded : l10n.agendaTopicsAdded(added))
          : added == 0
              ? (removed == 1 ? l10n.agendaTopicRemoved : l10n.agendaTopicsRemoved(removed))
              : l10n.agendaAgendaUpdated;
      ToastHelper.showSuccess(context, text);
      Navigator.of(context).pop(plan);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.agendaPlanSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _rowTile(_Row row) {
    final l10n = context.l10n;
    final parts = <String>[
      if (row.item.responsiblePerson.fullName.isNotEmpty) row.item.responsiblePerson.fullName,
      priorityLabels[row.item.priority] ?? '',
      if (row.inPlan) row.selected ? l10n.agendaAlreadyInPlan : l10n.agendaRemovedFromPlan,
    ].where((s) => s.isNotEmpty).toList();
    String? postponedLabel;
    if (row.postponedOn != null) {
      final d = DateTime.tryParse(row.postponedOn!)?.toLocal();
      postponedLabel = d != null
          ? l10n.agendaPostponedOn(DateFormat(dateFmt(DateFmtKind.dayMonth)).format(d))
          : l10n.agendaPostponed;
    }
    return ListTile(
      onTap: () => setState(() => row.selected = !row.selected),
      leading: Icon(
        row.selected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: row.selected ? AppColors.primary : AppColors.medium,
      ),
      title: Text(row.item.title),
      // Ionic: warning badge for postponed topics, then the grey subtitle.
      subtitle: Text.rich(
        TextSpan(children: [
          if (postponedLabel != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IonBadge(label: postponedLabel, color: AppColors.warning),
              ),
            ),
          TextSpan(text: parts.join(' · ')),
        ]),
        style: const TextStyle(color: AppColors.medium),
      ),
      trailing: row.selected && !row.inPlan
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ionic `.stepper`: clear "−" / "+" text buttons around the minutes.
                IconButton(
                  tooltip: l10n.agendaShorter,
                  color: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove),
                  onPressed: () => setState(() => row.duration = (row.duration - 5).clamp(5, 999)),
                ),
                Text(l10n.planningMinShort(row.duration)),
                IconButton(
                  tooltip: l10n.agendaLonger,
                  color: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => row.duration += 5),
                ),
              ],
            )
          : IonNote(l10n.planningMinShort(row.duration)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visiblePostponed = _postponedRows.where(_matches).toList();
    final visibleOthers = _otherRows.where(_matches).toList();
    final l10n = context.l10n;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          AppBar(
            toolbarHeight: ionModalToolbarHeight(context), // PARITY_R5
            automaticallyImplyLeading: false,
            primary: false,
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.commonClose,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(l10n.attendanceAddTopics),
            // Ionic: second toolbar with the searchbar.
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: IonSearchbar(
                controller: _searchController,
                placeholder: l10n.agendaSearchOrCreate,
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: AppSpinner())
                : ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      if (_canCreateFromSearch)
                        IonInsetList(children: [
                          ListTile(
                            leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                            title: Text(l10n.agendaCreateAsNew(_search.trim()),
                                style: const TextStyle(color: AppColors.primary)),
                            onTap: _createFromSearch,
                          ),
                        ]),
                      if (visiblePostponed.isNotEmpty)
                        IonInsetList(
                          header: l10n.agendaPostponedFromLast,
                          dividerIndent: 0,
                          children: visiblePostponed.map(_rowTile).toList(),
                        ),
                      IonInsetList(
                        header: l10n.agendaTopicStore,
                        dividerIndent: 0,
                        children: [
                          ...visibleOthers.map(_rowTile),
                          if (visibleOthers.isEmpty)
                            ListTile(
                              title: Text(
                                _search.trim().isNotEmpty
                                    ? l10n.agendaFlutterNoMatch
                                    : l10n.agendaFlutterNoOpenTopics,
                                style: const TextStyle(color: AppColors.medium),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
          // Ionic ion-footer: insert hint + block button.
          Material(
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_insertHint,
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.medium)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: !_hasChanges || _saving ? null : _confirm,
                        child: IonButtonLabel(_confirmLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
