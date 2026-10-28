import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/person/person.dart';
import 'base_repository.dart';
import 'shared_person_fields.dart';
import '../../l10n/l10n.dart';

/// Provider for ProfileRepository
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref);
});

/// Ionic default placeholder image (DEFAULT_IMAGE in constants.ts).
const String kDefaultProfileImage =
    'https://ionicframework.com/docs/img/demos/avatar.svg';

/// Extra (additional) field definition as configured on the tenant or the
/// organisation (`tenants.additional_fields` / `tenant_groups.additional_fields`).
///
/// Parsed from raw JSON so that the player-visibility flags
/// (`visibleToPlayers`, `editableByPlayers`) are available.
class ProfileExtraField {
  const ProfileExtraField({
    required this.id,
    required this.name,
    required this.type,
    this.defaultValue,
    this.options = const [],
    this.visibleToPlayers = false,
    this.editableByPlayers = false,
    this.isOrganisationField = false,
  });

  final String id;
  final String name;
  final String type;
  final dynamic defaultValue;
  final List<String> options;
  final bool visibleToPlayers;
  final bool editableByPlayers;

  /// True when the field is defined on the organisation (shared across tenants).
  /// Values of such fields live in `tenant_group_person_fields`.
  final bool isOrganisationField;

  factory ProfileExtraField.fromJson(
    Map<String, dynamic> json, {
    bool isOrganisationField = false,
  }) {
    return ProfileExtraField(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      defaultValue: json['defaultValue'],
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      visibleToPlayers: json['visibleToPlayers'] == true,
      editableByPlayers: json['editableByPlayers'] == true,
      isOrganisationField: isOrganisationField,
    );
  }
}

/// Own profile ("Meine Stammdaten") of the logged-in user in the current tenant.
class OwnProfile {
  const OwnProfile({
    required this.person,
    this.globalPersonId,
    this.organisationId,
    this.additionalFields = const {},
  });

  /// The `player` row of the current user in the current tenant.
  final Person person;

  /// `player.global_person_id` (not part of the Person model).
  final String? globalPersonId;

  /// Organisation (tenant_group) of the current tenant, if linked.
  final int? organisationId;

  /// Tenant additional_fields merged with shared organisation values.
  final Map<String, dynamic> additionalFields;

  /// Ionic `getOrganisationPersonKey`: prefers the global person id.
  String? get organisationPersonKey {
    if (globalPersonId != null && globalPersonId!.isNotEmpty) {
      return 'global:$globalPersonId';
    }
    final appId = person.appId;
    if (appId != null && appId.isNotEmpty) return 'app:$appId';
    return null;
  }
}

