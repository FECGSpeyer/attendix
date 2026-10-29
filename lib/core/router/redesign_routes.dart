import '../constants/enums.dart';

// REDESIGN: routes of the new design (Beta) and the switch the router and
// the start-page logic read. The Beta flag is stored on the device only
// (redesign_providers.dart); this mirror lets pure functions such as
// `homeRouteFor` pick the new start page without Riverpod.

class RedesignRoutes {
  RedesignRoutes._();

  /// Tab "Heute" (start page of the new design for every role).
  static const String today = '/heute';

  /// Tab "Termine" (Termin list of the new design; parents keep the
  /// parents portal).
  static const String events = '/termine';

  /// A Termin ("Überblick" / "Anwesenheit") of the new design.
  static String event(int id, {bool record = false}) =>
      record ? '$events/$id?tab=anwesenheit' : '$events/$id';

  /// An own Termin of a Spieler (person_attendances id).
  static String ownEvent(String personAttendanceId) =>
      '$events/meine/${Uri.encodeComponent(personAttendanceId)}';

  /// Tab "Ich".
  static const String me = '/ich';

  /// Ich › Darstellung (Farbwelt, hell/dunkel).
  static const String appearance = '/ich/darstellung';

  /// True while the new design is switched on (set by
  /// `RedesignSettingsNotifier`).
  static bool active = false;

  /// Routes that only exist in the new design.
  static bool isRedesignRoute(String location) =>
      location == today ||
      location == events ||
      location == me ||
      location.startsWith('$today/') ||
      location.startsWith('$events/') ||
      location.startsWith('$me/');

  /// Role checks of the new design's routes (the router runs them after the
  /// Beta check); null when [role] may open [location].
  ///
  /// * Termine: parents answer in the parents portal, applicants have none.
  /// * A Termin opens only for roles that may open it in the old design
  ///   (`Role.canAddAttendance`, like `/attendance/:id`); an own Termin
  ///   (`/termine/meine/…`) for everyone else too.
  static String? roleRedirect(String location, Role role) {
    final isEvents = location == events || location.startsWith('$events/');
    if (!isEvents) return null;
    if (role.isParent) return '/parents';
    if (role.isApplicant) return today;
    // The own Termine are open to everyone with Termine.
    if (location.startsWith('$events/meine/')) return null;
    if (location != events && !role.canAddAttendance) return events;
    return null;
  }
}
