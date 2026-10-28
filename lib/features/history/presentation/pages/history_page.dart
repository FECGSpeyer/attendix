import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/conductor_providers.dart';
import '../../../../core/providers/history_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/history/history_entry.dart';
import '../../../../data/models/song/song.dart';
import '../../history_utils.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../../../attendance/presentation/widgets/ios_condense_header.dart'; // UX_ATT

/// IOS_FORMS2: Ionic opens the Werkhistorie with
/// `modalController.create({ component: HistoryPage, presentingElement })`,
/// i.e. on iOS a card modal sheet over a dark backdrop (top inset 10pt,
/// rounded top corners, swipe down to close) and not a pushed page. On iOS
/// this presents [HistoryPage] like that on the root navigator; elsewhere
/// (Ionic md: full-screen modal) the `/history` route is pushed as before.
/// The `/history` route keeps working for deep links.
Future<void> showHistoryModal(BuildContext context) async {
  if (!isIosLook(context)) {
    await context.push('/history');
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: constraints.maxHeight - 10,
        child: const HistoryPage(asModal: true),
      ),
    ),
  );
}

/// History Page - Song performance history
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key, this.asModal = false});

  /// Shown via [showHistoryModal] (iOS card sheet): the close button pops
  /// the sheet instead of the route.
  final bool asModal;

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(performanceHistoryProvider);

    return Scaffold(
      // IOS_FORMS2: Ionic `ion-content` without colour → white page, so the
      // light-grey accordion headers stand out (iOS page grey otherwise).
      backgroundColor:
          isIosLook(context) ? Theme.of(context).colorScheme.surface : null,
      // UX_ATT: Ionic opens the Historie as a modal: title + close (X) at the
      // end, no back button.
      appBar: AppBar(
        title: Text(context.l10n.historyTitle),
        automaticallyImplyLeading: false,
        // IOS_FORMS2: iOS → ✕ in a Liquid Glass circle (ion-buttons end)
        actions: [
          ToolbarButtonGroup(children: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.l10n.commonClose,
              onPressed: () {
                if (widget.asModal) {
                  Navigator.of(context).pop();
                } else if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/settings');
                }
              },
            ),
          ]),
        ],
      ),
      body: Column(
        children: [
          // Search bar (Ionic ion-searchbar)
          IonSearchbar(
            controller: _searchController,
            hintText: context.l10n.historySearchSong,
            onChanged: (value) => setState(() => _searchQuery = value),
          ),

          // History list
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: AppSpinner()),
              error:
                  (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.danger,
                        ),
                        const SizedBox(height: 16),
                        Text(context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e))),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed:
                              () => ref.invalidate(performanceHistoryProvider),
                          child: Text(context.l10n.messagesRetry),
                        ),
                      ],
                    ),
                  ),
              data: (history) {
                final filtered = _filterHistory(history);
                final grouped = _groupByDate(filtered);

                if (history.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // UX_ATT: Ionic noDataContainer: plain large icon + label
                        Icon(
                          Icons.music_note_outlined,
                          size: 80,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.historyNoneYet,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 64,
                          color: AppColors.medium,
                        ),
                        const SizedBox(height: 16),
                        Text(context.l10n.historyNoneFound),
                      ],
                    ),
                  );
                }

                return RefreshIndicator.adaptive(
                  onRefresh: () async {
                    ref.invalidate(performanceHistoryProvider);
                    await ref.read(performanceHistoryProvider.future);
                  },
                  child:
                      _searchQuery.isNotEmpty
                          // UX_SETTINGS: Ionic shows a flat list while searching
                          ? ListView.separated(
                            padding: const EdgeInsets.only(bottom: 88),
                            itemCount: filtered.length,
                            separatorBuilder:
                                (_, __) => const Divider(height: 1),
                            itemBuilder:
                                (context, index) => _HistoryEntryTile(
                                  entry: filtered[index],
                                  onDelete: _deleteEntry,
                                  showCount: false,
                                ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 88),
                            itemCount: grouped.length,
                            itemBuilder: (context, index) {
                              final group = grouped[index];
                              return _HistoryGroup(
                                key: ValueKey(group.date),
                                date: group.date,
                                entries: group.entries,
                                // Ionic: collapsed accordion
                                onDelete: (entry) => _deleteEntry(entry),
                              );
                            },
                          ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: IonFabButton(
        onPressed: () => _showAddDialog(),
        icon: Icons.add,
      ),
    );
  }

  List<HistoryEntry> _filterHistory(List<HistoryEntry> history) {
    if (_searchQuery.isEmpty) return history;

    final query = _searchQuery.toLowerCase();
    return history.where((entry) {
      return (entry.songName?.toLowerCase().contains(query) ?? false) ||
          (entry.songNumber?.toLowerCase().contains(query) ?? false) ||
          entry.displayConductor.toLowerCase().contains(query);
    }).toList();
  }

  List<_GroupedHistory> _groupByDate(List<HistoryEntry> history) {
    final Map<String, List<HistoryEntry>> grouped = {};

    for (final entry in history) {
      final date = entry.formattedDate;
      grouped.putIfAbsent(date, () => []);
      grouped[date]!.add(entry);
    }

    return grouped.entries
        .map((e) => _GroupedHistory(date: e.key, entries: e.value))
        .toList();
  }

  // UX_ATT: Ionic addHisModal: sheet (breakpoint 0.7) with the title
  // "Werk(e) hinzufügen", a "Werk(e)" row that opens "Werke auswählen"
  // (search + checkboxes), the Dirigent select, the Datum field with a
  // calendar button and the block button "Hinzufügen".
  Future<void> _showAddDialog() async {
    final songsAsync = ref.read(planSongsProviderHistory);
    final conductorsAsync = ref.read(conductorsProvider);

    final songs = songsAsync.valueOrNull ?? [];
    final conductors = conductorsAsync.valueOrNull ?? [];

    if (songs.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.historyNoneFound);
      return;
    }

    final selectedSongIds = <int>{};
    int? selectedConductorId;
    String? otherConductor;
    DateTime selectedDate = DateTime.now();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final l10n = sheetContext.l10n;
          final divider = Divider(height: 0.5, thickness: 0.5, indent: 16, color: Theme.of(sheetContext).dividerColor);
          return SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.7,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.historyAddSongs,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                // Werk(e) → "Werke auswählen"
                ListTile(
                  title: Text(l10n.historySongs, style: const TextStyle(fontSize: 17)),
                  subtitle: Text(
                    selectedSongIds.isEmpty
                        ? l10n.historyNoneSelected
                        : l10n.historySelectedCount(selectedSongIds.length),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.medium),
                  onTap: () async {
                    final picked = await _pickSongs(songs, selectedSongIds);
                    if (picked != null) {
                      setSheetState(() {
                        selectedSongIds
                          ..clear()
                          ..addAll(picked);
                      });
                    }
                  },
                ),
                divider,
                // Dirigent (ion-select)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.attListConductor, style: const TextStyle(fontSize: 17))),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: otherConductor != null ? -1 : selectedConductorId,
                          alignment: AlignmentDirectional.centerEnd,
                          items: [
                            ...conductors.where((c) => c.left == null).map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text('${c.firstName} ${c.lastName}'),
                                  ),
                                ),
                            // UX_SETTINGS: Ionic "Anderer Dirigent"
                            DropdownMenuItem(value: -1, child: Text(l10n.attListOtherConductor)),
                          ],
                          onChanged: (v) async {
                            if (v == -1) {
                              final name = await _askOtherConductor(sheetContext);
                              if (name != null && name.isNotEmpty) {
                                setSheetState(() {
                                  selectedConductorId = null;
                                  otherConductor = name;
                                });
                              }
                            } else {
                              setSheetState(() {
                                selectedConductorId = v;
                                otherConductor = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (otherConductor != null) ...[
                  divider,
                  ListTile(title: Text(otherConductor!)),
                ],
                divider,
                // Datum (stacked label, value, calendar button)
                ListTile(
                  title: Text(
                    l10n.attendanceDate,
                    style: const TextStyle(fontSize: 12.75),
                  ),
                  subtitle: Text(
                    DateFormat(dateFmt()).format(selectedDate),
                    style: TextStyle(fontSize: 17, color: Theme.of(sheetContext).colorScheme.onSurface),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
                    onPressed: () async {
                      final date = await showAppDatePicker(
                        context: sheetContext,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) setSheetState(() => selectedDate = date);
                    },
                  ),
                ),
                divider,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      // Ionic: toast "Bitte wähle mindestens ein Werk an"
                      if (selectedSongIds.isEmpty) {
                        ToastHelper.showWarning(sheetContext, l10n.historySelectAtLeastOne);
                        return;
                      }
                      Navigator.pop(sheetContext, true);
                    },
                    child: Text(l10n.attendanceAdd),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (result == true && selectedSongIds.isNotEmpty) {
      await _addEntries(
        songIds: selectedSongIds,
        conductorId: selectedConductorId,
        otherConductor: otherConductor,
        date: selectedDate,
      );
    }
  }

  /// "Anderer Dirigent": asks for the name (Ionic onConChange alert).
  Future<String?> _askOtherConductor(BuildContext context) async {
    final controller = TextEditingController();
    try {
      return await showAppDialog<String>(
        context: context,
        builder: (context) => AppAlertDialog(
          title: Text(context.l10n.attListEnterConductor),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: context.l10n.attListConductor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(context.l10n.commonSave),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  /// Ionic songSelectModal: full-screen "Werke auswählen" with a checkmark
  /// button, a searchbar toolbar and an inset checkbox list.
  Future<Set<int>?> _pickSongs(List<Song> songs, Set<int> initial) {
    return Navigator.of(context).push<Set<int>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _HistorySongPicker(songs: songs, initial: initial),
      ),
    );
  }

  Future<void> _addEntries({
    required Set<int> songIds,
    int? conductorId,
    String? otherConductor,
    required DateTime date,
  }) async {
    if (DemoGuard.blocked()) return; // DEMO_GUARD
    try {
      final supabase = ref.read(supabaseClientProvider);
      final tenant = ref.read(currentTenantProvider);

      if (tenant?.id == null) {
        if (mounted) {
          ToastHelper.showError(context, context.l10n.historyFlutterNoTenant);
        }
        return;
      }

      final dateStr = date.toIso8601String().substring(0, 10);
      await supabase
          .from('history')
          .insert(
            songIds
                .map(
                  (songId) => {
                    'tenantId': tenant!.id!,
                    'songId': songId, // DB column (Ionic History.songId)
                    'person_id': conductorId,
                    'otherConductor': otherConductor,
                    'date': dateStr,
                    'visible': true,
                  },
                )
                .toList(),
          );

      ref.invalidate(performanceHistoryProvider);
      if (mounted) {
        final count = songIds.length;
        ToastHelper.showSuccess(
          context,
          context.l10n.historyFlutterSongsAdded(count),
        );
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
      }
    }
  }

  Future<void> _deleteEntry(HistoryEntry entry) async {
    if (entry.id == null) return;
    HapticHelper.medium(); // MEDIA_REALTIME: Ionic Haptics.impact Medium

    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.historyRemoveConfirm,
      message: '',
      confirmText: context.l10n.commonYes,
      cancelText: context.l10n.commonCancel,
    );

    if (!confirmed) return;
    if (DemoGuard.blocked()) return; // DEMO_GUARD

    try {
      final supabase = ref.read(supabaseClientProvider);
      final tenant = ref.read(currentTenantProvider);

      if (tenant?.id == null) {
        if (mounted) {
          ToastHelper.showError(context, context.l10n.historyFlutterNoTenant);
        }
        return;
      }

      await supabase
          .from('history')
          .delete()
          .eq('id', entry.id!)
          .eq('tenantId', tenant!.id!);

      ref.invalidate(performanceHistoryProvider);
      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.historyFlutterEntryDeleted);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
      }
    }
  }
}