/// Repository for the user's own profile data (Ionic ProfileService +
/// ImageService + settings page master data).
class ProfileRepository extends BaseRepository
    with TenantAwareRepository, SharedPersonFieldsRepository {
  ProfileRepository(super.ref);

  String get _userId {
    final id = supabase.auth.currentUser?.id;
    if (id == null) {
      throw RepositoryException(
        message: l10nWithoutContext.coreFlutterNotSignedIn,
        operation: 'profile',
      );
    }
    return id;
  }

  /// Load the own player profile for the current tenant (Ionic getPlayerProfile).
  Future<OwnProfile?> getOwnProfile() async {
    try {
      final userId = _userId;
      final response = await supabase
          .from('player')
          .select('*')
          .eq('tenantId', currentTenantId)
          .eq('appId', userId)
          .maybeSingle();

      if (response == null) return null;

      final person = Person.fromJson(response);
      final organisationId = await getOrganisationId();
      final profile = OwnProfile(
        person: person,
        globalPersonId: response['global_person_id']?.toString(),
        organisationId: organisationId,
        additionalFields:
            Map<String, dynamic>.from(person.additionalFields ?? const {}),
      );

      // Hydrate shared organisation values (Ionic hydrateSharedPersonFieldValues)
      final personKey = profile.organisationPersonKey;
      if (organisationId != null && personKey != null) {
        final shared = await getSharedFieldValues(organisationId, personKey);
        if (shared.isNotEmpty) {
          return OwnProfile(
            person: person,
            globalPersonId: profile.globalPersonId,
            organisationId: organisationId,
            additionalFields: {...profile.additionalFields, ...shared},
          );
        }
      }
      return profile;
    } catch (e, stack) {
      handleError(e, stack, 'getOwnProfile');
      rethrow;
    }
  }

  /// PARITY_B (I2): Ionic db.hydrateSharedPersonFieldValues — merges the
  /// shared organisation field values into `additional_fields`.
  Future<List<Person>> hydrateSharedPersonFieldValues(
    List<Person> players,
  ) async {
    return hydrateSharedPersonFieldValuesFor(
        await getOrganisationId(), players);
  }

  /// Organisation (tenant_group) id of the current tenant.
  Future<int?> getOrganisationId() async {
    try {
      final response = await supabase
          .from('tenant_group_tenants')
          .select('tenant_group')
          .eq('tenant_id', currentTenantId)
          .maybeSingle();
      return response?['tenant_group'] as int?;
    } catch (e, stack) {
      handleError(e, stack, 'getOrganisationId');
      rethrow;
    }
  }

  /// Person extra fields: organisation fields first, then tenant fields that
  /// are not overridden by the organisation (Ionic getPersonExtraFields).
  Future<List<ProfileExtraField>> getPersonExtraFields() async {
    try {
      final tenantRow = await supabase
          .from('tenants')
          .select('additional_fields')
          .eq('id', currentTenantId)
          .maybeSingle();

      final tenantFields = ((tenantRow?['additional_fields'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => ProfileExtraField.fromJson(e))
          .toList();

      final orgId = await getOrganisationId();
      var orgFields = <ProfileExtraField>[];
      if (orgId != null) {
        // tenant_groups has no tenantId column: scoped via the organisation id
        // of the current tenant (resolved through tenant_group_tenants above).
        final orgRow = await supabase
            .from('tenant_groups')
            .select('additional_fields')
            .eq('id', orgId)
            .maybeSingle();
        orgFields = ((orgRow?['additional_fields'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map((e) => ProfileExtraField.fromJson(e, isOrganisationField: true))
            .toList();
      }

      final orgIds = orgFields.map((f) => f.id).toSet();
      return [
        ...orgFields,
        ...tenantFields.where((f) => !orgIds.contains(f.id)),
      ];
    } catch (e, stack) {
      handleError(e, stack, 'getPersonExtraFields');
      rethrow;
    }
  }

  /// Shared organisation field values of one person.
  ///
  /// `tenant_group_person_fields` has no tenantId column: rows are scoped by
  /// the organisation id of the current tenant and the person key (RLS checks
  /// membership as well).
  Future<Map<String, dynamic>> getSharedFieldValues(
    int organisationId,
    String personKey,
  ) async {
    try {
      final response = await supabase
          .from('tenant_group_person_fields')
          .select('field_id, value')
          .eq('tenant_group', organisationId)
          .eq('person_key', personKey);

      return {
        for (final row in (response as List).cast<Map<String, dynamic>>())
          row['field_id'].toString(): row['value'],
      };
    } catch (e, stack) {
      handleError(e, stack, 'getSharedFieldValues');
      rethrow;
    }
  }

  /// Upsert shared organisation field values (Ionic updatePersonFieldValues).
  Future<void> updateSharedFieldValues(
    int organisationId,
    String personKey,
    Map<String, dynamic> values,
  ) async {
    ensureNotDemo('updateSharedFieldValues'); // DEMO_GUARD
    if (values.isEmpty) return;
    try {
      final rows = values.entries
          .map((e) => {
                'tenant_group': organisationId,
                'person_key': personKey,
                'field_id': e.key,
                'value': e.value,
              })
          .toList();
      await supabase
          .from('tenant_group_person_fields')
          .upsert(rows, onConflict: 'tenant_group,person_key,field_id');
    } catch (e, stack) {
      handleError(e, stack, 'updateSharedFieldValues');
      rethrow;
    }
  }

  /// Update the own profile (Ionic ProfileService.updateProfile).
  ///
  /// [personalData] (firstName, lastName, phone, birthday, img,
  /// correctBirthday) is personal data of the user and is synced to all own
  /// `player` rows (Ionic matches by appId). [additionalFields] are tenant
  /// specific and are only written to the current tenant's row.
  Future<void> updateOwnProfile({
    required Map<String, dynamic> personalData,
    Map<String, dynamic>? additionalFields,
    String? churchId,
  }) async {
    ensureNotDemo('updateOwnProfile'); // DEMO_GUARD
    try {
      final userId = _userId;

      // 1. Current tenant row incl. tenant-specific extra fields
      await supabase
          .from('player')
          .update({
            ...personalData,
            if (additionalFields != null) 'additional_fields': additionalFields,
          })
          .eq('tenantId', currentTenantId)
          .eq('appId', userId);

      // 2. Sync personal data to the user's own rows in other tenants.
      //    Scoped to appId == auth uid (own data only, enforced by RLS too).
      await _syncOwnPersonalData(userId, personalData);

      // 3. Church sync across own rows (Ionic: only if a church was set before)
      if (churchId != null) {
        await _syncOwnChurch(userId, churchId);
      }
    } catch (e, stack) {
      handleError(e, stack, 'updateOwnProfile');
      rethrow;
    }
  }

  Future<void> _syncOwnPersonalData(
    String userId,
    Map<String, dynamic> personalData,
  ) async {
    final rows = await supabase
        .from('player')
        .select('id, tenantId')
        .eq('appId', userId)
        .neq('tenantId', currentTenantId);
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      await supabase
          .from('player')
          .update(personalData)
          .eq('id', row['id'] as int)
          .eq('tenantId', row['tenantId'] as int)
          .eq('appId', userId);
    }
  }

  Future<void> _syncOwnChurch(String userId, String churchId) async {
    final rows = await supabase
        .from('player')
        .select('id, tenantId, additional_fields')
        .eq('appId', userId);
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final fields = Map<String, dynamic>.from(
          (row['additional_fields'] as Map?) ?? const {});
      final current = fields['bfecg_church'];
      if (current != null && current != '' && current != churchId) {
        fields['bfecg_church'] = churchId;
        await supabase
            .from('player')
            .update({'additional_fields': fields})
            .eq('id', row['id'] as int)
            .eq('tenantId', row['tenantId'] as int)
            .eq('appId', userId);
      }
    }
  }

  /// Upload a new Passbild (Ionic ImageService.updateImage with own appId).
  /// Returns the public URL.
  Future<String> uploadOwnImage({
    required int playerId,
    required Uint8List bytes,
    String? contentType,
  }) async {
    ensureNotDemo('uploadOwnImage'); // DEMO_GUARD
    try {
      final userId = _userId;
      final fileName = '$playerId';
      await supabase.storage.from('profiles').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );
      // PARITY_B (D7): store the bare public URL like Ionic updateImage —
      // Ionic removeImage derives the storage key from the URL, so a
      // cache-busting query would break deleting from Ionic. Busting happens
      // client-side only (ProfileNotifier.updateImage).
      final url = supabase.storage.from('profiles').getPublicUrl(fileName);

      await supabase
          .from('player')
          .update({'img': url})
          .eq('tenantId', currentTenantId)
          .eq('appId', userId);
      await _syncOwnPersonalData(userId, {'img': url});

      return url;
    } catch (e, stack) {
      handleError(e, stack, 'uploadOwnImage');
      rethrow;
    }
  }

  /// Remove the own Passbild (Ionic ImageService.removeImage with own appId).
  Future<void> removeOwnImage(String imgUrl) async {
    ensureNotDemo('removeOwnImage'); // DEMO_GUARD
    try {
      final userId = _userId;
      await supabase
          .from('player')
          .update({'img': ''})
          .eq('tenantId', currentTenantId)
          .eq('appId', userId);
      await _syncOwnPersonalData(userId, {'img': ''});

      final fileName = Uri.tryParse(imgUrl)?.pathSegments.lastOrNull;
      if (fileName != null && fileName.isNotEmpty) {
        await supabase.storage.from('profiles').remove([fileName]);
      }
    } catch (e, stack) {
      handleError(e, stack, 'removeOwnImage');
      rethrow;
    }
  }
}
