/// Values a "Person anlegen" form starts with (from the chat assistant).
/// Passed as route `extra` to `/people/new` and the Beta "Neue Person";
/// the form saves as usual (duplicate check, required fields, account).
class PersonCreatePrefill {
  const PersonCreatePrefill({required this.firstName, this.lastName, this.groupId, this.birthday});

  final String firstName;
  final String? lastName;
  final int? groupId;

  /// Local day.
  final DateTime? birthday;

  /// The prefill of a route `extra`, null for anything else.
  static PersonCreatePrefill? from(Object? extra) => extra is PersonCreatePrefill ? extra : null;
}
