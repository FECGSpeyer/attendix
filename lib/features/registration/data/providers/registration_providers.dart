import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/table_names.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/db_helpers.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../data/repositories/player_repository.dart';
import '../../../../data/repositories/user_registration_repository.dart';
import '../../../auth/data/auth_flow_service.dart';
import '../../../../l10n/l10n.dart';

/// Provider for loading a tenant by its register ID
final tenantByRegisterIdProvider = FutureProvider.family<Tenant?, String>((ref, registerId) async {
  final supabase = ref.watch(supabaseClientProvider);

  final response = await supabase
      .from('tenants')
      .select('*')
      .eq('register_id', registerId)
      .maybeSingle();

  if (response == null) return null;
  return Tenant.fromJson(response);
});

/// Provider for loading groups for a tenant
final registrationGroupsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, tenantId) async {
  final supabase = ref.watch(supabaseClientProvider);

  final response = await supabase
      .from('instruments')
      .select('id, name')
      .eq('tenantId', tenantId)
      .eq('maingroup', false)
      .order('name');

  return (response as List).map((g) => {
    'id': g['id'] as int,
    'name': g['name'] as String,
  }).toList();
});

/// Model for registration form data
class RegistrationFormData {
  String email;
  String password;
  String confirmPassword;
  String firstName;
  String lastName;
  int? groupId;
  String? phone;
  DateTime? birthDate;
  String? notes;
  Map<String, dynamic> additionalFields;
  Uint8List? profileImageBytes;

  RegistrationFormData({
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.firstName = '',
    this.lastName = '',
    this.groupId,
    this.phone,
    this.birthDate,
    this.notes,
    Map<String, dynamic>? additionalFields,
    this.profileImageBytes,
  }) : additionalFields = additionalFields ?? {};
}

/// Registration service for handling the registration process
/// (Ionic tenant-register.page.ts register() → db.addPlayer).
class RegistrationService {
  RegistrationService(this._ref);

  final Ref _ref;

  SupabaseClient get supabase => _ref.read(supabaseClientProvider);

  /// Fresh registration repository scoped to [tenantId] (the registration
  /// tenant is usually not the app's current tenant).
  UserRegistrationRepository _registrationRepo(int tenantId) =>
      UserRegistrationRepository(_ref)..setTenantId(tenantId);

