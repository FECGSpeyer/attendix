import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/conductor_providers.dart';
import '../../../../core/providers/history_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/history/history_entry.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../history/history_utils.dart' show defaultHistoryConductorId;
import '../../data/rd_manage_logic.dart' show RdManageEntry;
import '../widgets/manage/rd_manage_entries.dart' show rdManageTitle;
import '../widgets/manage/rd_manage_list.dart';
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/rd_widgets.dart';

/// REDESIGN: Verwaltung › Werkhistorie in the template "Verwaltungsliste"
/// (canvas "Beta: Gruppe und Daten", board "G4 Werkhistorie"). Replaces the
/// old history modal while the Beta is on: search on top, the entries by
/// date as sections (work, conductor), a tap offers "Entfernen", "+" adds
/// works played on a date in one sheet (works, conductor, date). Same data
/// and writes as the old page.
class RdWorkHistoryPage extends ConsumerStatefulWidget {
  const RdWorkHistoryPage({super.key});

  @override
  ConsumerState<RdWorkHistoryPage> createState() => _RdWorkHistoryPageState();
}

class _RdWorkHistoryPageState extends ConsumerState<RdWorkHistoryPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _stillIn(int? tenantId) => mounted && tenantId != null && ref.read(currentTenantIdProvider) == tenantId;

  Future<void> _refresh() async {
    ref.invalidate(performanceHistoryProvider);
    await ref.read(performanceHistoryProvider.future).catchError((_) => const <HistoryEntry>[]);
  }

  List<HistoryEntry> _filter(List<HistoryEntry> history) {
    if (_query.isEmpty) return history;
    final q = _query.toLowerCase();
    return history
        .where(
          (e) =>
              (e.songName?.toLowerCase().contains(q) ?? false) ||
              (e.songNumber?.toLowerCase().contains(q) ?? false) ||
              e.displayConductor.toLowerCase().contains(q),
        )
        .toList();
  }

  String _songTitle(HistoryEntry e) =>
      [if ((e.songNumber ?? '').isNotEmpty) e.songNumber!, e.songName ?? ''].where((s) => s.isNotEmpty).join(' ');

  Future<void> _remove(HistoryEntry entry) async {
    if (entry.id == null) return;
    final l10n = context.l10n;
    final tenantId = ref.read(currentTenantIdProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final confirmed = await showAppConfirm(
      context,
      title: l10n.historyRemoveConfirm,
      message: _songTitle(entry),
      confirmText: l10n.commonDelete,
      destructive: true,
    );
    if (!confirmed || !_stillIn(tenantId) || DemoGuard.blocked()) return;
    try {
      await repo.deleteHistoryEntry(entry.id!);
      container.invalidate(performanceHistoryProvider);
      if (mounted) ToastHelper.showSuccess(context, l10n.historyFlutterEntryDeleted);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  Future<void> _add() async {
    final l10n = context.l10n;
    final tenantId = ref.read(currentTenantIdProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    // Old page: wait for works and conductors so the sheet starts filled.
    List<Song> songs;
    List<Person> conductors;
    try {
      songs = await container.read(planSongsProviderHistory.future);
    } catch (_) {
      songs = const [];
    }
    try {
      conductors = await container.read(conductorsProvider.future);
    } catch (_) {
      conductors = const [];
    }
    if (!_stillIn(tenantId)) return;
    if (songs.isEmpty) {
      ToastHelper.showWarning(context, l10n.historyNoneFound);
      return;
    }
    final result = await showRdSettingsSheet<_HistoryInput>(
      context,
      (_) => _AddHistorySheet(songs: songs, conductors: conductors.where((c) => c.left == null).toList()),
    );
    if (result == null || !_stillIn(tenantId) || DemoGuard.blocked()) return;
    try {
      final dateStr = result.date.toIso8601String().substring(0, 10);
      await repo.addHistoryEntries([
        for (final songId in result.songIds)
          {
            'songId': songId,
            'person_id': result.conductorId,
            'otherConductor': result.otherConductor,
            'date': dateStr,
            'visible': true,
          },
      ]);
      container.invalidate(performanceHistoryProvider);
      if (mounted) ToastHelper.showSuccess(context, l10n.historyFlutterSongsAdded(result.songIds.length));
    } catch (e) {
      if (mounted) ToastHelper.showError(context, l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    // Like the old entry: not in general groups (open by URL → Verwaltung).
    if (ref.watch(currentTenantProvider.select((t) => t?.type == 'general'))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(RedesignRoutes.manage);
      });
      return const SizedBox.shrink();
    }
    final async = ref.watch(performanceHistoryProvider);
    // Old page: works are loaded on open so "+" is quick.
    ref.watch(planSongsProviderHistory);
    final history = rdLoadedValue(async);
    final shown = history == null ? null : _filter(history);

    List<RdManageListSection>? sections;
    if (shown != null) {
      final byDate = <String, List<HistoryEntry>>{};
      for (final e in shown) {
        byDate.putIfAbsent(e.formattedDate, () => []).add(e);
      }
      sections = [
        for (final MapEntry(key: date, value: entries) in byDate.entries)
          RdManageListSection(
            key: date,
            title: date,
            items: [
              for (final (i, e) in entries.indexed)
                RdManageListItem(
                  id: e.id ?? '$date-$i',
                  title: _songTitle(e),
                  subtitle: e.displayConductor,
                  icon: Icons.music_note_outlined,
                  onTap: e.id == null ? null : () => _remove(e),
                ),
            ],
          ),
      ];
    }

    return RdManageListPage(
      title: rdManageTitle(l10n, RdManageEntry.workHistory),
      intro: l10n.rdWmHistoryIntro,
      header:
          history == null || history.isEmpty
              ? null
              : TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v.trim()),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.historySearchSong,
                  prefixIcon: Icon(Icons.search, color: p.text2),
                  suffixIcon:
                      _query.isEmpty
                          ? null
                          : IconButton(
                            icon: Icon(Icons.close, color: p.text2),
                            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  filled: true,
                  fillColor: p.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(p.buttonRadius),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(p.buttonRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
      sections: sections,
      loadFailed: async.hasError && !async.isLoading,
      onRetry: () => ref.invalidate(performanceHistoryProvider),
      emptyText: _query.isEmpty ? l10n.historyNoneYet : l10n.historyNoneFound,
      emptyIcon: _query.isEmpty ? Icons.music_note_outlined : Icons.search_off,
      addLabel: l10n.historyAddSongs,
      onAdd: _add,
      onRefresh: _refresh,
    );
  }
}

/// What the add sheet returns.
class _HistoryInput {
  const _HistoryInput({required this.songIds, this.conductorId, this.otherConductor, required this.date});

  final Set<int> songIds;
  final int? conductorId;
  final String? otherConductor;
  final DateTime date;
}

/// "Werke hinzufügen": works, conductor and date in one sheet (old page:
/// first work preselected, first active conductor as default, "Anderer
/// Dirigent" asks for a name, at least one work).
class _AddHistorySheet extends StatefulWidget {
  const _AddHistorySheet({required this.songs, required this.conductors});

  final List<Song> songs;
  final List<Person> conductors;

  @override
  State<_AddHistorySheet> createState() => _AddHistorySheetState();
}

class _AddHistorySheetState extends State<_AddHistorySheet> {
  static const _other = -1;

  late final Set<int> _songIds = {if (widget.songs.first.id != null) widget.songs.first.id!};
  late int? _conductorId = defaultHistoryConductorId(widget.conductors);
  String? _otherConductor;
  DateTime _date = DateTime.now();

  String _conductorLabel(AppLocalizations l10n) {
    if (_otherConductor != null) return _otherConductor!;
    final c = widget.conductors.where((c) => c.id == _conductorId).firstOrNull;
    return c == null ? l10n.historyNoneSelected : '${c.firstName} ${c.lastName}';
  }

  Future<void> _pickSongs() async {
    final picked = await showRdSettingsSheet<Set<int>>(
      context,
      (_) => _SongPickSheet(songs: widget.songs, initial: _songIds),
    );
    if (picked != null && mounted) {
      setState(
        () =>
            _songIds
              ..clear()
              ..addAll(picked),
      );
    }
  }

  Future<void> _pickConductor() async {
    final l10n = context.l10n;
    final picked = await showRdChoiceSheet<int>(
      context,
      title: l10n.attListConductor,
      selected: _otherConductor != null ? _other : (_conductorId ?? _other),
      options: [
        for (final c in widget.conductors)
          if (c.id != null) (c.id!, '${c.firstName} ${c.lastName}'),
        (_other, l10n.attListOtherConductor),
      ],
    );
    if (picked == null || !mounted) return;
    if (picked == _other) {
      final name = await showRdTextSheet(
        context,
        title: l10n.attListEnterConductor,
        initial: _otherConductor ?? '',
        hint: l10n.attListConductor,
        capitalization: TextCapitalization.words,
      );
      if (name == null || name.trim().isEmpty || !mounted) return;
      setState(() {
        _conductorId = null;
        _otherConductor = name.trim();
      });
    } else {
      setState(() {
        _conductorId = picked;
        _otherConductor = null;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  void _done() {
    if (_songIds.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.historySelectAtLeastOne);
      return;
    }
    Navigator.of(context).pop(
      _HistoryInput(songIds: {..._songIds}, conductorId: _conductorId, otherConductor: _otherConductor, date: _date),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        RdSheetHead(title: l10n.historyAddSongs),
        RdGroupedList(
          children: [
            RdListRow(
              title: l10n.historySongs,
              value: _songIds.isEmpty ? l10n.historyNoneSelected : l10n.historySelectedCount(_songIds.length),
              onTap: _pickSongs,
            ),
            RdListRow(title: l10n.attListConductor, value: _conductorLabel(l10n), onTap: _pickConductor),
            RdListRow(title: l10n.attendanceDate, value: DateFormat(dateFmt()).format(_date), onTap: _pickDate),
          ],
        ),
        const SizedBox(height: 16),
        RdPrimaryButton(label: l10n.attendanceAdd, onPressed: _done),
      ],
    );
  }
}

/// "Werke auswählen": search and ticks, "Fertig" returns the choice.
class _SongPickSheet extends StatefulWidget {
  const _SongPickSheet({required this.songs, required this.initial});

  final List<Song> songs;
  final Set<int> initial;

  @override
  State<_SongPickSheet> createState() => _SongPickSheetState();
}

class _SongPickSheetState extends State<_SongPickSheet> {
  late final Set<int> _selected = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final q = _query.toLowerCase();
    final shown =
        widget.songs
            .where(
              (s) =>
                  s.id != null &&
                  (q.isEmpty ||
                      s.name.toLowerCase().contains(q) ||
                      (s.number?.toString().toLowerCase().contains(q) ?? false)),
            )
            .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RdSheetHead(title: l10n.historySongs, onDone: () => Navigator.of(context).pop(_selected)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: l10n.historySearchSong,
              prefixIcon: Icon(Icons.search, color: p.text2),
              filled: true,
              fillColor: p.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(p.buttonRadius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              RdGroupedList(
                children: [
                  for (final s in shown)
                    RdListRow(
                      leading: Icon(
                        _selected.contains(s.id) ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: _selected.contains(s.id) ? p.primary : p.text2,
                      ),
                      title: [if (s.number != null) '${s.number}', s.name].join(' '),
                      showChevron: false,
                      onTap:
                          () => setState(() {
                            if (!_selected.remove(s.id)) _selected.add(s.id!);
                          }),
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
