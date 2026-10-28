import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../data/song_print_service.dart';

/// "Aktuelle Werke" sheet (Ionic currentSongsModal)
class CurrentSongsSheet extends ConsumerWidget {
  const CurrentSongsSheet({
    super.key,
    required this.data,
    required this.canPrint,
    required this.onOpenSong,
  });

  final SongsListData data;
  final bool canPrint;
  final void Function(int songId) onOpenSong;

  Future<void> _printNotesForGroup(BuildContext context, WidgetRef ref) async {
    final groups = data.instruments;
    final group = await showDialog<Group>(
      context: context,
      builder: (ctx) => _GroupChoiceDialog(groups: groups),
    );
    if (group == null || !context.mounted) return;

    final entries = <SongPrintEntry>[];
    for (final g in data.currentSongs) {
      for (final his in g.history) {
        final song = his.song;
        final file = song?.files?.where((f) => f.instrumentId == group.id).firstOrNull;
        if (song != null && file != null) {
          entries.add(SongPrintEntry(song: song, file: file));
        }
      }
    }
    if (entries.isEmpty) {
      ToastHelper.showWarning(
          context, 'Keine Noten für diese Gruppe in den aktuellen Werken gefunden.');
      return;
    }

    final date = DateTime.now().toIso8601String().substring(0, 10);
    final result = await ref
        .read(songPrintServiceProvider)
        .printEntries(entries, 'Noten_${group.name}_$date.pdf');
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
    return DraggableScrollableSheet(
      initialChildSize: data.currentSongs.length > 1 ? 0.8 : 0.5,
      minChildSize: 0.3,
      maxChildSize: 1,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingM, AppDimensions.paddingS, AppDimensions.paddingS, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Aktuelle Werke',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (canPrint)
                    IconButton(
                      tooltip: 'Noten drucken',
                      icon: const Icon(Icons.print_outlined),
                      onPressed: () => _printNotesForGroup(context, ref),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: AppDimensions.paddingL),
                children: [
                  for (final group in data.currentSongs) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, 4),
                      child: Text(
                        group.date,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.medium,
                        ),
                      ),
                    ),
                    for (final his in group.history)
                      if (his.song != null)
                        ListTile(
                          dense: true,
                          title: Text(
                            '${his.song!.prefix ?? ''}${his.song!.number ?? ''} ${his.song!.name}',
                          ),
                          onTap: his.song!.id == null
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  onOpenSong(his.song!.id!);
                                },
                        ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GroupChoiceDialog extends StatefulWidget {
  const _GroupChoiceDialog({required this.groups});

  final List<Group> groups;

  @override
  State<_GroupChoiceDialog> createState() => _GroupChoiceDialogState();
}

class _GroupChoiceDialogState extends State<_GroupChoiceDialog> {
  Group? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gruppe wählen'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final g in widget.groups)
              RadioListTile<int?>(
                value: g.id,
                groupValue: _selected?.id,
                title: Text(g.name),
                onChanged: (_) => setState(() => _selected = g),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selected == null) {
              ToastHelper.showWarning(context, 'Bitte eine Gruppe auswählen.');
              return;
            }
            Navigator.of(context).pop(_selected);
          },
          child: const Text('Noten drucken'),
        ),
      ],
    );
  }
}

Future<void> showCurrentSongsSheet(
  BuildContext context, {
  required SongsListData data,
  required bool canPrint,
  required void Function(int songId) onOpenSong,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CurrentSongsSheet(
      data: data,
      canPrint: canPrint,
      onOpenSong: onOpenSong,
    ),
  );
}
