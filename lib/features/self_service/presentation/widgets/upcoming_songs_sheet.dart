import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../data/providers/upcoming_songs_provider.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../songs/data/song_print_service.dart';
import 'song_options_sheet.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// "Aktuelle Werke" sheet (Ionic signout songsModal): one inset list per
/// Termin, rows "Nr. Name" / "Dirigent: …", red rows when there are no notes
/// for the player's instrument, tap opens the song options.
class UpcomingSongsSheet extends ConsumerWidget {
  const UpcomingSongsSheet({super.key});

  /// One merged PDF of all upcoming songs' files for the player's own
  /// instrument (choir: fallback to files noted "Chor").
  Future<void> _printAllCurrentFiles(BuildContext context, WidgetRef ref) async {
    final groups = ref.read(upcomingSongsProvider).valueOrNull ?? const [];
    final player = await ref.read(currentSelfServicePlayerProvider.future);
    final instrumentId =
        player?.instrument ?? await ref.read(currentPlayerInstrumentProvider.future);
    final isChoir = ref.read(currentTenantProvider)?.type == 'choir';
    final entries = collectCurrentSongPrintEntries(groups, instrumentId, isChoir: isChoir);
    if (!context.mounted) return;
    if (entries.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.signoutNoScoresFound);
      return;
    }
    final result = await ref
        .read(songPrintServiceProvider)
        .printEntries(entries, 'aktuelle_noten.pdf');
    if (!context.mounted || result == null) return;
    if (result.pageCount == 0) {
      ToastHelper.showWarning(context, context.l10n.signoutFlutterNoPrintableScores);
    } else if (result.skipped > 0) {
      ToastHelper.showWarning(
          context, context.l10n.signoutFlutterFilesSkipped(result.skipped));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(upcomingSongsProvider);
    final instrumentAsync = ref.watch(currentPlayerInstrumentProvider);
    final isChoir = ref.watch(currentTenantProvider)?.type == 'choir';
    final groupCount = songsAsync.valueOrNull?.length ?? 0;

    // Ionic: breakpoints 0.8 (several Termine) / 0.6 (one Termin)
    return DraggableScrollableSheet(
      initialChildSize: groupCount > 1 ? 0.8 : 0.6,
      minChildSize: 0.3,
      maxChildSize: 1,
      expand: false,
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // UX_SELF: Ionic toolbar – close (start), title, print (end)
              IonSheetHeader(
                title: context.l10n.signoutCurrentSongs,
                start: [
                  IconButton(
                    tooltip: context.l10n.commonClose,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
                end: [
                  // MISC2: Ionic signout printAllCurrentFiles
                  IconButton(
                    tooltip: context.l10n.signoutFlutterPrintAllScores,
                    icon: const Icon(Icons.print_outlined),
                    onPressed: () => _printAllCurrentFiles(context, ref),
                  ),
                ],
              ),
              Expanded(
                child: songsAsync.when(
                  loading: () => const Center(child: AppSpinner()),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                        const SizedBox(height: AppDimensions.paddingM),
                        Text(context.l10n.signoutFlutterError(friendlyErrorMessage(error))),
                        TextButton(
                          onPressed: () => ref.invalidate(upcomingSongsProvider),
                          child: Text(context.l10n.messagesRetry),
                        ),
                      ],
                    ),
                  ),
                  data: (songGroups) {
                    if (songGroups.isEmpty) {
                      return Center(
                        child: Text(
                          context.l10n.signoutFlutterNoCurrentSongs,
                          style: const TextStyle(color: AppColors.medium),
                        ),
                      );
                    }
                    final playerInstrument = instrumentAsync.valueOrNull;
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: AppDimensions.paddingL),
                      itemCount: songGroups.length,
                      itemBuilder: (context, i) => _SongGroupSection(
                        group: songGroups[i],
                        playerInstrumentId: playerInstrument,
                        isChoir: isChoir,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Ionic hasSongNotesForPlayer: the song lists the player's instrument
/// (choir: or has a file noted "Chor").
bool hasSongNotesForPlayer(Song? song, int? instrumentId, {required bool isChoir}) {
  if (song == null) return false;
  final hasInstrument =
      instrumentId != null && (song.instrumentIds ?? const <int>[]).contains(instrumentId);
  if (isChoir) {
    final hasChoirNote =
        (song.files ?? const <SongFile>[]).any((f) => f.note?.toLowerCase() == 'chor');
    return hasInstrument || hasChoirNote;
  }
  return hasInstrument;
}

/// One inset list per Termin: date header + songs.
class _SongGroupSection extends StatelessWidget {
  const _SongGroupSection({
    required this.group,
    required this.isChoir,
    this.playerInstrumentId,
  });

  final UpcomingSongGroup group;
  final int? playerInstrumentId;
  final bool isChoir;

  @override
  Widget build(BuildContext context) {
    final songs = group.songs.where((h) => h.song != null).toList();
    // Ionic: ion-list inset > ion-list-header (date) + ion-item-group
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IonListHeader(
          [
            DateHelper.getReadableDate(group.date),
            if (group.typeInfo != null && group.typeInfo!.isNotEmpty) group.typeInfo!,
          ].join(' · '),
        ),
        IonInsetList(
          children: [
            for (var i = 0; i < songs.length; i++)
              _SongListItem(
                song: songs[i].song!,
                conductorName: songs[i].conductorName ?? songs[i].otherConductor,
                missingNotes:
                    !hasSongNotesForPlayer(songs[i].song, playerInstrumentId, isChoir: isChoir),
                playerInstrumentId: playerInstrumentId,
              ),
          ],
        ),
      ],
    );
  }
}

/// Song row: "Nr. Name", "Dirigent: …"; red when there are no notes for the
/// player (Ionic color="danger"); download button for the song link.
class _SongListItem extends StatelessWidget {
  const _SongListItem({
    required this.song,
    this.conductorName,
    this.missingNotes = false,
    this.playerInstrumentId,
  });

  final Song song;
  final String? conductorName;
  final bool missingNotes;
  final int? playerInstrumentId;

  @override
  Widget build(BuildContext context) {
    final fg = missingNotes ? Colors.white : null;
    final number = song.fullNumber;
    // Ionic ion-label (iOS): h2 17px, h3 14px; button items show the chevron.
    final ios = isIosLook(context);
    final hasLink = song.link != null && song.link!.isNotEmpty;
    return ListTile(
      tileColor: missingNotes ? AppColors.danger : null,
      textColor: fg,
      iconColor: fg,
      minVerticalPadding: ios ? 10 : null,
      title: Text(
        number.isEmpty ? song.name : '$number. ${song.name}',
        style: ios ? const TextStyle(fontSize: 17) : null,
      ),
      subtitle: conductorName != null && conductorName!.isNotEmpty
          ? Text(
              context.l10n.signoutConductor(conductorName!),
              style: ios
                  ? TextStyle(fontSize: 14, color: fg ?? Theme.of(context).colorScheme.onSurface)
                  : null,
            )
          : null,
      trailing: hasLink || ios
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasLink)
                  IconButton(
                    icon: Icon(Icons.download_outlined, color: fg ?? AppColors.primary),
                    tooltip: context.l10n.signoutOpenScoreLink,
                    onPressed: () => openSongLink(context, song.link!),
                  ),
                if (ios)
                  Icon(Icons.chevron_right,
                      color: (fg ?? AppColors.medium).withValues(alpha: 0.6)),
              ],
            )
          : null,
      onTap: () => showSongOptionsSheet(
        context,
        song: song,
        playerInstrumentId: playerInstrumentId,
      ),
    );
  }
}

/// Collects one print entry per upcoming song: the file for [instrumentId],
/// or for choirs the file noted "Chor" (Ionic printAllCurrentFiles).
List<SongPrintEntry> collectCurrentSongPrintEntries(
  List<UpcomingSongGroup> groups,
  int? instrumentId, {
  required bool isChoir,
}) {
  final entries = <SongPrintEntry>[];
  for (final group in groups) {
    for (final his in group.songs) {
      final song = his.song;
      final files = song?.files;
      if (song == null || files == null) continue;
      var file = files.where((f) => f.instrumentId == instrumentId).firstOrNull;
      if (file == null && isChoir) {
        file = files.where((f) => f.note?.toLowerCase() == 'chor').firstOrNull;
      }
      if (file != null) entries.add(SongPrintEntry(song: song, file: file));
    }
  }
  return entries;
}

/// Shows the upcoming songs sheet as a bottom sheet
Future<void> showUpcomingSongsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const UpcomingSongsSheet(),
  );
}
