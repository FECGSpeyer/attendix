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

/// Bottom sheet showing upcoming songs grouped by date
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
      ToastHelper.showWarning(context, 'Keine Noten für dein Instrument gefunden.');
      return;
    }
    final result = await ref
        .read(songPrintServiceProvider)
        .printEntries(entries, 'aktuelle_noten.pdf');
    if (!context.mounted || result == null) return;
    if (result.pageCount == 0) {
      ToastHelper.showWarning(context, 'Keine druckbaren Noten gefunden.');
    } else if (result.skipped > 0) {
      ToastHelper.showWarning(
          context, '${result.skipped} Datei(en) konnten nicht eingebunden werden.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(upcomingSongsProvider);
    final instrumentAsync = ref.watch(currentPlayerInstrumentProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.borderRadiusL),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.medium.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Row(
                  children: [
                    const Icon(Icons.library_music, color: AppColors.primary),
                    const SizedBox(width: AppDimensions.paddingS),
                    Expanded(
                      child: Text(
                        'Aktuelle Stücke',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    // MISC2: Ionic signout printAllCurrentFiles
                    IconButton(
                      tooltip: 'Alle Noten drucken',
                      icon: const Icon(Icons.print_outlined),
                      onPressed: () => _printAllCurrentFiles(context, ref),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: songsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.danger),
                        const SizedBox(height: AppDimensions.paddingM),
                        Text('Fehler: $error'),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(upcomingSongsProvider),
                          child: const Text('Erneut versuchen'),
                        ),
                      ],
                    ),
                  ),
                  data: (songGroups) {
                    if (songGroups.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.music_off,
                                size: 48, color: AppColors.medium),
                            SizedBox(height: AppDimensions.paddingM),
                            Text('Keine aktuellen Stücke'),
                            SizedBox(height: AppDimensions.paddingS),
                            Text(
                              'Für kommende Termine sind\nkeine Stücke eingetragen.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.medium),
                            ),
                          ],
                        ),
                      );
                    }

                    final playerInstrument = instrumentAsync.valueOrNull;

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      itemCount: songGroups.length,
                      itemBuilder: (context, groupIndex) {
                        final group = songGroups[groupIndex];
                        return _SongGroupSection(
                          group: group,
                          playerInstrumentId: playerInstrument,
                        );
                      },
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

/// Section showing songs for one date
class _SongGroupSection extends StatelessWidget {
  const _SongGroupSection({
    required this.group,
    this.playerInstrumentId,
  });

  final UpcomingSongGroup group;
  final int? playerInstrumentId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingS,
            vertical: AppDimensions.paddingS,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
          ),
          child: Row(
            children: [
              const Icon(Icons.event, size: 16, color: AppColors.primary),
              const SizedBox(width: AppDimensions.paddingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateHelper.getReadableDate(group.date),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (group.typeInfo != null)
                      Text(
                        group.typeInfo!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.medium,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${group.songs.length} Stück${group.songs.length != 1 ? 'e' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.medium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.paddingS),
        // Song list
        ...group.songs.map((history) {
          final song = history.song;
          if (song == null) return const SizedBox.shrink();

          final hasInstrument = _hasInstrumentFiles(song);
          final isMissing = !hasInstrument && playerInstrumentId != null;

          return _SongListItem(
            song: song,
            conductorName: history.conductorName ?? history.otherConductor,
            isInstrumentMissing: isMissing,
            playerInstrumentId: playerInstrumentId,
          );
        }),
        const SizedBox(height: AppDimensions.paddingM),
      ],
    );
  }

  bool _hasInstrumentFiles(Song song) {
    if (playerInstrumentId == null) return true;
    final instrumentIds = song.instrumentIds;
    if (instrumentIds == null || instrumentIds.isEmpty) return true;
    return instrumentIds.contains(playerInstrumentId);
  }
}

/// Single song list item
class _SongListItem extends StatelessWidget {
  const _SongListItem({
    required this.song,
    this.conductorName,
    this.isInstrumentMissing = false,
    this.playerInstrumentId,
  });

  final Song song;
  final String? conductorName;
  final bool isInstrumentMissing;
  final int? playerInstrumentId;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor:
            isInstrumentMissing ? AppColors.warning : AppColors.primary,
        radius: 18,
        child: Text(
          song.fullNumber.isEmpty ? '?' : song.fullNumber,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          if (isInstrumentMissing) ...[
            const Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              song.name,
              style: TextStyle(
                color: isInstrumentMissing ? AppColors.warning : null,
              ),
            ),
          ),
        ],
      ),
      subtitle: conductorName != null
          ? Text(
              conductorName!,
              style: const TextStyle(fontSize: 12),
            )
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showSongOptions(context),
      ),
      onTap: () => _showSongOptions(context),
    );
  }

  void _showSongOptions(BuildContext context) {
    showSongOptionsSheet(
      context,
      song: song,
      playerInstrumentId: playerInstrumentId,
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
    backgroundColor: Colors.transparent,
    builder: (context) => const UpcomingSongsSheet(),
  );
}
