import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/table_names.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/utils/db_helpers.dart';
import '../../../../core/utils/parent_registration.dart';
import '../../../../core/utils/profile_image_path.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../data/repositories/player_repository.dart';
import '../../../../data/repositories/profile_repository.dart' show syncOwnPlayerImage;
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

/// Provider for loading groups for a tenant (Ionic GroupService.getGroups:
/// category, sort_order (nulls last), name; then `maingroup !== true`, so
/// groups without a maingroup value stay in the list).
final registrationGroupsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, tenantId) async {
  final supabase = ref.watch(supabaseClientProvider);

  final response = await supabase
      .from('instruments')
      .select('id, name, maingroup')
      .eq('tenantId', tenantId)
      .order('category', ascending: true)
      .order('sort_order', ascending: true)
      .order('name', ascending: true);

  return (response as List)
      .where((g) => g['maingroup'] != true)
      .map((g) => {
            'id': g['id'] as int,
            'name': g['name'] as String,
          })
      .toList();
});

/// Ionic tenant-register ngOnInit: the extra fields of the registration in
/// the order of `registration_fields`.
List<ExtraField> orderedRegistrationFields(
  List<String> registrationFields,
  List<ExtraField> additionalFields,
) {
  final fields = <ExtraField>[];
  for (final id in registrationFields) {
    final field = additionalFields.where((f) => f.id == id).firstOrNull;
    if (field != null) fields.add(field);
  }
  return fields;
}

/// Ionic ion-input type=number (NumericValueAccessor parseFloat): the entered
/// number, whole numbers as int. Accepts a decimal comma (German keyboards).
/// `null` when the input is not a finite number.
num? parseRegistrationNumber(String input) {
  final parsed = double.tryParse(input.trim().replaceAll(',', '.'));
  if (parsed == null || !parsed.isFinite) return null;
  if (parsed == parsed.truncateToDouble() && parsed.abs() <= 9007199254740991) {
    return parsed.toInt();
  }
  return parsed;
}

/// Ionic tenant-register ngOnInit: every registration field starts with its
/// `defaultValue` (church: none) and register() stores each field value in
/// `additional_fields`, so an untouched select keeps its default.
Map<String, dynamic> registrationFieldDefaults(
  List<String> registrationFields,
  List<ExtraField> additionalFields,
) {
  return {
    for (final field
        in orderedRegistrationFields(registrationFields, additionalFields))
      if (field.id != 'bfecg_church' && field.defaultValue != null)
        field.id: field.defaultValue,
  };
}

/// One child in a parent registration ("Mein Kind").
class ChildRegistrationData {
  ChildRegistrationData({
    this.firstName = '',
    this.lastName = '',
    this.groupId,
    this.birthDate,
  });

