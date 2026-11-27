import 'package:flutter/material.dart';

import '../../../../../core/services/native/native_file_service.dart';
import '../../../../../core/theme/redesign/rd_theme.dart';
import '../../../../../data/models/song/song.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../planning/presentation/widgets/rd_plan_widgets.dart' show showRdPlanSheet;
import '../../../../../shared/widgets/redesign/rd_widgets.dart';

/// "Aktuelle Werke" sheet for self-service & parents views.
/// "Nr. Name" / "Dirigent: …" with the download icon when the song has a
/// link; tapping a row opens the link.
Future<void> showCurrentSongsSheet(
  BuildContext context,
  List<({String date, List<SongHistory> history})> groups,
) {
  return showRdPlanSheet<void>(
    context,
    title: context.l10n.signoutCurrentSongs,
    builder: (ctx, _) => [
      for (final group in groups) ...[
        RdGroupLabel(group.date),
        RdGroupedList(
          children: [
            for (final his in group.history)
              if (his.song != null)
                RdListRow(
                  title: '${his.song!.number ?? ''}. ${his.song!.name}',
                  subtitle: (his.conductorName ?? '').isNotEmpty
                      ? ctx.l10n.signoutConductor(his.conductorName!)
                      : null,
                  trailing: (his.song!.link ?? '').isNotEmpty
                      ? Icon(Icons.download_outlined, color: ctx.rd.link, size: 20)
                      : null,
                  showChevron: false,
                  onTap: (his.song!.link ?? '').isEmpty
                      ? null
                      : () => NativeFileService.openLinkInApp(Uri.parse(his.song!.link!)),
                ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    ],
  );
}
