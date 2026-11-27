import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../core/constants/enums.dart';
import '../../core/constants/table_names.dart' show SupabaseBuckets;
import '../../core/utils/archived_attendance.dart';
import '../../core/utils/date_helper.dart';
import '../../core/utils/profile_image_path.dart';
import '../models/person/person.dart';
import '../models/instrument/instrument.dart';
import '../models/shift/shift_plan.dart';
import '../../core/utils/people_shift_status.dart';
import '../../core/utils/person_matcher.dart';
import '../../core/utils/text_utils.dart';
import '../../core/utils/type_circle.dart';
import '../../core/utils/db_helpers.dart';
import '../../core/utils/duty_utils.dart' show dutySyncFieldsForStatus;
import '../../core/utils/helper_member.dart';
import '../../core/utils/paged_query.dart';
import '../../core/config/supabase_config.dart'
    show AccountScopeKey, currentAuthUserIdProvider;
import 'base_repository.dart';
import 'profile_repository.dart' show syncOwnPlayerImage;
import 'shared_person_fields.dart'
    show fetchSharedFieldValuesForPeople, organisationFieldDefaults, organisationPersonKeyOfRow;
import 'user_registration_repository.dart';
import '../../l10n/l10n.dart';
import '../../core/services/error_reporter.dart';
import '../../core/utils/handover_request.dart';
import '../../core/utils/parent_registration.dart';

part 'player_repository_attendance_sync.dart';
part 'player_repository_handover.dart';
part 'player_repository_lifecycle.dart';
part 'player_repository_queries.dart';

/// Provider for PlayerRepository
final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(ref);
});

