part of 'registration_providers.dart';

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

/// Model for registration form data.
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
    'birthday': hasBirthDate ? child.birthDate?.toIso8601String().split('T').first : null,
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
Person registrationBackfillPerson(Map<String, dynamic> storedRow) => Person.fromJson(storedRow);

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
    'birthday': hasBirthDate ? formData.birthDate?.toIso8601String().split('T').first : null,
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

/// Q3: a "Mein Kind" registration with an account that already has its own
/// role in the group (thrown before any child row is written).
class MemberParentRegistrationException extends AccountFlowException {
  const MemberParentRegistrationException(super.message);
}

/// Result of registration attempt.
class RegistrationResult {
  final bool success;
  final String? errorMessage;
  final bool isNewAccount;
  final bool autoApproved;
  final Role role;

  /// Number of children of a parent registration (0: self registration).
  final int children;

  /// Q3: "Mein Kind" with an account that is already a member of the group;
  /// [errorMessage] explains it and nothing was saved.
  final bool memberBlocked;

  const RegistrationResult._({
    required this.success,
    this.errorMessage,
    this.memberBlocked = false,
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
  String get successMessage =>
      children > 0
          ? (isNewAccount
              ? l10nWithoutContext.parentRegisterSuccessNewPending
              : l10nWithoutContext.parentRegisterSuccessPending)
          : successMessageFor(autoApproved: autoApproved, isNewAccount: isNewAccount);

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

  factory RegistrationResult.error(String message, {bool memberBlocked = false}) {
    return RegistrationResult._(
      success: false,
      errorMessage: message,
      memberBlocked: memberBlocked,
    );
  }
}
