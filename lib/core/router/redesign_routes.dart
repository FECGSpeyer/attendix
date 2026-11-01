import '../constants/enums.dart';
import 'route_access.dart' show canOpenSongsTab;

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

  /// "Neuer Termin" of the new design.
  static const String newEvent = '$events/neu';

  /// A Termin ("Überblick" / "Anwesenheit") of the new design.
  static String event(int id, {bool record = false}) =>
      record ? '$events/$id?tab=anwesenheit' : '$events/$id';

  /// An own Termin of a Spieler (person_attendances id).
  static String ownEvent(String personAttendanceId) =>
      '$events/meine/${Uri.encodeComponent(personAttendanceId)}';

  /// Tab "Mitglieder" of the new design (roles that see the old people
  /// tab; players keep `/members`).
  static const String members = '/mitglieder';

  /// A person of the new design.
  static String person(int id) => '$members/$id';

  /// "Verlauf" of a person (coming Termine and history).
  static String personHistory(int id) => '$members/$id/verlauf';

  /// Tab "Werke" of the new design.
  static const String works = '/werke';

  /// A work of the new design.
  static String work(int id) => '$works/$id';

  /// Tab "Ich".
  static const String me = '/ich';

  /// Ich › Darstellung (Farbwelt, hell/dunkel).
  static const String appearance = '/ich/darstellung';

  /// Ich › Verwaltung (the old settings in six areas).
  static const String manage = '/ich/verwaltung';

  /// One area of the Verwaltung (`RdManageArea.key`).
  static String manageArea(String key) => '$manage/$key';

  /// Verwaltung › Auswertung (statistics of the new design).
  static const String stats = '$manage/auswertung';

  /// Verwaltung › Mitteilung schreiben.
  static const String compose = '$manage/mitteilung';

  /// Verwaltung › Mitglieder bearbeiten (several members at once).
  static const String bulkMembers = '$manage/mitglieder-bearbeiten';

  /// Ich › Benachrichtigungen.
  static const String notifications = '$me/benachrichtigungen';

  /// Pages for leads only (Admins and Verantwortliche, like the old
  /// statistics, messages and archive entries).
  static const _leadOnly = {stats, compose, bulkMembers};

  /// True while the new design is switched on (set by
  /// `RedesignSettingsNotifier`).
  static bool active = false;

  /// Routes that only exist in the new design.
  static bool isRedesignRoute(String location) =>
      location == today ||
      location == events ||
      location == members ||
      location == works ||
      location == me ||
      location.startsWith('$today/') ||
      location.startsWith('$events/') ||
      location.startsWith('$members/') ||
      location.startsWith('$works/') ||
      location.startsWith('$me/');

  /// Where a notification, a push or an "open attendance" link leads while
  /// the new design is on: the old Termin page, "Meine Termine", the Termin
  /// list and the people list become their pages of the new design (the
  /// role checks of [roleRedirect] stay). Other locations and every location
  /// without the Beta stay as they are. "Alle Details" still pushes
  /// `/attendance/:id` directly, so this is no router redirect.
  /// Query and fragment (e.g. a push's `tenantId`) are kept.
  static String betaTarget(String location) {
    if (!active) return location;
    final uri = Uri.tryParse(location);
    if (uri == null) return location;
    final path = uri.path;
    final termin = RegExp(r'^/attendance/(\d+)$').firstMatch(path);
    final String target;
    if (termin != null) {
      target = event(int.parse(termin.group(1)!));
    } else if (path == '/signout' || path == '/attendance') {
      target = events;
    } else if (path == '/people') {
      target = members;
    } else {
      return location;
    }
    return uri.replace(path: target).toString();
  }

  /// Role checks of the new design's routes (the router runs them after the
  /// Beta check); null when [role] may open [location].
  ///
  /// * Termine: parents answer in the parents portal, applicants have none.
  /// * A Termin opens only for roles that may open it in the old design
  ///   (`Role.canAddAttendance`, like `/attendance/:id`); an own Termin
  ///   (`/termine/meine/…`) for everyone else too.
  /// * Mitglieder and its persons only for roles with the old people tab
  ///   (`Role.canSeePeopleTab`, like `/people`).
  /// * Werke like `/songs-tab` (not for parents and applicants).
  /// * Verwaltung not for applicants and parents (nothing to manage there);
  ///   each entry keeps the guard of the page it opens.
  static String? roleRedirect(String location, Role role) {
    if (location == manage || location.startsWith('$manage/')) {
      if (role.isApplicant || role.isParent) return me;
      if (_leadOnly.contains(location) && !(role.isAdmin || role.isResponsible)) return manage;
      return null;
    }
    if (location == members || location.startsWith('$members/')) {
      return role.canSeePeopleTab ? null : today;
    }
    if (location == works || location.startsWith('$works/')) {
      return canOpenSongsTab(role) ? null : today;
    }
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