/// SOL_FIX1: one immutable repository instance per tenant. A running
/// multi-step operation keeps its instance (and tenant) even when the user
/// switches tenants, instead of a shared instance changing tenant mid-flow.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final playerRepositoryForTenantProvider =
    Provider.family<PlayerRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _playerRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _playerRepositoryForAccountProvider =
    Provider.family<PlayerRepository, AccountScopeKey>((ref, key) {
  final repo = PlayerRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

/// Ionic DEFAULT_IMAGE (placeholder avatar).
const String kDefaultPersonImage =
    'https://ionicframework.com/docs/img/demos/avatar.svg';

/// Result of [PlayerRepository.handoverPlayer] for a single player.
/// [requested]: the target group got a waiting request in its Freigaben
/// (see `handover_request.dart`); nothing changed for the person yet.
enum HandoverResult { success, requested, duplicate, error }

/// Repository for player/person operations
class PlayerRepository extends _PlayerRepositoryCore
    with
        _PlayerAttendanceSyncMixin,
        _PlayerLifecycleMixin,
        _PlayerQueriesMixin,
        _PlayerHandoverMixin {
  PlayerRepository(super.ref);

  /// The note the asking group writes into its own person's history. The
  /// answer of the target group only acts on a source person whose history
  /// still has this note open ([openHandoverKeep]).
  static String handoverAskedNote(String targetTenantName, {required bool keep}) =>
      '$_handoverPrefix$targetTenantName" angefragt (${keep ? _handoverKeeps : _handoverMoves}).';

  /// Whether the source [row] is a person its own group asked to hand over
  /// to [targetTenantName], and what that group chose: true "stays active
  /// there too", false "moves completely", null when nothing is open (never
  /// asked, or already answered).
  ///
  /// The marker on the waiting row is plain JSON in the target group, so it
  /// alone never decides which person of another group is written to: only
  /// people the asking group itself offered can be reached, and only once.
  /// (The name is not compared: the target's leads may correct it while
  /// they take the person in.)
  static bool? openHandoverKeep(Map<String, dynamic> row, String targetTenantName) {
    final history = row['history'];
    // Requests still open, by the target group's name at that time.
    final open = <String, bool>{};
    for (final e in history is List ? history : const []) {
      final text = e is Map ? e['text'] : null;
      if (text is! String) continue;
      final asked = _handoverAsked.firstMatch(text);
      if (asked != null) {
        open[asked.group(1)!] = asked.group(2) == _handoverKeeps;
        continue;
      }
      final done = _handoverDone.firstMatch(text);
      if (done != null) {
        open.remove(done.group(1));
      } else if (text.startsWith(_handoverPrefix)) {
        final end = text.indexOf(_handoverDeclined, _handoverPrefix.length);
        if (end > 0) open.remove(text.substring(_handoverPrefix.length, end));
      }
    }
    // The group was renamed since: the only open request is this one.
    return open[targetTenantName] ?? (open.length == 1 ? open.values.single : null);
  }

}

abstract class _PlayerRepositoryCore extends BaseRepository with TenantAwareRepository {
  _PlayerRepositoryCore(super.ref);

  /// Get all active players for the current tenant
  Future<List<Person>> getPlayers({
    bool includeAttendances = false,
    bool all = false,
  }) async {
    try {
      var query = supabase
          .from('player')
          .select(includeAttendances ? '*, person_attendances(*)' : '*')
          .eq('tenantId', currentTenantId)
          .isFilter('pending', false);

      if (!all) {
        query = query.isFilter('left', null);
      }

      final response = await query
          .order('instrument', ascending: true)
          .order('isLeader', ascending: false)
          .order('lastName', ascending: true);

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPlayers');
      rethrow;
    }
  }

  /// Persons (archived ones too) on the shift plan [shiftId], filtered on
  /// the server and fully paged (Ionic deleteShift: getPlayers(true)
  /// filtered by shift_id).
  Future<List<Person>> getPlayersByShift(String shiftId) async {
    try {
      final rows = await fetchAllPages<Map<String, dynamic>>((from, to) async {
        final page = await supabase
            .from('player')
            .select('*')
            .eq('tenantId', currentTenantId)
            .eq('shift_id', shiftId)
            .isFilter('pending', false)
            .order('id', ascending: true)
            .range(from, to);
        return (page as List).cast<Map<String, dynamic>>();
      });
      return rows.map(Person.fromJson).toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPlayersByShift');
      rethrow;
    }
  }

  /// Get a single player by ID
  Future<Person?> getPlayerById(int id) async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('id', id)
          .eq('tenantId', currentTenantId)
          .maybeSingle();

      if (response == null) return null;
      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'getPlayerById');
      rethrow;
    }
  }

  /// Get player by app ID (user ID)
  ///
  /// One account can own several rows in a tenant (siblings registered with
  /// the parents' e-mail, an archived row next to a new one). Like Ionic
  /// PlayerService.getPlayerByAppId this prefers the active (not pending, not
  /// archived) row instead of failing on `maybeSingle`.
  Future<Person?> getPlayerByAppId(String appId) async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('appId', appId)
          .eq('tenantId', currentTenantId);

      final rows = (response as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return null;
      final active = rows.where((p) =>
          p['pending'] != true && (p['left'] == null || p['left'] == ''));
      return Person.fromJson(active.isNotEmpty ? active.first : rows.first);
    } catch (e, stack) {
      handleError(e, stack, 'getPlayerByAppId');
      rethrow;
    }
  }

  /// Get pending (not yet approved) players
  Future<List<Person>> getPendingPlayers() async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('pending', true)
          .order('created_at', ascending: true);

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPendingPlayers');
      rethrow;
    }
  }

  /// Get archived (left) players
  Future<List<Person>> getArchivedPlayers() async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .isFilter('pending', false)
          .not('left', 'is', null)
          .order('left', ascending: false);

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getArchivedPlayers');
      rethrow;
    }
  }

  /// Get active players for a specific instrument/voice group.
  ///
  /// Returns players whose `instrument` matches [instrumentId] and who are
  /// not pending and have not left. Ordered by leader first, then last name.
  Future<List<Person>> getPlayersByInstrument(int instrumentId) async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('instrument', instrumentId)
          .isFilter('left', null)
          .isFilter('pending', false)
          .order('isLeader', ascending: false)
          .order('lastName', ascending: true);

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPlayersByInstrument');
      rethrow;
    }
  }

  /// Get conductors (main group members)
  Future<List<Person>> getConductors(int mainGroupId, {bool includeLeft = false}) async {
    try {
      var query = supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('instrument', mainGroupId)
          .isFilter('pending', false);

      if (!includeLeft) {
        query = query.isFilter('left', null);
      }

      final response = await query.order('lastName', ascending: true);

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getConductors');
      rethrow;
    }
  }

  /// Returns players whose `parent_id` equals [parentId], in the current
  /// tenant. Filters out pending and left players (matches `isFilter`
  /// semantics used by the parents portal).
  ///
  /// Note: the DB column is `parent_id` (snake_case). Confirmed against
  /// existing repository methods and the Ionic db.service.ts.
  Future<List<Person>> getChildrenForParent(int parentId) async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('parent_id', parentId)
          // LOGIC_SELF: Ionic getPlayers (PARENT) `.is('pending', false)` —
          // approved players have pending=false, not NULL.
          .isFilter('pending', false)
          .isFilter('left', null)
          // PARITY_SELF: Ionic getPlayers (PARENT) order – instrument,
          // isLeader descending, lastName.
          .order('instrument', ascending: true)
          .order('isLeader', ascending: false)
          .order('lastName', ascending: true);
      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getChildrenForParent');
      rethrow;
    }
  }

  /// Get players by parent ID (for parent role)
  Future<List<Person>> getPlayersByParentId(int parentId) async {
    try {
      final response = await supabase
          .from('player')
          .select('*, person_attendances(*)')
          .eq('tenantId', currentTenantId)
          .eq('parent_id', parentId)
          .isFilter('pending', false)
          .isFilter('left', null)
          .order('instrument', ascending: true)
          .order('isLeader', ascending: false)
          .order('lastName', ascending: true);

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'getPlayersByParentId');
      rethrow;
    }
  }

  /// Find players by first and last name (for duplicate detection)
  Future<List<Person>> findPlayersByName(String firstName, String lastName) async {
    try {
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .ilike('firstName', firstName)
          .ilike('lastName', lastName);

      return (response as List)
          .map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      handleError(e, stack, 'findPlayersByName');
      return [];
    }
  }

  /// Create a new player
  Future<Person> createPlayer(Person player) async {
    ensureNotDemo('createPlayer'); // DEMO_GUARD
    try {
      // Computed fields stripped, tenantId set (shared with reactivation).
      final data = _personInsertData(player);

      final response = await supabase
          .from('player')
          .insert(data)
          .select()
          .single();

      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'createPlayer');
      rethrow;
    }
  }


  /// ASTRA_PHOTO: Ionic ImageService.updateImage – upload the picture to the
  /// `profiles` bucket under the bare player id (upsert) and store its plain
  /// public URL in `player.img`. Returns the public URL.
  Future<String> updateImage(int playerId, Uint8List bytes, {String? appId}) async {
    ensureNotDemo('updateImage'); // DEMO_GUARD
    try {
      final storagePath = profileImageStoragePath(playerId);
      await supabase.storage.from(SupabaseBuckets.profiles).uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      final publicUrl = supabase.storage
          .from(SupabaseBuckets.profiles)
          .getPublicUrl(storagePath);
      await supabase
          .from('player')
          .update({'img': publicUrl})
          .eq('id', playerId)
          .eq('tenantId', currentTenantId);
      await syncOwnImage(appId, publicUrl);
      return publicUrl;
    } catch (e, stack) {
      handleError(e, stack, 'updateImage');
      rethrow;
    }
  }

  /// Ionic `ImageService.updateImage` / `removeImage` with the own appId
  /// (`appId === currentUserId`): the picture is written to every player
  /// row of the account, i.e. in all instances. No-op for other persons.
  Future<void> syncOwnImage(String? appId, String img) async {
    final userId = supabase.auth.currentUser?.id;
    if (appId == null || appId.isEmpty || userId == null || appId != userId) return;
    await syncOwnPlayerImage(supabase, userId: userId, img: img);
  }

  /// Ionic 4.19.3 `ImageService.copyProfileImage`: copies a person's picture
  /// to another player row (handover). Pictures of the `profiles` bucket are
  /// duplicated to `profiles/<targetId>` so both rows own their file; other
  /// URLs are reused as they are. Default avatars, empty values and `data:`
  /// URLs are skipped. Returns the URL written to the target row, or null.
  Future<String?> copyProfileImage(
    String? sourceImg,
    int targetId, {
    required int targetTenantId,
  }) async {
    if (sourceImg == null ||
        sourceImg.isEmpty ||
        sourceImg.startsWith('data:') ||
        sourceImg == kDefaultPersonImage) {
      return null;
    }
    var url = sourceImg;
    const marker = '/storage/v1/object/public/profiles/';
    final markerIndex = sourceImg.indexOf(marker);
    if (markerIndex != -1) {
      final sourcePath = Uri.decodeComponent(
          sourceImg.substring(markerIndex + marker.length).split('?').first);
      final targetPath = profileImageStoragePath(targetId);
      if (sourcePath.isNotEmpty && sourcePath != targetPath) {
        final bucket = supabase.storage.from(SupabaseBuckets.profiles);
        try {
          await bucket.remove([targetPath]);
        } catch (_) {
          // Nothing stored under the new id yet.
        }
        try {
          await bucket.copy(sourcePath, targetPath);
          // Cache-bust in case an older picture with the same id was cached.
          url = '${bucket.getPublicUrl(targetPath)}?v=${DateTime.now().millisecondsSinceEpoch}';
        } catch (e) {
          debugPrint('copyProfileImage: storage copy failed, keeping URL: $e');
        }
      }
    }
    await supabase
        .from('player')
        .update({'img': url})
        .eq('id', targetId)
        .eq('tenantId', targetTenantId);
    return url;
  }

  /// DB_FIX: insert / reactivate payload like Ionic addPlayer:
  /// `pickPersonFields({...player, tenantId, id: Utils.getId()})`.
  ///
  /// Only whitelisted `player` columns are sent (Person.toJson also holds
  /// client-only keys such as `telegramId` → PGRST204). Null values are
  /// dropped: they correspond to Ionic's undefined form fields, which JSON
  /// serialisation omits, so DB defaults / existing values (e.g. `img` of a
  /// reactivated row) stay intact. `img` is not part of pickPersonFields; for
  /// a fresh insert a non-data URL (adopted picture of a cross-tenant match)
  /// is still sent, mirroring Ionic sanitizeImg (the reactivation in
  /// [addPlayer] drops it again).
  Map<String, dynamic> _personInsertData(Person player) {
    final data = pickPersonFields(player.toJson())
      ..remove('created_at')
      ..removeWhere((_, v) => v == null);
    data['id'] = generateIonicId();
    data['tenantId'] = currentTenantId;
    final img = player.img;
    if (img != null && img.isNotEmpty && !img.startsWith('data:')) {
      data['img'] = img;
    }
    return data;
  }

  /// Update an existing player
  Future<Person> updatePlayer(Person player) async {
    ensureNotDemo('updatePlayer'); // DEMO_GUARD
    if (player.id == null) {
      throw RepositoryException(
        message: 'Player ID is required for update',
        operation: 'updatePlayer',
      );
    }

    try {
      // DB_FIX: Ionic updatePlayer → update(pickPersonFields(player)) without
      // id / created_at (no img, no client-only keys like telegramId).
      // tenantId stays out of the body: the row is filtered by it.
      final data = pickPersonFields(player.toJson())
        ..remove('id')
        ..remove('created_at')
        ..remove('tenantId');

      final response = await supabase
          .from('player')
          .update(data)
          .eq('id', player.id!)
          .eq('tenantId', currentTenantId)
          .select()
          .maybeSingle();

      // RT-008: Handle case where player was not found
      if (response == null) {
        throw RepositoryException(
          message: 'Player not found or belongs to different tenant',
          operation: 'updatePlayer',
        );
      }

      return Person.fromJson(response);
    } catch (e, stack) {
      handleError(e, stack, 'updatePlayer');
      rethrow;
    }
  }

  /// Update arbitrary fields on a player row. Used by inline-edit pages
  /// where building a full Person object would be overkill (e.g. when
  /// the payload mixes top-level fields with JSON-column updates).
  ///
  /// Read-only fields (id, tenantId, created_at) are stripped from the
  /// input map before the update is sent.
  Future<void> updatePlayerFields(int id, Map<String, dynamic> updates) async {
    ensureNotDemo('updatePlayerFields'); // DEMO_GUARD
    try {
      updates.remove('id');
      updates.remove('tenantId');
      updates.remove('created_at');

      await supabase
          .from('player')
          .update(updates)
          .eq('id', id)
          .eq('tenantId', currentTenantId);
    } catch (e, stack) {
      handleError(e, stack, 'updatePlayerFields');
      rethrow;
    }
  }

  /// Registration repository bound to the current tenant.
  ///
  /// SOL_FIX1: own instance bound to this repository's tenant instead of
  /// mutating the shared registration repository.
  UserRegistrationRepository _registration() {
    return UserRegistrationRepository(ref)..bindTenantId(currentTenantId);
  }

  /// Main group (Hauptgruppe) of [tenantId] (default: current tenant).
  Future<int?> _mainGroupId({int? tenantId}) async {
    final row = await supabase
        .from('instruments')
        .select('id')
        .eq('tenantId', tenantId ?? currentTenantId)
        .eq('maingroup', true)
        .limit(1)
        .maybeSingle();
    return row?['id'] as int?;
  }

  /// E-mail of the signed-in user (Ionic `tenantUser().email`) for history
  /// entries like 'Person genehmigt von …'.
  String _actorEmail() {
    try {
      return supabase.auth.currentUser?.email ?? '';
    } catch (_) {
      return '';
    }
  }
}

/// [PlayerRepository.addPlayer] saved [person] but could not add it to the
/// Termine since its join date ([cause]).
class PersonNotAddedToAttendancesException implements Exception {
  PersonNotAddedToAttendancesException(this.person, this.cause);

  final Person person;
  final Object cause;

  @override
  String toString() => cause.toString();
}
