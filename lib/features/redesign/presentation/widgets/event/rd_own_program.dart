import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/providers/debug_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/router/redesign_routes.dart';
import '../../../../../core/router/route_access.dart' show canOpenSongsTab;
import '../../../../../core/services/audio_player/audio_player_service.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../core/utils/event_list_utils.dart';
import '../../../../../core/utils/toast_helper.dart';
import '../../../../../data/models/song/song.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../songs/data/song_print_service.dart';
import '../../../../songs/presentation/widgets/song_file_opener.dart';
import '../../../data/providers/rd_event_details_providers.dart';
import '../../../data/rd_event_details_logic.dart';
import '../../../data/rd_works_logic.dart' show rdFileKind;
import '../rd_widgets.dart';
import '../today/rd_today_common.dart';
import 'rd_event_sections.dart' show RdProgramNumber;

/// REDESIGN: the Programm (Werke) of an own Termin for Spieler and, read
/// only, for parents (concept "Vortrag im Beta-Design", boards 5–7).
///
/// * Always called "Werke". A Probe without Werke of its own shows those
///   of the next Auftritt ("Vom nächsten Auftritt: …").
/// * Per Werk: number, title, conductor; "Du dirigierst" or "Keine Noten"
///   when the Spieler's group has no score (choir: "Chor (alle)" counts).
/// * Tap: "Deine Noten öffnen", "Aufnahme anhören", "Zum Werk" (only in
///   the current group and when the Werke tab is open to the role).
/// * "Meine Noten als ein PDF" for coming Termine with scores.
/// * Empty: a coming Vortrag says the Programm is not set yet; otherwise
///   nothing. Groups of type "general" never show it.
class RdOwnProgramSection extends ConsumerWidget {
  const RdOwnProgramSection({
    super.key,
    required this.tenantId,
    required this.attendanceId,
    required this.personId,
    required this.highlight,
    required this.past,
    this.readOnly = false,
  });

  final int tenantId;
  final int attendanceId;

  /// The Spieler (or child) in that group; null = no group, no scores.
  final int? personId;
  final bool highlight;
  final bool past;

  /// Parents: the list only.
  final bool readOnly;

