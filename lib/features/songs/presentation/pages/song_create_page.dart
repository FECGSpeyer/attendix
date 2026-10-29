import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/song_providers.dart';
import '../widgets/add_song_sheet.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Full page variant of "Werk hinzufügen" (route `/settings/songs/new`).
/// The songs list opens the same form as a sheet (like the Ionic modal).
class SongCreatePage extends ConsumerWidget {
  const SongCreatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(songsListDataProvider(null));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.songsAddSong)),
      body: dataAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (e, _) => Center(child: Text(context.l10n.songsFlutterErrorWith(friendlyErrorMessage(e)))),
        data: (data) => data == null
            ? const SizedBox.shrink()
            : AddSongSheet(
                data: data,
                onCreated: (id) => context.pushReplacement('/settings/songs/$id'),
              ),
      ),
    );
  }
}
