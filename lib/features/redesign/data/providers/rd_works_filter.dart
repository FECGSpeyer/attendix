import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/song_filter_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../data/models/song/song.dart';
import '../../../../data/models/song/song_filter.dart';
import '../rd_works_logic.dart';

/// REDESIGN: "Nur zeigen" filters of the Werke tab that the stored filter
/// of the old list does not have (kept while the app runs).
final rdWorksOnlyProvider = StateProvider<Set<RdWorksOnly>>((ref) => const {});

/// The Werke of the list: the stored filter and sort of the old list, the
/// "Nur zeigen" filters and the search over title and number. "Am
/// längsten nicht gespielt" lists Werke that were never played first.
List<Song> rdFilteredWorks({
  required SongsListData data,
  required SongFilter filter,
  required Set<RdWorksOnly> only,
  required String query,
  required int? groupId,
  required Map<int, int>? playerCounts,
}) {
  final filtered = rdApplyOnly(
    applySongFilter(
      data.songs,
      filter,
      additionalFields: data.additionalFields,
    ).where((s) => rdWorkMatches(s, query)).toList(),
    only,
    groupId: groupId,
    groups: data.groups,
    playerCounts: playerCounts,
    orchestra: data.isOrchestra,
    choir: data.isChoir,
  );
  if (filter.sortOption != SongSortOption.lastSungAsc) return filtered;
  bool never(Song s) => DateTime.tryParse(s.lastSung ?? '') == null;
  return [...filtered.where(never), ...filtered.where((s) => !never(s))];
}
