import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/conductor_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

part 'songs_selection_sheet.freezed.dart';
part 'songs_selection_sheet.g.dart';

/// Entry representing a song-conductor pair to be saved with attendance
@freezed
class SongHistoryEntry with _$SongHistoryEntry {
  const factory SongHistoryEntry({
    required int songId,
    required String songName,
    int? conductorId,
    String? conductorName,
    String? otherConductor,
  }) = _SongHistoryEntry;

  factory SongHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$SongHistoryEntryFromJson(json);
}

/// Extension for SongHistoryEntry
extension SongHistoryEntryExtension on SongHistoryEntry {
  /// Get display name for conductor
  String get displayConductor {
    if (otherConductor != null && otherConductor!.isNotEmpty) {
      return otherConductor!;
    }
    return conductorName ?? l10nWithoutContext.commonUnknown;
  }
}

/// Bottom sheet for selecting songs to add to attendance
class SongsSelectionSheet extends ConsumerStatefulWidget {
  final List<SongHistoryEntry> existingEntries;
  final ValueChanged<List<SongHistoryEntry>> onEntriesChanged;

  const SongsSelectionSheet({
    super.key,
    required this.existingEntries,
    required this.onEntriesChanged,
  });

  /// Show the bottom sheet and return updated entries
  static Future<List<SongHistoryEntry>?> show(
    BuildContext context, {
    required List<SongHistoryEntry> existingEntries,
  }) async {
    List<SongHistoryEntry>? result;

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SongsSelectionSheet(
        existingEntries: existingEntries,
        onEntriesChanged: (entries) {
          result = entries;
        },
      ),
    );

    return result;
  }

  @override
  ConsumerState<SongsSelectionSheet> createState() => _SongsSelectionSheetState();
}

class _SongsSelectionSheetState extends ConsumerState<SongsSelectionSheet> {
  final Set<int> _selectedSongIds = {};
  int? _selectedConductorId;
  String? _otherConductorName;
  bool _useOtherConductor = false;

