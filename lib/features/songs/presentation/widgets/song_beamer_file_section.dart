import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_beamer.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart';

/// "SongBeamer-Datei" of a Werk (Ionic 4.17.10 song page `showBeamerFile`):
/// only for organisations linked to the Gemeinde App with Beamer files on.
/// The file is written by the Gemeinde App; Attendix only shows it.
class SongBeamerFileSection extends ConsumerWidget {
  const SongBeamerFileSection({super.key, required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(currentOrganisationProvider).valueOrNull;
    if (!PlanBeamer.active(org, true)) return const SizedBox.shrink();
    final file = song.beamerFile;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IonListHeader(l10n.songsBeamerFile),
        IonInsetList(children: [
          IonItem(
            leading: Icon(Icons.tv_outlined, color: file != null ? AppColors.primary : AppColors.medium),
            title: Text(file?.name ?? l10n.planningBeamerNoFile),
            subtitle: Text(file != null ? l10n.planningBeamerChangeInApp : l10n.planningBeamerLinkInApp),
          ),
        ]),
      ],
    );
  }
}
