import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/profile_repository.dart';
import 'player_providers.dart';
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
final profileRepositoryForTenantProvider =
    Provider.family<ProfileRepository, int?>((ref, tenantId) {
  final repo = ProfileRepository(ref);
  if (tenantId != null) repo.bindTenantId(tenantId);
  return repo;
});

/// Own player profile in the current tenant ("Meine Stammdaten")
final ownProfileProvider = FutureProvider<OwnProfile?>((ref) async {
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
    state = const AsyncValue.loading();
    try {
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
        await _repo.updateSharedFieldValues(orgId, personKey, sharedValues);
      }

      await _repo.updateOwnProfile(
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
    state = const AsyncValue.loading();
    try {
      final url = await _repo.uploadOwnImage(
        playerId: playerId,
        bytes: bytes,
        contentType: contentType,
      );
      state = const AsyncValue.data(null);
      _invalidate();
      return url;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Remove the own Passbild
  Future<bool> removeImage(String imgUrl) async {
    state = const AsyncValue.loading();
    try {
      await _repo.removeOwnImage(imgUrl);
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