  @override
  void initState() {
    super.initState();
    // Pre-select first conductor if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final conductors = ref.read(activeConductorsProvider).valueOrNull;
      if (conductors != null && conductors.isNotEmpty) {
        setState(() {
          _selectedConductorId = conductors.first.id;
        });
      }
    });
  }

  // UX_ATT: Ionic addHisModal: inset group with the "Werk(e)" picker row
  // (opens "Werke auswählen" with search) and the "Dirigent" select
  // (+ "Anderer Dirigent" input), then the primary "Werk(e) hinzufügen" row.
  @override
  Widget build(BuildContext context) {
    final conductorsAsync = ref.watch(activeConductorsProvider);
    final conductors = conductorsAsync.valueOrNull ?? const <Person>[];
    const otherValue = -1;
    final conductorValue = _useOtherConductor ? otherValue : _selectedConductorId;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      color: Theme.of(context).brightness == Brightness.dark ? null : AppColors.light,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.attListAddSongs,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.l10n.commonClose,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(context.l10n.attListSongsLabel),
                          subtitle: Text(_selectedSongIds.isEmpty
                              ? context.l10n.attListNoSongsSelected
                              : context.l10n.attListSongsSelected(_selectedSongIds.length)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _openSongPicker,
                        ),
                        const Divider(height: 1, indent: 16),
                        ListTile(
                          title: Text(context.l10n.attListConductor),
                          trailing: DropdownButtonHideUnderline(
                            child: AppDropdownButton<int>(
                              iosInterface: AppSelectInterface.alert, // IOS_THEME2
                              value: conductorValue,
                              hint: Text(context.l10n.attendanceChoose),
                              alignment: AlignmentDirectional.centerEnd,
                              items: [
                                for (final c in conductors)
                                  if (c.id != null)
                                    DropdownMenuItem(value: c.id, child: Text(c.fullName)),
                                DropdownMenuItem(
                                  value: otherValue,
                                  child: Text(context.l10n.attListOtherConductor),
                                ),
                              ],
                              onChanged: (v) => setState(() {
                                if (v == otherValue) {
                                  _useOtherConductor = true;
                                  _selectedConductorId = null;
                                } else {
                                  _useOtherConductor = false;
                                  _selectedConductorId = v;
                                  _otherConductorName = null;
                                }
                              }),
                            ),
                          ),
                        ),
                        if (_useOtherConductor) ...[
                          const Divider(height: 1, indent: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: TextField(
                              autofocus: true,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText: context.l10n.attListEnterConductor,
                                border: InputBorder.none,
                              ),
                              onChanged: (value) => setState(() => _otherConductorName = value),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      enabled: _canAdd(),
                      title: Text(
                        context.l10n.attListAddSongs,
                        style: TextStyle(
                          color: _canAdd() ? AppColors.primary : AppColors.medium,
                        ),
                      ),
                      onTap: _canAdd() ? _addSongs : null,
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

  /// Full-screen "Werke auswählen" with "Werk suchen..." (Ionic songSelectModal).
  Future<void> _openSongPicker() async {
    final result = await Navigator.of(context, rootNavigator: true).push<Set<int>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _SongPickerPage(initialSelection: _selectedSongIds),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedSongIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  bool _canAdd() {
    if (_selectedSongIds.isEmpty) return false;
    if (_useOtherConductor) {
      return _otherConductorName != null && _otherConductorName!.isNotEmpty;
    }
    return _selectedConductorId != null;
  }

  void _addSongs() {
    final songsAsync = ref.read(songsProvider);
    final conductorsAsync = ref.read(activeConductorsProvider);

    final songs = songsAsync.valueOrNull ?? [];
    final conductors = conductorsAsync.valueOrNull ?? [];

    // Create entries for each selected song
    final newEntries = <SongHistoryEntry>[];
    for (final songId in _selectedSongIds) {
      final song = songs.firstWhere(
        (s) => s.id == songId,
        orElse: () => Song(name: context.l10n.commonUnknown),
      );

      String? conductorName;
      if (!_useOtherConductor && _selectedConductorId != null) {
        final conductor = conductors.firstWhere(
          (c) => c.id == _selectedConductorId,
          orElse: () => const Person(),
        );
        conductorName = conductor.fullName;
      }

      newEntries.add(SongHistoryEntry(
        songId: songId,
        songName: song.displayName,
        conductorId: _useOtherConductor ? null : _selectedConductorId,
        conductorName: conductorName,
        otherConductor: _useOtherConductor ? _otherConductorName : null,
      ));
    }

    // Add to existing entries
    final allEntries = [...widget.existingEntries, ...newEntries];
    widget.onEntriesChanged(allEntries);

    Navigator.of(context).pop();
  }
}

/// UX_ATT: Ionic "Werke auswählen" modal with search and checkbox list.
class _SongPickerPage extends ConsumerStatefulWidget {
  const _SongPickerPage({required this.initialSelection});

  final Set<int> initialSelection;

  @override
  ConsumerState<_SongPickerPage> createState() => _SongPickerPageState();
}

class _SongPickerPageState extends ConsumerState<_SongPickerPage> {
  late final Set<int> _selected = {...widget.initialSelection};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.attListChooseSongs),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: context.l10n.commonApply,
            onPressed: () => Navigator.of(context).pop(_selected),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SearchBar(
              hintText: context.l10n.attListSearchSong,
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      body: songsAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (e, _) => Center(child: Text(context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)))),
        data: (songs) {
          final filtered = _search.isEmpty
              ? songs
              : songs
                  .where((s) => '${s.prefix ?? ''}${s.number ?? ''} ${s.name}'
                      .toLowerCase()
                      .contains(_search))
                  .toList();
          if (filtered.isEmpty) {
            return Center(
              child: Text(context.l10n.attListNoSongsFound, style: const TextStyle(color: AppColors.medium)),
            );
          }
          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final song = filtered[index];
              final id = song.id;
              return CheckboxListTile(
                value: id != null && _selected.contains(id),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('${song.prefix ?? ''}${song.number ?? ''} ${song.name}'.trim()),
                subtitle: (song.composer?.isNotEmpty ?? false) ? Text(song.composer!) : null,
                onChanged: id == null
                    ? null
                    : (v) => setState(() {
                          if (v == true) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        }),
              );
            },
          );
        },
      ),
    );
  }
}

/// Widget to display selected songs in a list
class SelectedSongsList extends StatelessWidget {
  final List<SongHistoryEntry> entries;
  final ValueChanged<List<SongHistoryEntry>>? onEntriesChanged;
  final bool readOnly;

  const SelectedSongsList({
    super.key,
    required this.entries,
    this.onEntriesChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.l10n.attListNoSongsSelected,
        ),
      );
    }

    return Column(
      children: entries.asMap().entries.map((entry) {
        final index = entry.key;
        final songEntry = entry.value;

        return ListTile(
          title: Text(songEntry.songName),
          subtitle: Text(songEntry.displayConductor),
          trailing: readOnly
              ? null
              : IconButton(
                  icon: Icon(Icons.close, semanticLabel: context.l10n.commonClose),
                  onPressed: () {
                    final newEntries = List<SongHistoryEntry>.from(entries);
                    newEntries.removeAt(index);
                    onEntriesChanged?.call(newEntries);
                  },
                ),
          dense: true,
        );
      }).toList(),
    );
  }
}
