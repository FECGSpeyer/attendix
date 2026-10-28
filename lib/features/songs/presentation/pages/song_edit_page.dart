import 'package:flutter/material.dart';

import 'song_detail_page.dart';

/// Route `/settings/songs/:id/edit`.
///
/// Like Ionic, songs are edited inline on the detail page (admins and
/// responsibles get the editable form there), so this route shows it.
class SongEditPage extends StatelessWidget {
  const SongEditPage({super.key, required this.songId});

  final int songId;

  @override
  Widget build(BuildContext context) => SongDetailPage(songId: '$songId');
}