  RdOwnProgramKey get _key => (tenantId: tenantId, attendanceId: attendanceId, personId: personId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(rdOwnProgramProvider(_key));
    final title = l10n.redesignEventWorks;
    final program = async.valueOrNull;

    if (program == null) {
      if (!async.hasError) return const SizedBox.shrink();
      return _frame(
        title,
        RdInfoCard(
          text: l10n.redesignEventWorksLoadFailed,
          icon: Icons.error_outline,
          action: RdOutlineButton(
            label: l10n.redesignCommonRetry,
            onPressed: () => ref.invalidate(rdOwnProgramProvider(_key)),
          ),
        ),
      );
    }
    if (!program.usesWorks) return const SizedBox.shrink();
    // A Probe without Werke of its own: those of the next Auftritt.
    final follows = program.items.isEmpty && !highlight && !past;
    final followed = follows ? ref.watch(rdOwnFollowedProgramProvider(_key)).valueOrNull : null;
    final items = followed?.items ?? program.items;
    if (items.isEmpty) {
      if (!highlight || past) return const SizedBox.shrink();
      return _frame(
        title,
        RdCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const RdRowIcon(Icons.music_note_outlined),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.redesignOwnProgramPending, style: RdType.meta(p, size: 15))),
            ],
          ),
        ),
      );
    }

    final notes = [
      for (final item in items) rdMyNotes(item.song, program.instrumentId, isChoir: program.isChoir),
    ];
    final withNotes = [for (var i = 0; i < items.length; i++) if (notes[i].isNotEmpty && items[i].song != null) i];
    final rows = <Widget>[
      if (followed != null)
        Container(
          key: const Key('rd-own-program-source'),
          width: double.infinity,
          color: p.soft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.event_outlined, size: 18, color: p.softText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.redesignEventWorksFrom(_sourceLabel(followed)),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.softText),
                ),
              ),
            ],
          ),
        ),
      for (var i = 0; i < items.length; i++) _row(context, ref, program, items[i], i, notes[i], numbered: followed == null),
    ];
    return _frame(
      l10n.redesignEventSectionCount(title, '${items.length}'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RdGroupedList(children: rows),
          if (!readOnly && !past && withNotes.length > 1) ...[
            const SizedBox(height: 10),
            RdGroupedList(children: [
              RdListRow(
                leading: const RdRowIcon(Icons.print_outlined),
                title: l10n.redesignOwnPrintMine,
                subtitle: l10n.redesignOwnPrintMineHint('${withNotes.length}', '${items.length}'),
                onTap: () => _printMine(context, ref, [
                  for (final i in withNotes) SongPrintEntry(song: items[i].song!, file: notes[i].first),
                ], title),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  /// "Adventskonzert · So., 13. Dez."
  String _sourceLabel(RdFollowedProgram source) {
    final date = EventListUtils.parse(source.date);
    String? day;
    try {
      day = date == null ? null : DateFormat('EEE, d. MMM', currentIntlLocale()).format(date);
    } catch (_) {
      // Locale data not loaded: the name alone.
    }
    return [if (source.name.isNotEmpty) source.name, if (day != null) day].join(' · ');
  }

  Widget _frame(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          RdGroupLabel(label),
          child,
        ],
      );

  Widget _row(BuildContext context, WidgetRef ref, RdOwnProgram program, RdProgramItem item, int index,
      List<SongFile> notes, {bool numbered = true}) {
    final l10n = context.l10n;
    final song = item.song;
    final mine = personId != null && item.conductorPersonId == personId;
    // Parents may have children in several groups: no per-child hint.
    final missing = !readOnly && song != null && !mine && program.instrumentId != null && notes.isEmpty;
    return RdListRow(
      key: ValueKey('rd-own-program-$index'),
      leading: numbered ? RdProgramNumber(index + 1) : const RdRowIcon(Icons.music_note),
      title: song == null
          ? l10n.historyFlutterUnknownSong
          : (song.fullNumber.isEmpty ? song.name : '${song.fullNumber}. ${song.name}'),
      subtitle: item.conductorName == null || mine ? null : l10n.signoutConductor(item.conductorName!),
      trailing: mine
          ? RdPill(l10n.redesignOwnYouConduct, tone: RdTone.primary)
          : missing
              ? RdPill(l10n.redesignOwnNoNotes, tone: RdTone.late)
              : null,
      onTap: song == null || readOnly ? null : () => _open(context, ref, item, index, notes),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, RdProgramItem item, int index, List<SongFile> notes) async {
    final song = item.song!;
    final l10n = context.l10n;
    final recording = rdRecordingOf(song);
    // "Zum Werk" opens the Werk page of the current group only.
    final sameGroup = ref.read(currentTenantIdProvider) == tenantId;
    final canOpenWork = sameGroup && canOpenSongsTab(ref.read(effectiveRoleProvider));
    final action = await showModalBottomSheet<Object>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.rd.bg,
      builder: (ctx) {
        final p = ctx.rd;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: Text(song.name, style: RdType.cardTitle(p))),
                const SizedBox(height: 4),
                Text(
                  [
                    l10n.redesignEventWorkNumber('${index + 1}'),
                    if (item.conductorName != null) l10n.signoutConductor(item.conductorName!),
                  ].join(' · '),
                  style: RdType.meta(p, size: 15),
                ),
                const SizedBox(height: 16),
                if (notes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RdCard(
                      padding: const EdgeInsets.all(14),
                      color: p.lateSoft,
                      child: Text(l10n.redesignOwnNoNotesFor, style: TextStyle(fontSize: 15, color: p.text)),
                    ),
                  ),
                RdGroupedList(children: [
                  for (final f in notes)
                    RdListRow(
                      leading: const RdRowIcon(Icons.description_outlined),
                      title: l10n.redesignOwnOpenMine,
                      subtitle: notes.length == 1 ? rdFileKind(f) : '${f.fileName} · ${rdFileKind(f)}',
                      onTap: () => Navigator.of(ctx).pop(f),
                    ),
                  if (recording != null)
                    RdListRow(
                      leading: const RdRowIcon(Icons.play_arrow_rounded),
                      title: l10n.signoutListenRecording,
                      subtitle: rdFileKind(recording),
                      onTap: () => Navigator.of(ctx).pop('recording'),
                    ),
                  if (canOpenWork)
                    RdListRow(
                      leading: const RdRowIcon(Icons.music_note_outlined),
                      title: l10n.attendanceToSong,
                      subtitle: l10n.redesignEventToWorkHint,
                      onTap: () => Navigator.of(ctx).pop('song'),
                    ),
                ]),
              ],
            ),
          ),
        );
      },
    );
    if (action == null || !context.mounted) return;
    if (action is SongFile) {
      await openSongFile(context, action);
    } else if (action == 'recording') {
      await ref
          .read(audioPlayerServiceProvider.notifier)
          .playFromUrl(recording!.url, recording.fileName, '${song.fullNumber} ${song.name}'.trim());
    } else if (action == 'song') {
      context.push(RedesignRoutes.work(song.id!));
    }
  }

  Future<void> _printMine(BuildContext context, WidgetRef ref, List<SongPrintEntry> entries, String title) async {
    final l10n = context.l10n;
    final result = await ref.read(songPrintServiceProvider).printEntries(entries, '$title.pdf');
    if (!context.mounted || result == null) return;
    if (result.pageCount == 0) {
      ToastHelper.showWarning(context, l10n.signoutFlutterNoPrintableScores);
    } else if (result.skipped > 0) {
      ToastHelper.showWarning(context, l10n.signoutFlutterFilesSkipped(result.skipped));
    }
  }
}