/// Grouped history helper
class _GroupedHistory {
  final String date;
  final List<HistoryEntry> entries;

  _GroupedHistory({required this.date, required this.entries});
}

/// History group (Ionic `ion-accordion` with the date as header)
class _HistoryGroup extends StatefulWidget {
  final String date;
  final List<HistoryEntry> entries;
  final Function(HistoryEntry) onDelete;

  const _HistoryGroup({
    super.key,
    required this.date,
    required this.entries,
    required this.onDelete,
  });

  @override
  State<_HistoryGroup> createState() => _HistoryGroupState();
}

class _HistoryGroupState extends State<_HistoryGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // UX_ATT: accordion header is an `ion-item color="light"` (grey row)
    final dark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = dark ? const Color(0xFF222428) : AppColors.light;
    if (!isIosLook(context)) {
      return ExpansionTile(
        backgroundColor: Theme.of(context).colorScheme.surface,
        collapsedBackgroundColor: headerColor,
        shape: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
        collapsedShape: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
        title: Text(widget.date, style: const TextStyle(fontSize: 17)),
        children: [
          for (final entry in widget.entries)
            _HistoryEntryTile(entry: entry, onDelete: widget.onDelete),
        ],
      );
    }
    // IOS_FORMS2: Ionic iOS accordion – the header stays light grey when
    // open, the toggle chevron is drawn in the item's text colour (black)
    // and turns upside down when expanded.
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final hairline = BorderSide(color: Theme.of(context).dividerColor, width: 0.5);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: headerColor,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(border: Border(bottom: hairline)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.date,
                      style: TextStyle(fontSize: 17, color: onSurface),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down, size: 22, color: onSurface),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _expanded
              ? Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in widget.entries)
                        _HistoryEntryTile(entry: entry, onDelete: widget.onDelete),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Ionic history item: "Nr Name", "Datum | Dirigent", badge "N Proben";