  /// Register the current (or a new) user for [tenant].
  ///
  /// * not signed in → password sign-up (Ionic db.register); an existing
  ///   account with the same password is signed in instead
  /// * signed in (password login or e-mail code) → registerUser with
  ///   `self_register` (no inform mail)
  Future<RegistrationResult> register({
    required Tenant tenant,
    required RegistrationFormData formData,
    bool otpMode = false,
  }) async {
    final tenantId = tenant.id!;
    final role =
        tenant.autoApproveRegistrations ? Role.player : Role.applicant;
    final registration = _registrationRepo(tenantId);
    final currentUser = supabase.auth.currentUser;
    final email = (currentUser?.email ?? formData.email).toLowerCase().trim();

    String userId;
    var created = false;
    try {
      if (currentUser == null) {
        final AuthResponse signUp;
        try {
          signUp = await supabase.auth.signUp(
            email: email,
            password: formData.password,
            emailRedirectTo: '${authRedirectBase()}/login',
            data: {
              AccountRepository.termsAcceptedAtKey:
                  DateTime.now().toUtc().toIso8601String(),
            },
          );
        } catch (_) {
          return RegistrationResult.error(
              '${l10nWithoutContext.dbCreateAccountFailed}: ${l10nWithoutContext.dbRegisterFailed}');
        }
        final user = signUp.user;
        if (user == null) {
          return RegistrationResult.error(
              '${l10nWithoutContext.dbCreateAccountFailed}: ${l10nWithoutContext.dbRegisterFailed}');
        }
        if (user.identities?.isEmpty ?? true) {
          // E-mail already registered → try to sign in with the password.
          try {
            final login = await supabase.auth.signInWithPassword(
              email: email,
              password: formData.password,
            );
            if (login.user == null) throw const AuthException('no user');
          } catch (_) {
            return RegistrationResult.error(
              '${l10nWithoutContext.dbCreateAccountFailed}: ${l10nWithoutContext.dbEmailExists}',
            );
          }
          // Existing account: go through registerUser so an existing
          // membership raises "bereits in diesem Mandanten" instead of
          // creating a duplicate tenantUsers row.
          userId = await registration.registerUser(
            email: email,
            name: formData.firstName,
            role: role,
            tenantId: tenantId,
            selfRegister: true,
          );
        } else {
          userId = user.id;
          created = true;
          await registration.addUserToTenant(userId, role, email,
              tenantId: tenantId);
        }
      } else {
        userId = await registration.registerUser(
          email: email,
          name: formData.firstName,
          role: role,
          tenantId: tenantId,
          selfRegister: true,
        );
      }

      final pending = !tenant.autoApproveRegistrations;
      final today = DateTime.now();
      final todayIso =
          DateTime.utc(today.year, today.month, today.day).toIso8601String();
      final registrationFields = tenant.registrationFields ?? const [];
      final hasBirthDate = registrationFields.contains('birthDate');
      final phone = formData.phone?.replaceAll(RegExp(r'\s+'), '');

      final playerData = buildRegistrationPlayerData(
        tenantId: tenantId,
        appId: userId,
        formData: formData,
        email: email,
        pending: pending,
        hasBirthDate: hasBirthDate,
        phone: phone,
        todayIso: todayIso,
      );

      // Ionic addPlayer: reactivate a former (left) row instead of
      // inserting a duplicate. Active rows are never overwritten.
      final existing = await supabase
          .from('player')
          .select('id, left')
          .eq('appId', userId)
          .eq('tenantId', tenantId)
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle();

      final int playerId;
      if (existing != null) {
        if (existing['left'] == null) {
          return RegistrationResult.error(
              l10nWithoutContext.dbUserAlreadyInTenant);
        }
        playerId = existing['id'] as int;
        await supabase
            .from('player')
            .update(reactivationPlayerData(playerData))
            .eq('id', playerId)
            .eq('tenantId', tenantId);
      } else {
        final playerResponse = await supabase
            .from('player')
            // DB_FIX: Ionic addPlayer sets the id client-side (Utils.getId)
            .insert({...playerData, 'id': generateIonicId()})
            .select('id')
            .single();
        playerId = playerResponse['id'] as int;
      }

      // Upload profile image if provided
      if (formData.profileImageBytes != null) {
        try {
          final storagePath = '$tenantId/$playerId.jpg';
          await supabase.storage.from(SupabaseBuckets.profiles).uploadBinary(
                storagePath,
                formData.profileImageBytes!,
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
              .eq('tenantId', tenantId);
        } catch (e, stack) {
          // Log but don't block registration
          debugPrint('Profile image upload failed: $e\n$stack');
        }
      }

      // Ionic addPlayer: addPlayerToAttendancesByDate(data) with the
      // inserted / reactivated row when not pending. Re-read the stored row
      // so the type filters see the registrant's real `additional_fields`
      // (and `joined`, which a reactivation keeps).
      if (!pending) {
        try {
          final storedRow = await supabase
              .from('player')
              .select('*')
              .eq('id', playerId)
              .eq('tenantId', tenantId)
              .single();
          final playerRepo = PlayerRepository(_ref)..setTenantId(tenantId);
          await playerRepo
              .addPlayerToAttendancesByDate(registrationBackfillPerson(storedRow));
        } catch (e) {
          debugPrint('Attendance backfill failed: $e');
        }
      }

      return RegistrationResult.success(
        // A new account only needs e-mail confirmation when it was created
        // with a password (OTP already verified the e-mail).
        isNewAccount: created && !otpMode,
        autoApproved: tenant.autoApproveRegistrations,
        role: role,
      );
    } on AccountFlowException catch (e) {
      return RegistrationResult.error(e.message);
    } catch (e) {
      debugPrint('Registration failed: $e');
      return RegistrationResult.error(
          l10nWithoutContext.tenantRegisterFlutterRegisterFailedRetry);
    }
  }
}

/// Person used for the attendance backfill after a self registration:
/// the stored player row (Ionic passes the inserted/updated `data`).
Person registrationBackfillPerson(Map<String, dynamic> storedRow) =>
    Person.fromJson(storedRow);

/// Fields written when a former (left) member registers again: keeps the
/// existing `history`, `joined` and `playsSince` (Ionic reactivation).
Map<String, dynamic> reactivationPlayerData(Map<String, dynamic> playerData) {
  return {
    ...Map<String, dynamic>.of(playerData)
      ..remove('history')
      ..remove('joined')
      ..remove('playsSince'),
    'left': null,
  };
}

/// Player row for a self registration (Ionic tenant-register addPlayer).
Map<String, dynamic> buildRegistrationPlayerData({
  required int tenantId,
  required String appId,
  required RegistrationFormData formData,
  required String email,
  required bool pending,
  required bool hasBirthDate,
  required String? phone,
  required String todayIso,
}) {
  return {
    'appId': appId,
    'tenantId': tenantId,
    'firstName': formData.firstName,
    'lastName': formData.lastName,
    'email': email.isNotEmpty ? email : null,
    'phone': phone ?? '',
    'birthday': hasBirthDate
        ? formData.birthDate?.toIso8601String().split('T').first
        : null,
    'correctBirthday': hasBirthDate,
    'instrument': formData.groupId,
    'notes': formData.notes ?? '',
    'pending': pending,
    'self_register': true,
    'hasTeacher': false,
    'isCritical': false,
    'isLeader': false,
    'history': <dynamic>[],
    'playsSince': todayIso,
    'joined': todayIso,
    'additional_fields': formData.additionalFields,
  };
}

/// Result of registration attempt
class RegistrationResult {
  final bool success;
  final String? errorMessage;
  final bool isNewAccount;
  final bool autoApproved;
  final Role role;

  const RegistrationResult._({
    required this.success,
    this.errorMessage,
    this.isNewAccount = false,
    this.autoApproved = false,
    this.role = Role.applicant,
  });

  factory RegistrationResult.success({
    bool isNewAccount = false,
    bool autoApproved = false,
    Role role = Role.applicant,
  }) {
    return RegistrationResult._(
      success: true,
      isNewAccount: isNewAccount,
      autoApproved: autoApproved,
      role: role,
    );
  }

  /// Ionic tenantRegister.success.* texts.
  String get successMessage => successMessageFor(
      autoApproved: autoApproved, isNewAccount: isNewAccount);

  static String successMessageFor({
    required bool autoApproved,
    required bool isNewAccount,
  }) {
    if (autoApproved) {
      return isNewAccount
          ? l10nWithoutContext.tenantRegisterSuccessNewConfirm
          : l10nWithoutContext.tenantRegisterSuccessJoined;
    }
    return isNewAccount
        ? l10nWithoutContext.tenantRegisterSuccessNewPending
        : l10nWithoutContext.tenantRegisterSuccessPending;
  }

  factory RegistrationResult.error(String message) {
    return RegistrationResult._(
      success: false,
      errorMessage: message,
    );
  }
}

/// Provider for registration service
final registrationServiceProvider = Provider<RegistrationService>((ref) {
  return RegistrationService(ref);
});
