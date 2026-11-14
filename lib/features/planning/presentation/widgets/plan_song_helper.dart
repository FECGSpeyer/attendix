import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/song_providers.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../data/models/song/song.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart' show IonCloseButton;
import '../../../../shared/widgets/dialogs/ion_modal.dart';
import 'ion_items.dart';
import 'rd_plan_widgets.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/data/rd_collections_logic.dart';

/// The Werke planned for [att] ([own]: the Termin of the open Ablauf).
typedef PlanEventWorks = ({PlanAttendance att, bool own, List<PlanEventWork> works});

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

  /// Beta: key of the Werk's own length in the Ablauf, kept with its
  /// Zusatzfelder (`songs.additional_fields`; no tenant field has this id).
  static const minutesKey = 'planMinutes';

  /// Beta: minutes a Werk enters the Ablauf with unless it has its own.
  static const betaMinutes = 5;

  /// The Werk's own length in the Ablauf (null: none stored).
  static int? ownMinutes(Song song) {
    final value = song.additionalFields?[minutesKey];
    final minutes = value is num ? value.round() : int.tryParse('${value ?? ''}');
    return minutes == null || minutes <= 0 ? null : minutes;
  }

  /// Beta: `time` of a Werk that enters the Ablauf.
  static String betaTime(Song song) => '${ownMinutes(song) ?? betaMinutes}';

  /// "Aktuelle Werke hinzufügen": all Werke of the current history that are
  /// not yet part of the plan. [time]: the length of each (20 minutes
  /// without it, like Ionic).
  static List<PlanField> currentSongFields(
    List<PlanField> fields, {
    required List<SongHistory> history,
    required List<Song> songs,
    required String Function(Song song) prefix,
    String Function(Song song)? time,
    bool includeExisting = false,
  }) {
    // Ionic 4.17.25: [includeExisting] adds the current Werke again even when
    // they are already in the open plan ("Erneut hinzufügen").
    final existing = includeExisting
        ? <int>{}
        : fields.map((f) => int.tryParse(f.id)).whereType<int>().toSet();
    final result = <PlanField>[];
    for (final h in history) {
      final id = h.songId;
      if (id == null || existing.contains(id)) continue;
      final song = songs.where((s) => s.id == id).firstOrNull;
      if (song == null) continue;
      existing.add(id);
      result.add(songField(song, history: history, prefix: prefix, time: time?.call(song) ?? '20'));
    }
    return result;
  }

  /// Whether [att] is an Auftritt: its Terminart is highlighted (Vortrag,
  /// Konzert), or it is an old "vortrag" Termin without a Terminart.
  static bool isAuftritt(PlanAttendance att, List<PlanAttendanceType> types) =>
      att.type == 'vortrag' || (types.where((t) => t.id == att.typeId).firstOrNull?.highlight ?? false);

  /// "Werke vom … übernehmen" (Beta): the Termine whose planned Werke are
  /// offered for the Ablauf of [att], at most [limit].
  ///
  /// First [att] itself, then the Termine after it (same day: not before
  /// its start), nearest first. A later Termin counts when its Terminart is
  /// highlighted (Vortrag, Konzert) or differs from the one of [att]: a
  /// Probe takes the Werke of the next Auftritt, not those of the next Probe.
  /// [history] holds the Werke of the coming Termine (`currentSongsProvider`).
  /// [distinct]: a Werk of several Termine is listed once, at the nearest
  /// one; without it every Termin keeps its whole list.
  static List<PlanEventWorks> eventWorks(
    PlanAttendance att, {
    required List<PlanAttendance> attendances,
    required List<PlanAttendanceType> types,
    required List<SongHistory> history,
    required List<Song> songs,
    int limit = 3,
    bool distinct = true,
    bool auftritteOnly = false,
  }) {
    DateTime? dayOf(PlanAttendance a) {
      final d = DateTime.tryParse(a.date);
      return d == null ? null : DateTime(d.year, d.month, d.day);
    }

    final day = dayOf(att);
    if (att.id == null || day == null) return const [];
    final start = PlanUtils.parseTimeToMinutes(PlanUtils.formatTime(att.startTime));
    int? startOf(PlanAttendance a) => PlanUtils.parseTimeToMinutes(PlanUtils.formatTime(a.startTime));
    bool highlighted(PlanAttendance a) => isAuftritt(a, types);

    final found = <({PlanAttendance att, DateTime day, List<PlanEventWork> works})>[];
    for (final a in attendances) {
      final d = dayOf(a);
      if (a.id == null || d == null) continue;
      final own = a.id == att.id;
      if (!own) {
        if (d.isBefore(day)) continue;
        final s = startOf(a);
        if (d == day && start != null && s != null && s < start) continue;
        if (!highlighted(a) && (auftritteOnly || a.typeId == att.typeId)) continue;
      }
      // In the order they were planned (the Programm has no other order).
      final entries = history.where((h) => h.attendanceId == a.id && h.songId != null).toList()
        ..sort((x, y) => (x.id ?? 0).compareTo(y.id ?? 0));
      final seen = <int>{};
      final works = <PlanEventWork>[];
      for (final h in entries) {
        final song = songs.where((s) => s.id == h.songId).firstOrNull;
        if (song == null || !seen.add(h.songId!)) continue;
        works.add((song: song, conductor: h.conductorName ?? ''));
      }
      if (works.isNotEmpty) found.add((att: a, day: d, works: works));
    }
    found.sort((x, y) {
      final own = (y.att.id == att.id ? 1 : 0) - (x.att.id == att.id ? 1 : 0);
      if (own != 0) return own;
      final byDay = x.day.compareTo(y.day);
      if (byDay != 0) return byDay;
      final byStart = (startOf(x.att) ?? 0).compareTo(startOf(y.att) ?? 0);
      return byStart != 0 ? byStart : x.att.id!.compareTo(y.att.id!);
    });
    // A Werk of several Termine is listed once, at the nearest one.
    final listed = <int>{};
    final result = <PlanEventWorks>[];
    for (final f in found) {
      final works = [
        for (final w in f.works)
          if (!distinct || listed.add(w.song.id!)) w,
      ];
      if (works.isNotEmpty) result.add((att: f.att, own: f.att.id == att.id, works: works));
      if (result.length == limit) break;
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
/// In the Beta skin a sheet with search; [currentIds] (Werke of the current
/// history) are listed first and [inPlanIds] are marked "im Ablauf".
/// Werke of a Sammlung that is not "planbar" (Beta Sammlungen) stay out;
/// the Sammlungen are loaded first, and when that fails only the Repertoire
/// is offered.
Future<Song?> showPlanSongPicker(
  BuildContext context,
  List<Song> songs, {
  Set<int> currentIds = const {},
  Set<int> inPlanIds = const {},
}) async => (await showPlanWorksPicker(context, songs, currentIds: currentIds, inPlanIds: inPlanIds))?.song;

/// [showPlanSongPicker] that can also return "Alle aktuellen Werke"
/// ([offerAllCurrent], Beta skin only).
Future<PlanWorksPick?> showPlanWorksPicker(
  BuildContext context,
  List<Song> songs, {
  Set<int> currentIds = const {},
  Set<int> inPlanIds = const {},
  bool offerAllCurrent = false,
}) async {
  List<SongCollection>? collections;
  var known = true;
  try {
    collections = await ProviderScope.containerOf(context, listen: false).read(songCollectionsProvider.future);
  } catch (_) {
    known = false;
  }
  if (!context.mounted) return null;
  final plannable = known ? rdPlannableWorks(songs, collections) : rdWorksIn(songs, null);
  if (context.rdSkin != null) {
    return showRdPlanSongPicker(
      context,
      plannable,
      currentIds: currentIds,
      inPlanIds: inPlanIds,
      collections: collections,
      offerAllCurrent: offerAllCurrent,
    );
  }
  // ABL-15: Ionic `ion-modal` (full screen on phones, centred card from
  // 768px) instead of a full-screen page.
  final song = await showIonModal<Song>(
    context,
    builder: (_) => _SongPicker(songs: plannable),
  );
  return song == null ? null : (song: song, allCurrent: false);
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
        actions: const [IonCloseButton()],
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
