part of 'song_providers.dart';

// ============================================================================
// Songs list data (authenticated and public share link)
// ============================================================================

/// Everything the songs list needs - for the logged-in tenant or for a
/// public song sharing link (Ionic `/:songSharingId`).
class SongsListData {
  const SongsListData({
    required this.tenantId,
    required this.tenantType,
    required this.songs,
    required this.categories,
    required this.groups,
    required this.groupCategories,
    required this.currentSongs,
    required this.additionalFields,
    this.publicTenant,
    this.songSharingId,
  });

  /// Tenant used for persisted filter settings (current or shared tenant)
  final int tenantId;
  final String tenantType;
  final List<Song> songs;
  final List<SongCategory> categories;

  /// All groups of the tenant (incl. main group)
  final List<Group> groups;
  final List<GroupCategory> groupCategories;
  final List<CurrentSongsGroup> currentSongs;
  final List<SongAdditionalField> additionalFields;

  /// Set when the list is shown via a public share link
  final Tenant? publicTenant;
  final String? songSharingId;

  bool get isPublic => publicTenant != null;
  bool get isOrchestra => tenantType == 'orchestra';
  bool get isChoir => tenantType == 'choir';

  /// Groups shown as instruments (all but the main group)
  List<Group> get instruments =>
      groups.where((g) => g.maingroup != true).toList();

  /// The same data with other [songs] (e.g. the Werke of one Sammlung).
  SongsListData withSongs(List<Song> songs) => SongsListData(
        tenantId: tenantId,
        tenantType: tenantType,
        songs: songs,
        categories: categories,
        groups: groups,
        groupCategories: groupCategories,
        currentSongs: currentSongs,
        additionalFields: additionalFields,
        publicTenant: publicTenant,
        songSharingId: songSharingId,
      );
}

/// Ionic: for orchestras, songs without instrument_ids count as fully
/// instrumented (all group ids).
List<Song> _applyDefaultInstruments(List<Song> songs, List<Group> groups, bool isOrchestra) {
  if (!isOrchestra) return songs;
  final allIds = groups.map((g) => g.id).whereType<int>().toList();
  return songs
      .map((s) => (s.instrumentIds?.isNotEmpty ?? false)
          ? s
          : s.copyWith(instrumentIds: allIds))
      .toList();
}

/// Data for the songs list. `null` sharing id = logged-in tenant.
/// Returns null if a public sharing id is invalid.
final songsListDataProvider =
    FutureProvider.autoDispose.family<SongsListData?, String?>((ref, sharingId) async {
  // SOL_FIX16: account link before the first await (see account_scoped test).
  ref.watch(currentAuthUserIdProvider);
  if (sharingId != null) {
    final repo = ref.watch(publicSongRepositoryProvider);
    final shared = await repo.getTenantBySongSharingId(sharingId);
    if (shared == null) return null;
    final tid = shared.id;
    final results = await Future.wait([
      repo.getSongs(tid),
      repo.getSongCategories(tid),
      repo.getGroups(tid),
      repo.getGroupCategories(tid).catchError((_) => <GroupCategory>[]),
      repo.getCurrentSongs(tid).catchError((_) => <CurrentSongsGroup>[]),
    ]);
    final groups = results[2] as List<Group>;
    final isOrchestra = shared.tenant.type == 'orchestra';
    return SongsListData(
      tenantId: tid,
      tenantType: shared.tenant.type,
      songs: _applyDefaultInstruments(results[0] as List<Song>, groups, isOrchestra),
      categories: results[1] as List<SongCategory>,
      groups: groups,
      groupCategories: results[3] as List<GroupCategory>,
      currentSongs: results[4] as List<CurrentSongsGroup>,
      additionalFields: shared.additionalFields,
      publicTenant: shared.tenant,
      songSharingId: sharingId,
    );
  }

  final tenant = ref.watch(currentTenantProvider);
  final tenantId = tenant?.id;
  if (tenantId == null) return null;

  final settings = await ref.watch(songTenantSettingsProvider.future);
  final songs = await ref.watch(songsProvider.future);
  final categories = await ref.watch(songCategoriesProvider.future);
  final groups = await ref.watch(groupsProvider.future);
  List<GroupCategory> groupCategories;
  try {
    groupCategories = await ref.watch(groupCategoriesProvider.future);
  } catch (_) {
    groupCategories = const [];
  }
  List<CurrentSongsGroup> currentSongs;
  try {
    currentSongs = await ref.watch(currentSongsProvider.future);
  } catch (_) {
    currentSongs = const [];
  }
  final isOrchestra = tenant!.type == 'orchestra';
  return SongsListData(
    tenantId: tenantId,
    tenantType: tenant.type,
    songs: _applyDefaultInstruments(songs, groups, isOrchestra),
    categories: categories,
    groups: groups,
    groupCategories: groupCategories,
    currentSongs: currentSongs,
    additionalFields: settings.additionalFields,
    songSharingId: settings.songSharingId ?? tenant.songSharingId,
  );
});

