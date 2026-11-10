import '../../data/models/person/person.dart';

/// Key in `player.additional_fields` that marks a child that an Elternteil
/// registered via the register link ("Mein Kind").
///
/// Until a lead approves it, the child row carries the parent's account as
/// `appId` and this marker with the parent's name and e-mail. On approval
/// the parent becomes an Elternteil (parents row, role parent), the child
/// gets `parent_id` and loses `appId`, e-mail and the marker. No DB schema
/// change is needed for this.
const String kParentRegistrationKey = '_parent_registration';

/// The Elternteil who registered a child via the register link.
class ParentRegistration {
  const ParentRegistration({
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  final String firstName;
  final String lastName;
  final String email;

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() => {
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
    if (email is! String || email.trim().isEmpty) return null;
    return ParentRegistration(
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
