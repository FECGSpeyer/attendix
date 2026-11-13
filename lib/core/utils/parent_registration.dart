import '../../data/models/person/person.dart';
import '../constants/enums.dart';

/// Key in `player.additional_fields` that marks a child that an Elternteil
/// registered via the register link ("Mein Kind").
///
/// The child row never carries the parent's account as `appId` (that would
/// make it the parent's own person: profile sync, login). Until a lead
/// approves it, it carries this marker with the parent's account id, name
/// and e-mail. On approval the parent becomes an Elternteil (parents row,
/// role parent, `tenantUsers.parent_id`), then the child gets `parent_id`
/// and loses e-mail and marker, so a failed step can simply be retried. No
/// DB schema change is needed for this.
const String kParentRegistrationKey = '_parent_registration';

/// The Elternteil who registered a child via the register link.
class ParentRegistration {
  const ParentRegistration({
    required this.appId,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  /// Auth user id of the parent's account.
  final String appId;
  final String firstName;
  final String lastName;
  final String email;

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() => {
        'appId': appId,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
      };

  /// Reads the marker from `additional_fields`; null when it is missing or
  /// malformed.
  static ParentRegistration? fromAdditionalFields(Map<String, dynamic>? fields) {
    final raw = fields?[kParentRegistrationKey];
    if (raw is! Map) return null;
    final email = raw['email'];
    final appId = raw['appId'];
    if (email is! String || email.trim().isEmpty) return null;
    if (appId is! String || appId.isEmpty) return null;
    return ParentRegistration(
      appId: appId,
      firstName: (raw['firstName'] as String?)?.trim() ?? '',
      lastName: (raw['lastName'] as String?)?.trim() ?? '',
      email: email.trim(),
    );
  }
}

/// The parent marker of [person] (a pending child), or null.
ParentRegistration? parentRegistrationOf(Person person) =>
    ParentRegistration.fromAdditionalFields(person.additionalFields);

/// [fields] without the parent marker (written on approval).
Map<String, dynamic> withoutParentRegistration(Map<String, dynamic>? fields) =>
    {...?fields}..remove(kParentRegistrationKey);

/// Columns written together with `pending: false` when a child of a parent
/// registration is approved: it belongs to the Elternteil [parentId], the
/// parent's e-mail and the marker go.
Map<String, dynamic> childApprovalFields(int parentId, Map<String, dynamic>? fields) => {
      'parent_id': parentId,
      'appId': null,
      'email': null,
      'additional_fields': withoutParentRegistration(fields),
    };

/// Q3: the account behind a "Mein Kind" registration is already in the group
/// with its own role (Mitglied, Helfer, Leitung, …). One account is not
/// Elternteil and member at once (Leon 13.11.), so such a registration is
/// refused up front and the child is never linked to that account.
bool hasOwnMemberRole(Role? role) =>
    role != null && role != Role.none && role != Role.applicant && role != Role.parent;