/// swipe left reveals the red delete option.
class _HistoryEntryTile extends StatelessWidget {
  const _HistoryEntryTile({
    required this.entry,
    required this.onDelete,
    this.showCount = true,
  });

  final HistoryEntry entry;
  final Function(HistoryEntry) onDelete;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final name = entry.songName ?? context.l10n.historyFlutterUnknownSong;
    // UX_ATT: Ionic ion-item-sliding with a red trash option (tap to delete)
    return Slidable(
      key: ValueKey(entry.id ?? '${entry.songId}_${entry.date}'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(entry),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete,
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          showCount && entry.songNumber != null
              ? '${entry.songNumber} $name'
              : name,
          // Ionic iOS label: h2 17 px, h3 15 px in the text color
          style: const TextStyle(fontSize: 17),
        ),
        subtitle: Text(
          '${entry.formattedDate} | ${entry.displayConductor}',
          style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface),
        ),
        trailing:
            showCount && entry.count != 0
                ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    rehearsalsLabel(entry.count),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                )
                : null,
      ),
    );
  }
}

/// UX_ATT: Ionic "Werke auswählen" modal of the history sheet.
class _HistorySongPicker extends StatefulWidget {
  const _HistorySongPicker({required this.songs, required this.initial});

  final List<Song> songs;
  final Set<int> initial;

