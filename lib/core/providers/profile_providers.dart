import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tenant/tenant.dart';
import '../config/supabase_config.dart';
import '../services/offline_queue_service.dart' show OfflineWriteSession;
import '../../data/repositories/attendance_repository.dart'
    show OfflineSessionChangedException;
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/shared_person_fields.dart';
import 'organisation_providers.dart';
import 'player_providers.dart';
import 'realtime_providers.dart';
import 'tenant_providers.dart';

/// Profile repository with tenant context
final profileRepositoryWithTenantProvider = Provider<ProfileRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(profileRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [ProfileRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final profileRepositoryForTenantProvider =
    Provider.family<ProfileRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _profileRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _profileRepositoryForAccountProvider =
    Provider.family<ProfileRepository, AccountScopeKey>((ref, key) {
  final repo = ProfileRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
  return repo;
});

/// Own player profile in the current tenant ("Meine Stammdaten")
final ownProfileProvider = FutureProvider<OwnProfile?>((ref) async {
  // SOL_FIX14: per-user data – reload when the account changes.
  if (ref.watch(currentAuthUserIdProvider) == null) return null;
  final repo = ref.watch(profileRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  return repo.getOwnProfile();
});

/// All person extra fields (organisation + tenant)
final personExtraFieldsProvider =
    FutureProvider<List<ProfileExtraField>>((ref) async {
  final repo = ref.watch(profileRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getPersonExtraFields();
});

// PARITY_B (I2) --------------------------------------------------------------

/// Ionic getPersonExtraFields as [ExtraField]s: organisation fields first,
/// then the tenant fields not overridden by the organisation.
final personListExtraFieldsProvider = Provider<List<ExtraField>>((ref) {
  final tenantFields =
      ref.watch(currentTenantProvider)?.additionalFields ?? const <ExtraField>[];
  final orgFields = [
    for (final f in ref.watch(currentOrganisationProvider).valueOrNull
            ?.additionalFields ??
        const [])
      ExtraField(
        id: f.id,
        name: f.name,
        type: f.type,
        defaultValue: f.defaultValue,
        options: f.options,
        visibleToPlayers: f.visibleToPlayers,
        editableByPlayers: f.editableByPlayers,
        displayMode: f.displayMode,
      ),
  ];
  if (orgFields.isEmpty) return tenantFields;
  final orgIds = orgFields.map((f) => f.id).toSet();
  return [
    ...orgFields,
    ...tenantFields.where((f) => !orgIds.contains(f.id)),
  ];
});

/// Shared organisation field values of all people in the list, keyed by
/// person key (Ionic list.page getPlayers → hydrateSharedPersonFieldValues).
final sharedPersonFieldValuesProvider =
    FutureProvider.autoDispose<Map<String, Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(profileRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return const {};
  final people = await ref.watch(realtimePlayersProvider.future);
  final orgId = await repo.getOrganisationId();
  if (orgId == null) return const {};
  final keys =
      people.map(organisationPersonKeyOf).whereType<String>().toSet().toList();
  return repo.getSharedFieldValuesForPeople(orgId, keys);
});

/// Extra fields visible to players (Ionic getVisibleExtraFields)
final visibleProfileExtraFieldsProvider =
    Provider<List<ProfileExtraField>>((ref) {
  final fields = ref.watch(personExtraFieldsProvider).valueOrNull ?? [];
  return fields.where((f) => f.visibleToPlayers).toList();
});

/// Mutations on the own profile
class ProfileNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  ProfileRepository get _repo => ref.read(profileRepositoryWithTenantProvider);

  void _invalidate() {
    ref.invalidate(ownProfileProvider);
    ref.invalidate(playersProvider);
  }

  /// SOL_FIX15: captures the signed-in account + auth session (and tenant)
  /// synchronously, before the flow's first await. Throws when nobody is
  /// signed in or [ownerAppId] (the profile shown in the form) belongs to
  /// another account.
  ({String userId, bool Function() isCurrent}) _captureSession({
    String? ownerAppId,
  }) {
    final session = OfflineWriteSession.capture(ref);
    final userId = session.userId;
    if (userId == null || (ownerAppId != null && ownerAppId != userId)) {
      throw const OfflineSessionChangedException();
    }
    return (userId: userId, isCurrent: session.isCurrent);
  }

  /// Save "Meine Stammdaten" (Ionic settings.page updateUserData)
  Future<bool> saveMasterData({
    required OwnProfile original,
    required String firstName,
    required String lastName,
    required String phone,
    required String? birthday,
    required Map<String, dynamic> additionalFields,
    required List<ProfileExtraField> visibleFields,
  }) async {
    final repo = _repo; // SOL_FIX4: bind the tenant repository before the first await.
    state = const AsyncValue.loading();
    try {
      // SOL_FIX15: account + session of this save, captured before any
      // await and checked again right before every write.
      final session = _captureSession(ownerAppId: original.person.appId);
      final oldFields = original.person.additionalFields ?? const {};

      // Church sync only if it changed (Ionic churchId logic)
      String? churchId;
      if (additionalFields['bfecg_church'] != original.additionalFields['bfecg_church']) {
        churchId = additionalFields['bfecg_church']?.toString();
      }

      final editable = visibleFields.where((f) => f.editableByPlayers);
      final tenantFields = Map<String, dynamic>.from(oldFields);
      final sharedValues = <String, dynamic>{};
      for (final field in editable) {
        if (field.isOrganisationField) {
          sharedValues[field.id] = additionalFields[field.id];
          tenantFields.remove(field.id);
        } else {
          tenantFields[field.id] = additionalFields[field.id];
        }
      }

      final orgId = original.organisationId;
      final personKey = original.organisationPersonKey;
      if (orgId != null && personKey != null && sharedValues.isNotEmpty) {
        await repo.updateSharedFieldValues(
          orgId,
          personKey,
          sharedValues,
          isSessionCurrent: session.isCurrent,
        );
      }

      await repo.updateOwnProfile(
        userId: session.userId,
        isSessionCurrent: session.isCurrent,
        personalData: {
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'phone': phone.trim(),
          'birthday': birthday,
          // Only confirm the birthday when the user actually changed it
          if (birthday != original.person.birthday) 'correctBirthday': true,
        },
        additionalFields: tenantFields,
        churchId: churchId,
      );

      state = const AsyncValue.data(null);
      _invalidate();
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Replace the own Passbild
  Future<String?> updateImage({
    required int playerId,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final repo = _repo;
    state = const AsyncValue.loading();
    try {
      final session = _captureSession();
      final url = await repo.uploadOwnImage(
        userId: session.userId,
        isSessionCurrent: session.isCurrent,
        playerId: playerId,
        bytes: bytes,
        contentType: contentType,
      );
      state = const AsyncValue.data(null);
      // PARITY_B (D7): the DB keeps the bare URL (same as before the upload),
      // so drop the cached old image and return a cache-busted URL for the
      // immediate preview only.
      try {
        await CachedNetworkImage.evictFromCache(url);
      } catch (_) {}
      _invalidate();
      return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Remove the own Passbild
  Future<bool> removeImage(String imgUrl) async {
    final repo = _repo;
    state = const AsyncValue.loading();
    try {
      final session = _captureSession();
      await repo.removeOwnImage(
        imgUrl,
        userId: session.userId,
        isSessionCurrent: session.isCurrent,
      );
      state = const AsyncValue.data(null);
      _invalidate();
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final profileNotifierProvider =
    NotifierProvider<ProfileNotifier, AsyncValue<void>>(ProfileNotifier.new);
