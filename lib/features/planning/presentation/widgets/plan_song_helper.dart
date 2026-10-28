import 'package:flutter/material.dart';

import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../data/models/song/song.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import 'ion_items.dart';

/// Song related helpers of the Ablaufplan editor (Ionic `PlanningPage`
/// `onSongsChange`, `addCurrentSongs`, `resolvePlaceholderFields`).
class PlanSongHelper {
  PlanSongHelper._();

  /// Field for one Werk. [prefix] mirrors Ionic: `${tenant.longName}: ` with
  /// `planning_prefix_instance_name`, otherwise `${song.number}. `.
  static PlanField songField(
    Song song, {
    required List<SongHistory> history,
    required String Function(Song song) prefix,
    String time = '20',
  }) {
    final conductor = history.where((h) => h.songId == song.id).firstOrNull?.conductorName;
    return PlanField(
      id: '${song.id}',
      name: '${prefix(song)}${song.name}',
      time: time,
      conductor: conductor ?? '',
      songId: song.id,
    );
  }

  /// "Aktuelle Werke hinzufügen": all Werke of the current history that are
  /// not yet part of the plan.
  static List<PlanField> currentSongFields(
    List<PlanField> fields, {
    required List<SongHistory> history,
    required List<Song> songs,
    required String Function(Song song) prefix,
  }) {
    final existing = fields.map((f) => int.tryParse(f.id)).whereType<int>().toSet();
    final result = <PlanField>[];
    for (final h in history) {
      final id = h.songId;
      if (id == null || existing.contains(id)) continue;
      final song = songs.where((s) => s.id == id).firstOrNull;
      if (song == null) continue;
      existing.add(id);
      result.add(songField(song, history: history, prefix: prefix));
    }
    return result;
  }

  /// Replaces `song-placeholder-*` fields of a default plan / template with the
  /// next Werk of the current history; the agenda placeholder takes 0 min.
  static List<PlanField> resolvePlaceholders(
    List<PlanField> fields, {
    required List<SongHistory> history,
    required List<Song> songs,
    required String Function(Song song) prefix,
  }) {
    final added = <int>{};
    final result = <PlanField>[];
    for (final field in fields) {
      if (field.id.startsWith('song-placeholder-')) {
        final h = history.where((h) => h.songId != null && !added.contains(h.songId)).firstOrNull;
        if (h != null) {
          added.add(h.songId!);
          final song = songs.where((s) => s.id == h.songId).firstOrNull;
          if (song != null) {
            final resolved = songField(song, history: history, prefix: prefix, time: field.time);
            result.add(field.copyWith(
              id: resolved.id,
              name: resolved.name,
              conductor: resolved.conductor,
              songId: resolved.songId,
            ));
          }
        }
        continue;
      }
      result.add(PlanUtils.isAgendaPlaceholder(field) ? field.copyWith(time: '0') : field);
    }
    return result;
  }
}

/// Searchable song picker (Ionic `songSelectModal`: "Werk auswählen" with a
/// searchbar toolbar and an inset list).
Future<Song?> showPlanSongPicker(BuildContext context, List<Song> songs) {
  return Navigator.of(context, rootNavigator: true).push<Song>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _SongPicker(songs: songs),
  ));
}

class _SongPicker extends StatefulWidget {
  const _SongPicker({required this.songs});
  final List<Song> songs;

  @override
  State<_SongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends State<_SongPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = widget.songs.where((s) {
      if (q.isEmpty) return true;
      final label = '${s.prefix ?? ''}${s.number ?? ''} ${s.name} ${s.composer ?? ''}'.toLowerCase();
      return label.contains(q);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.l10n.planningChooseSong),
        actions: [
          IconButton(
            tooltip: context.l10n.commonClose,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: IonSearchbar(
            placeholder: context.l10n.attListSearchSong,
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          if (filtered.isEmpty && q.isNotEmpty)
            IonInsetList(children: [
              ListTile(
                title: Text(context.l10n.attListNoSongsFound,
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.medium, fontSize: 14)),
              ),
            ]),
          if (filtered.isNotEmpty)
            IonInsetList(children: [
              for (final s in filtered)
                ListTile(
                  title: Text('${s.prefix ?? ''}${s.number ?? ''} ${s.name}'),
                  subtitle: (s.composer ?? '').isNotEmpty
                      ? Text(s.composer!, style: const TextStyle(color: AppColors.medium))
                      : null,
                  onTap: () => Navigator.pop(context, s),
                ),
            ]),
        ],
      ),
    );
  }
}