  String firstName;
  String lastName;
  int? groupId;
  DateTime? birthDate;
}

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

  /// Content type of [profileImageBytes] (as picked, not re-encoded).
  String? profileImageMimeType;

  /// "Mein Kind": an Elternteil registers [children]; [firstName] /
  /// [lastName] / [phone] are then the parent's own.
  bool forChildren = false;
  final List<ChildRegistrationData> children = [ChildRegistrationData()];

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
      UserRegistrationRepository(_ref)..bindTenantId(tenantId);

  /// Register the current (or a new) user for [tenant].
  ///
  /// * not signed in → password sign-up (Ionic db.register); an existing
  ///   account with the same password is signed in instead
  /// * signed in (password login or e-mail code) → registerUser with
  ///   `self_register` (no inform mail)
  /// "Mein Kind": an Elternteil registers one or more children. The
  /// parent's account gets access as applicant (if it has none yet) and
  /// each child becomes a pending person with the parent marker. The lead
  /// approves each child in Freigaben; that makes the account an Elternteil
  /// (see PlayerNotifier.approvePlayer). Always pending, also with
  /// auto-approve, because only a lead may create the Elternteil.
  Future<RegistrationResult> registerChildren({
    required Tenant tenant,
    required RegistrationFormData formData,
    bool otpMode = false,
  }) async {
    final tenantId = tenant.id!;
    final email = (supabase.auth.currentUser?.email ?? formData.email)
        .toLowerCase()
        .trim();
    try {
      final (userId, created) = await _parentAccount(tenant, formData, email);
      final today = DateTime.now();
      final todayIso =
          DateTime.utc(today.year, today.month, today.day).toIso8601String();
      final hasBirthDate =
          (tenant.registrationFields ?? const []).contains('birthDate');
      // One insert for all children: either all are saved or none (a retry
      // then never duplicates a child).
      await supabase.from('player').insert([
        for (final child in formData.children)
          {
            ...buildChildRegistrationPlayerData(
              tenantId: tenantId,
              parentAppId: userId,
              formData: formData,
              child: child,
              parentEmail: email,
              hasBirthDate: hasBirthDate,
              todayIso: todayIso,
            ),
            'id': generateIonicId(),
          },
      ]);
      return RegistrationResult.success(
        isNewAccount: created && !otpMode,
        role: Role.applicant,
        children: formData.children.length,
      );
    } on AccountFlowException catch (e) {
      return RegistrationResult.error(e.message);
    } catch (e) {
      debugPrint('Child registration failed: $e');
      return RegistrationResult.error(
          l10nWithoutContext.tenantRegisterFlutterRegisterFailedRetry);
    }
  }

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

      // Ionic addPlayer (db.service.ts): if the user already has a player
      // row in this tenant (e.g. previously left), overwrite it with the new
      // registration data and `left: null` instead of inserting a duplicate.
      // PARITY_A (D3): like Ionic, this applies to any existing row (active
      // ones too); registerUser already rejects users still in the tenant.
      final existing = await supabase
          .from('player')
          .select('id')
          .eq('appId', userId)
          .eq('tenantId', tenantId)
          .limit(1)
          .maybeSingle();

      final int playerId;
      if (existing != null) {
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
          // DB_REVIEW_REST (M4): Ionic updateImage key `<id>`.
          final storagePath = profileImageStoragePath(playerId);
          await supabase.storage.from(SupabaseBuckets.profiles).uploadBinary(
                storagePath,
                formData.profileImageBytes!,
                fileOptions: FileOptions(
                  contentType: formData.profileImageMimeType ?? 'image/jpeg',
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
          // Ionic tenant-register: updateImage with the signed-in account →
          // the picture goes to all of its instances.
          if (supabase.auth.currentUser?.id == userId) {
            await syncOwnPlayerImage(supabase, userId: userId, img: publicUrl);
          }
        } catch (e, stack) {
          // Log but don't block registration
          debugPrint('Profile image upload failed: $e\n$stack');
        }
      }

      // Ionic addPlayer: addPlayerToAttendancesByDate(data) with the
      // inserted / reactivated row when not pending. Re-read the stored row
      // so the type filters see the registrant's real `additional_fields`
      // (and `joined`).
      if (!pending) {
        try {
          final storedRow = await supabase
              .from('player')
              .select('*')
              .eq('id', playerId)
              .eq('tenantId', tenantId)
              .single();
          final playerRepo = PlayerRepository(_ref)..bindTenantId(tenantId);
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

/// Account step of a parent registration: the signed-in / new / existing
/// account of the Elternteil gets access to [tenantId] as applicant unless
/// it already has a role there (e.g. a parent adding another child later).
extension _ParentAccount on RegistrationService {
  Future<(String, bool)> _parentAccount(
      Tenant tenant, RegistrationFormData formData, String email) async {
    final tenantId = tenant.id!;
    final registration = _registrationRepo(tenantId);
    final currentUser = supabase.auth.currentUser;
    String userId;
    var created = false;
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
        throw AccountFlowException(
            '${l10nWithoutContext.dbCreateAccountFailed}: ${l10nWithoutContext.dbRegisterFailed}');
      }
      final user = signUp.user;
      if (user == null) {
        throw AccountFlowException(
            '${l10nWithoutContext.dbCreateAccountFailed}: ${l10nWithoutContext.dbRegisterFailed}');
      }
      if (user.identities?.isEmpty ?? true) {
        // E-mail already registered → sign in with the password.
        try {
          final login = await supabase.auth.signInWithPassword(
            email: email,
            password: formData.password,
          );
          if (login.user == null) throw const AuthException('no user');
          userId = login.user!.id;
        } catch (_) {
          throw AccountFlowException(
            '${l10nWithoutContext.dbCreateAccountFailed}: ${l10nWithoutContext.dbEmailExists}',
          );
        }
      } else {
        userId = user.id;
        created = true;
      }
    } else {
      userId = currentUser.id;
    }
    final role = created
        ? null
        : await registration.getTenantUserRole(userId, tenantId: tenantId);
    if (role == null) {
      await registration.addUserToTenant(userId, Role.applicant, email,
          tenantId: tenantId);
    }
    return (userId, created);
  }
}

/// Player row of one child in a parent registration: the shared form data
/// with the child's name / group / birth date, always pending (the lead
/// approves the parent with the child), no `appId` (the child is not the
/// parent's own person) and the parent marker with the parent's account
/// (see [kParentRegistrationKey]).
Map<String, dynamic> buildChildRegistrationPlayerData({
  required int tenantId,
  required String parentAppId,
  required RegistrationFormData formData,
  required ChildRegistrationData child,
  required String parentEmail,
  required bool hasBirthDate,
  required String todayIso,
}) {
  final data = buildRegistrationPlayerData(
    tenantId: tenantId,
    appId: parentAppId,
    formData: formData,
    email: parentEmail,
    pending: true,
    hasBirthDate: hasBirthDate,
    phone: formData.phone?.replaceAll(RegExp(r'\s+'), ''),
    todayIso: todayIso,
  );
  return {
    ...data,
    'firstName': child.firstName.trim(),
    'lastName': child.lastName.trim(),
    'instrument': child.groupId,
    'birthday': hasBirthDate
        ? child.birthDate?.toIso8601String().split('T').first
        : null,
    'appId': null,
    'img': kDefaultAvatarUrl,
    'additional_fields': {
      ...formData.additionalFields,
      kParentRegistrationKey: ParentRegistration(
        appId: parentAppId,
        firstName: formData.firstName.trim(),
        lastName: formData.lastName.trim(),
        email: parentEmail,
      ).toJson(),
    },
  };
}

/// Person used for the attendance backfill after a self registration:
/// the stored player row (Ionic passes the inserted/updated `data`).
Person registrationBackfillPerson(Map<String, dynamic> storedRow) =>
    Person.fromJson(storedRow);

/// Fields written when a user with an existing player row registers again
/// (Ionic addPlayer reactivation): the complete new registration data
/// (incl. `history: []`, `joined`, `playsSince`) plus `left: null`.
Map<String, dynamic> reactivationPlayerData(Map<String, dynamic> playerData) {
  return {
    ...Map<String, dynamic>.of(playerData)..remove('id'),
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
    // Ionic addPlayer: without a picture the row gets DEFAULT_IMAGE; a chosen
    // picture is uploaded afterwards and sets `img` then.
    if (formData.profileImageBytes == null) 'img': kDefaultAvatarUrl,
  };
}

/// Result of registration attempt
class RegistrationResult {
  final bool success;
  final String? errorMessage;
  final bool isNewAccount;
  final bool autoApproved;
  final Role role;

  /// Number of children of a parent registration (0: self registration).
  final int children;

  const RegistrationResult._({
    required this.success,
    this.errorMessage,
    this.isNewAccount = false,
    this.autoApproved = false,
    this.role = Role.applicant,
    this.children = 0,
  });

  factory RegistrationResult.success({
    bool isNewAccount = false,
    bool autoApproved = false,
    Role role = Role.applicant,
    int children = 0,
  }) {
    return RegistrationResult._(
      success: true,
      isNewAccount: isNewAccount,
      autoApproved: autoApproved,
      role: role,
      children: children,
    );
  }

  /// Ionic tenantRegister.success.* texts (parent registration: its own).
  String get successMessage => children > 0
      ? (isNewAccount
          ? l10nWithoutContext.parentRegisterSuccessNewPending
          : l10nWithoutContext.parentRegisterSuccessPending)
      : successMessageFor(
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