  @override
  State<_HistorySongPicker> createState() => _HistorySongPickerState();
}

class _HistorySongPickerState extends State<_HistorySongPicker> {
  late final Set<int> _selected = {...widget.initial};
  final _search = TextEditingController();
  String _term = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = _term.toLowerCase();
    final filtered = term.isEmpty
        ? widget.songs
        : widget.songs.where((s) => s.displayName.toLowerCase().contains(term)).toList();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? null : AppColors.light,
      appBar: AppBar(
        title: Text(context.l10n.historySelectSongs),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: context.l10n.commonApply,
            onPressed: () => Navigator.pop(context, _selected),
          ),
        ],
      ),
      body: Column(
        children: [
          IonSearchbar(
            controller: _search,
            hintText: context.l10n.historySearchSong,
            onChanged: (v) => setState(() => _term = v),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.l10n.historyNoneFound,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.medium),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Card(
                        margin: const EdgeInsets.all(16),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < filtered.length; i++) ...[
                              if (i > 0) const Divider(height: 0.5, thickness: 0.5, indent: 56),
                              CheckboxListTile(
                                value: filtered[i].id != null && _selected.contains(filtered[i].id),
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(filtered[i].displayName),
                                subtitle: (filtered[i].composer?.isNotEmpty ?? false)
                                    ? Text(filtered[i].composer!)
                                    : null,
                                onChanged: (v) {
                                  final id = filtered[i].id;
                                  if (id == null) return;
                                  setState(() => v == true ? _selected.add(id) : _selected.remove(id));
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
