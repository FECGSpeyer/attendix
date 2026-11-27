import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/providers/conductor_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../planning/presentation/widgets/plan_widgets.dart';
import '../../../songs/data/collections_logic.dart';
import 'event/form_widgets.dart';
import '../../../../shared/widgets/components/components.dart';
import '../../../today/presentation/widgets/today_common.dart';

part 'songs_selection_sheet.freezed.dart';
part 'songs_selection_sheet.g.dart';
part 'songs_selection_sheet_view.dart';

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

  factory SongHistoryEntry.fromJson(Map<String, dynamic> json) => _$SongHistoryEntryFromJson(json);
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      showDragHandle: true,
      backgroundColor: context.rd.bg,
      builder:
          (context) => SongsSelectionSheet(
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
  final _otherConductorController = TextEditingController();

  /// Conductor of single Werke that differs from "Dirigent für alle".
  final Map<int, _RdConductor> _rdOverrides = {};

  /// Werk whose conductor chips are open.
  int? _rdExpandedSongId;

  @override
  void dispose() {
    _otherConductorController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Pre-select first conductor if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final conductors = ref.read(activeConductorsProvider).valueOrNull;
      if (conductors != null && conductors.isNotEmpty) {
        setState(() {
          _selectedConductorId = conductors.first.id;
        });
      }
      // Straight into "Werke auswählen" (all Werke at once, the conductor is
      // set per Werk afterwards); cancelling closes the sheet.
      _rdOpenPickerFirst();
    });
  }

  void _update(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) => _rdBuild(context);

  /// Full-screen "Werke auswählen" with "Werk suchen..." (Ionic songSelectModal).
  /// Returns false when it was cancelled.
  Future<bool> _openSongPicker() async {
    final result = await Navigator.of(context, rootNavigator: true).push<Set<int>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _RdSongMultiPicker(initialSelection: _selectedSongIds),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedSongIds
          ..clear()
          ..addAll(result);
        _rdOverrides.removeWhere((id, _) => !_selectedSongIds.contains(id));
        if (!_selectedSongIds.contains(_rdExpandedSongId)) _rdExpandedSongId = null;
      });
    }
    return result != null;
  }

  bool _canAdd() {
    if (_selectedSongIds.isEmpty) return false;
    final conductors = ref.read(activeConductorsProvider).valueOrNull ?? const <Person>[];
    return _selectedSongIds.every((id) => _rdConductorFor(id, conductors) != null);
  }

  void _addSongs() {
    final songsAsync = ref.read(songsProvider);
    final conductorsAsync = ref.read(activeConductorsProvider);

    final songs = songsAsync.valueOrNull ?? [];
    final conductors = conductorsAsync.valueOrNull ?? [];

    // Create entries for each selected song
    final newEntries = <SongHistoryEntry>[];
    for (final songId in _selectedSongIds) {
      final song = songs.firstWhere((s) => s.id == songId, orElse: () => Song(name: context.l10n.commonUnknown));

      final choice = _rdConductorFor(songId, conductors);
      if (choice == null) continue;

      String? conductorName;
      if (choice.other == null && choice.id != null) {
        final conductor = conductors.firstWhere((c) => c.id == choice.id, orElse: () => const Person());
        conductorName = conductor.fullName;
      }

      newEntries.add(
        SongHistoryEntry(
          songId: songId,
          songName: song.displayName,
          conductorId: choice.other == null ? choice.id : null,
          conductorName: conductorName,
          otherConductor: choice.other,
        ),
      );
    }

    // Add to existing entries
    final allEntries = [...widget.existingEntries, ...newEntries];
    widget.onEntriesChanged(allEntries);

    Navigator.of(context).pop();
  }
}

/// Widget to display selected songs in a list
class SelectedSongsList extends StatelessWidget {
  final List<SongHistoryEntry> entries;
  final ValueChanged<List<SongHistoryEntry>>? onEntriesChanged;
  final bool readOnly;

  const SelectedSongsList({super.key, required this.entries, this.onEntriesChanged, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(padding: const EdgeInsets.all(16), child: Text(context.l10n.attListNoSongsSelected));
    }

    return Column(
      children:
          entries.asMap().entries.map((entry) {
            final index = entry.key;
            final songEntry = entry.value;

            return ListTile(
              title: Text(songEntry.songName),
              subtitle: Text(songEntry.displayConductor),
              trailing:
                  readOnly
                      ? null
                      : IconButton(
                        icon: Icon(AppIcons.close, semanticLabel: context.l10n.commonClose),
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
