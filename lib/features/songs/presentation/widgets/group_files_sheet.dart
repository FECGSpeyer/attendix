import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../data/models/song/song.dart';
import '../../data/song_print_service.dart';
import 'song_file_opener.dart';
import '../../../../l10n/l10n.dart';

/// Gruppenverzeichnis (Ionic groupDirectoryModal): pick a group, see all of
/// its files across songs, open or print them as one folder.
class GroupFilesSheet extends ConsumerStatefulWidget {
  const GroupFilesSheet({super.key, required this.songs, required this.groups});

  final List<Song> songs;

  /// Groups with files (incl. virtual "Dirigenten" group)
  final List<Group> groups;

  @override
  ConsumerState<GroupFilesSheet> createState() => _GroupFilesSheetState();
}

class _GroupFilesSheetState extends ConsumerState<GroupFilesSheet> {
  Group? _selectedGroup;

  List<({Song song, SongFile file})> get _files =>
      _selectedGroup?.id == null ? const [] : filesForGroup(widget.songs, _selectedGroup!.id!);

  Future<void> _printFolder() async {
    final files = [..._files]
      ..sort((a, b) {
        final p = (a.song.prefix ?? '').compareTo(b.song.prefix ?? '');
        if (p != 0) return p;
        return (a.song.number ?? 0).compareTo(b.song.number ?? 0);
      });
    if (files.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.songsNoScoresGroup);
      return;
    }
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final result = await ref.read(songPrintServiceProvider).printEntries(
          [for (final e in files) SongPrintEntry(song: e.song, file: e.file)],
          'Mappe_${_selectedGroup!.name}_$date.pdf',
        );
    if (!mounted || result == null) return;
    if (result.pageCount == 0) {
      ToastHelper.showWarning(context, context.l10n.svcNoPrintableScores);
    } else if (result.skipped > 0) {
      ToastHelper.showWarning(context, context.l10n.songsFlutterFilesSkipped(result.skipped));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedGroup;
    final files = _files;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.3,
      maxChildSize: 1,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingS, AppDimensions.paddingS, AppDimensions.paddingS, 0),
              child: Row(
                children: [
                  if (selected != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _selectedGroup = null),
                    )
                  else
                    const SizedBox(width: AppDimensions.paddingS),
                  Expanded(
                    child: Text(
                      selected?.name ?? context.l10n.songsChooseGroup,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (selected != null && files.isNotEmpty)
                    IconButton(
                      tooltip: context.l10n.songsPrint,
                      icon: const Icon(Icons.print_outlined),
                      onPressed: _printFolder,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingS),
              child: Text(
                context.l10n.songsOnlyGroupsWithFiles,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.medium),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: selected == null
                  ? ListView(
                      controller: scrollController,
                      children: [
                        for (final group in widget.groups)
                          ListTile(
                            title: Text(group.name),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => setState(() => _selectedGroup = group),
                          ),
                      ],
                    )
                  : ListView(
                      controller: scrollController,
                      children: [
                        for (final entry in files)
                          ListTile(
                            title: Text(entry.file.fileName),
                            subtitle: Text(
                              '${entry.song.prefix ?? ''}${entry.song.number ?? ''} ${entry.song.name}',
                            ),
                            onTap: () => openSongFile(context, entry.file),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

Future<void> showGroupFilesSheet(
  BuildContext context, {
  required List<Song> songs,
  required List<Group> groups,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => GroupFilesSheet(songs: songs, groups: groups),
  );
}
