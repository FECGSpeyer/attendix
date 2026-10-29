import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../data/song_print_service.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../../../../shared/widgets/layout/ionic_ios.dart';

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
    final group = await showAppDialog<Group>(
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
      ToastHelper.showWarning(context, context.l10n.songsNoScoresCurrent);
      return;
    }

    final date = DateTime.now().toIso8601String().substring(0, 10);
    final result = await ref
        .read(songPrintServiceProvider)
        .printEntries(entries, 'Noten_${group.name}_$date.pdf');
    if (!context.mounted || result == null) return;
    if (result.pageCount == 0) {
      ToastHelper.showWarning(context, context.l10n.svcNoPrintableScores);
    } else if (result.skipped > 0) {
      ToastHelper.showWarning(context, context.l10n.songsFlutterFilesSkipped(result.skipped));
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
        // UX_SONGS_SELF: Ionic currentSongsModal: toolbar (title + print),
        // light content with one inset list (list header per date).
        return Column(
          children: [
            IonSheetHeader(
              title: context.l10n.songsCurrent,
              end: [
                if (canPrint)
                  IconButton(
                    tooltip: context.l10n.songsPrintScores,
                    icon: const Icon(Icons.print_outlined),
                    onPressed: () => _printNotesForGroup(context, ref),
                  ),
              ],
            ),
            Expanded(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: AppDimensions.paddingL),
                  children: [
                    for (final group in data.currentSongs) ...[
                      IonListHeader(group.date),
                      IonInsetList(
                        children: [
                          for (final his in group.history)
                            if (his.song != null)
                              IonItem(
                                title: Text(
                                  '${his.song!.prefix ?? ''}${his.song!.number ?? ''} ${his.song!.name}',
                                ),
                                detail: true,
                                onTap: his.song!.id == null
                                    ? null
                                    : () {
                                        Navigator.of(context).pop();
                                        onOpenSong(his.song!.id!);
                                      },
                              ),
                        ],
                      ),
                    ],
                  ],
                ),
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
    return AppAlertDialog(
      title: Text(context.l10n.songsChooseGroup),
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
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selected == null) {
              ToastHelper.showWarning(context, context.l10n.songsChooseGroupPlease);
              return;
            }
            Navigator.of(context).pop(_selected);
          },
          child: Text(context.l10n.songsPrintScores),
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
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CurrentSongsSheet(
      data: data,
      canPrint: canPrint,
      onOpenSong: onOpenSong,
    ),
  );
}