// ============================================================================
// Song detail data (authenticated and public share link)
// ============================================================================

/// Parameters for [songDetailDataProvider]
typedef SongDetailParams = ({int songId, String? sharingId});

/// Everything the song detail page needs.
class SongDetailData {
  const SongDetailData({
    required this.song,
    required this.tenantType,
    required this.instruments,
    List<Group>? partGroups,
    required this.categories,
    required this.additionalFields,
    required this.history,
    required this.readOnly,
    this.publicTenant,
    this.songSharingId,
    this.mainGroupId,
  }) : partGroups = partGroups ?? instruments;

  final Song song;
  final String tenantType;

  /// Groups without the main group (only loaded for orchestras)
  final List<Group> instruments;

  /// Groups a file can belong to on the Beta Werk page: the groups without
  /// the main group for every kind of tenant (a choir's voices too), as the
  /// Noten-Import knows them. With [instruments] empty outside orchestras
  /// the upload took an existing "Tenor" for a new group. Defaults to
  /// [instruments].
  final List<Group> partGroups;
  final List<SongCategory> categories;
  final List<SongAdditionalField> additionalFields;

  /// Werkhistorie (only loaded for admins/responsibles)
  final List<SongHistory> history;
  final bool readOnly;
  final Tenant? publicTenant;
  final String? songSharingId;
  final int? mainGroupId;

  bool get isPublic => publicTenant != null;
  bool get isOrchestra => tenantType == 'orchestra';
  bool get isChoir => tenantType == 'choir';
}

final songDetailDataProvider = FutureProvider.autoDispose
    .family<SongDetailData?, SongDetailParams>((ref, params) async {
  // SOL_FIX16: account link before the first await (see account_scoped test).
  ref.watch(currentAuthUserIdProvider);
  if (params.sharingId != null) {
    final repo = ref.watch(publicSongRepositoryProvider);
    final shared = await repo.getTenantBySongSharingId(params.sharingId!);
    if (shared == null) return null;
    final song = await repo.getSong(params.songId, shared.id);
    if (song == null) return null;
    final isOrchestra = shared.tenant.type == 'orchestra';
    final groups = isOrchestra ? await repo.getGroups(shared.id) : const <Group>[];
    List<SongCategory> categories;
    try {
      categories = await repo.getSongCategories(shared.id);
    } catch (_) {
      categories = const [];
    }
    return SongDetailData(
      song: song,
      tenantType: shared.tenant.type,
      instruments: groups.where((g) => g.maingroup != true).toList(),
      categories: categories,
      additionalFields: shared.additionalFields,
      history: const [],
      readOnly: true,
      publicTenant: shared.tenant,
      songSharingId: params.sharingId,
    );
  }

  final tenant = ref.watch(currentTenantProvider);
  if (tenant?.id == null) return null;
  final role = ref.watch(currentRoleProvider);
  final readOnly = !(role.isAdmin || role.isResponsible);

  final settings = await ref.watch(songTenantSettingsProvider.future);
  final song = await ref.watch(songByIdProvider(params.songId).future);
  if (song == null) return null;

  final groups = await ref.watch(groupsProvider.future);
  List<SongCategory> categories;
  try {
    categories = await ref.watch(songCategoriesProvider.future);
  } catch (_) {
    categories = const [];
  }
  List<SongHistory> history = const [];
  if (!readOnly) {
    try {
      history = await ref.watch(songHistoryProvider(params.songId).future);
    } catch (_) {
      // Non-critical
    }
  }

  final isOrchestra = tenant!.type == 'orchestra';
  final partGroups = groups.where((g) => g.maingroup != true).toList();
  return SongDetailData(
    song: song,
    tenantType: tenant.type,
    instruments: isOrchestra ? partGroups : const [],
    partGroups: partGroups,
    categories: categories,
    additionalFields: settings.additionalFields,
    history: history,
    readOnly: readOnly,
    songSharingId: settings.songSharingId ?? tenant.songSharingId,
    mainGroupId: groups.where((g) => g.maingroup == true).firstOrNull?.id,
  );
});
