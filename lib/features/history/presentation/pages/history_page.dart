import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
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

/// History Page - Song performance history
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

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
      appBar: AppBar(title: Text(context.l10n.historyTitle)),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.l10n.historySearchSong,
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                        : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
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
                        // UX_SETTINGS: Ionic empty state
                        const Icon(
                          Icons.music_note_outlined,
                          size: 48,
                          color: AppColors.medium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.historyNoneYet,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.medium),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
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
    String songFilter = '';

    final result = await showAppDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              final filteredSongs =
                  songFilter.isEmpty
                      ? songs
                      : songs
                          .where(
                            (s) => s.displayName.toLowerCase().contains(
                              songFilter.toLowerCase(),
                            ),
                          )
                          .toList();

              return AppAlertDialog(
                title: Text(
                  selectedSongIds.isEmpty
                      ? context.l10n.historyAddSongs
                      : context.l10n.historySelectedCount(selectedSongIds.length),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Song search
                        TextField(
                          decoration: InputDecoration(
                            hintText: context.l10n.historySearchSong,
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                          ),
                          onChanged:
                              (v) => setDialogState(() => songFilter = v),
                        ),
                        const SizedBox(height: 8),

                        // Song multi-select list
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredSongs.length,
                            itemBuilder: (context, index) {
                              final song = filteredSongs[index];
                              final isSelected = selectedSongIds.contains(
                                song.id,
                              );
                              return CheckboxListTile(
                                value: isSelected,
                                title: Text(
                                  song.displayName,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (v) {
                                  setDialogState(() {
                                    if (v == true && song.id != null) {
                                      selectedSongIds.add(song.id!);
                                    } else if (song.id != null) {
                                      selectedSongIds.remove(song.id!);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Conductor selector
                        DropdownButtonFormField<int>(
                          value: selectedConductorId,
                          decoration: InputDecoration(
                            labelText: context.l10n.attListConductor,
                          ),
                          // UX_SETTINGS: Ionic "Anderer Dirigent"
                          items: [
                            ...conductors
                                .where((c) => c.left == null)
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text('${c.firstName} ${c.lastName}'),
                                  ),
                                ),
                            DropdownMenuItem(
                              value: -1,
                              child: Text(context.l10n.attListOtherConductor),
                            ),
                          ],
                          onChanged: (v) async {
                            if (v == -1) {
                              final controller = TextEditingController();
                              try {
                                final result = await showAppDialog<String>(
                                  context: context,
                                  builder:
                                      (context) => AppAlertDialog(
                                        title: Text(context.l10n.attListEnterConductor),
                                        content: TextField(
                                          controller: controller,
                                          decoration: InputDecoration(
                                            labelText: context.l10n.attListConductor,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(context),
                                            child: Text(context.l10n.commonCancel),
                                          ),
                                          ElevatedButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  controller.text,
                                                ),
                                            child: Text(context.l10n.commonSave),
                                          ),
                                        ],
                                      ),
                                );
                                if (result != null && result.isNotEmpty) {
                                  setDialogState(() {
                                    selectedConductorId = null;
                                    otherConductor = result;
                                  });
                                }
                              } finally {
                                controller.dispose();
                              }
                            } else {
                              setDialogState(() {
                                selectedConductorId = v;
                                otherConductor = null;
                              });
                            }
                          },
                        ),
                        if (otherConductor != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('${context.l10n.attListConductor}: $otherConductor'),
                          ),
                        const SizedBox(height: 16),

                        // Date selector
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.l10n.attendanceDate),
                          subtitle: Text(
                            DateFormat(dateFmt()).format(selectedDate),
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showAppDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setDialogState(() => selectedDate = date);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.l10n.commonCancel),
                  ),
                  ElevatedButton(
                    onPressed:
                        selectedSongIds.isEmpty
                            ? null
                            : () => Navigator.pop(context, true),
                    child: Text(context.l10n.attendanceAdd),
                  ),
                ],
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
class _HistoryGroup extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ExpansionTile(
      backgroundColor: Theme.of(context).colorScheme.surface,
      collapsedBackgroundColor:
          Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(date),
      children: [
        for (final entry in entries)
          _HistoryEntryTile(entry: entry, onDelete: onDelete),
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
    return Dismissible(
      key: ValueKey(entry.id ?? '${entry.songId}_${entry.date}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.danger,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete(entry);
        return false; // Deletion handled after confirmation
      },
      child: ListTile(
        title: Text(
          showCount && entry.songNumber != null
              ? '${entry.songNumber} $name'
              : name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text('${entry.formattedDate} | ${entry.displayConductor}'),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                )
                : null,
      ),
    );
  }
}
