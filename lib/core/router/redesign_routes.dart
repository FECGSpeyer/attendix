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

  /// "Termin bearbeiten" of the new design.
  static String eventEdit(int id) => '$events/$id/bearbeiten';

  /// An own Termin of a Spieler (person_attendances id).
  static String ownEvent(String personAttendanceId) =>
      '$events/meine/${Uri.encodeComponent(personAttendanceId)}';

  /// Tab "Mitglieder" of the new design (roles that see the old people
  /// tab; players keep `/members`).
  static const String members = '/mitglieder';

  /// A person of the new design.
  static String person(int id) => '$members/$id';

  /// "Neue Person" of the new design (replaces `/people/new` in the Beta).
  static const String personNew = '$members/neu';

  /// "Person bearbeiten" of the new design (replaces `/people/:id`).
  static String personEdit(int id) => '$members/$id/bearbeiten';

  /// "Verlauf" of a person (coming Termine and history).
  static String personHistory(int id) => '$members/$id/verlauf';

  /// Tab "Werke" of the new design.
  static const String works = '/werke';

  /// A work of the new design.
  static String work(int id) => '$works/$id';

  /// Werke › "Noten importieren" (Admins and Verantwortliche, like the
  /// entry in the Werke list).
  static const String worksImport = '$works/import';

  /// "Werk bearbeiten" of the new design (replaces the old song page).
  static String workEdit(int id) => '$works/$id/bearbeiten';

  /// "Neues Werk" of the new design (title and number, then the Noten).
  static const String newWork = '$works/neu';

  /// "Meine Noten" / "Nach Stimme": the Noten of one part as one folder.
  static const String folder = '$works/mappe';

  /// "Sammlungen" of the Werke (Admins and Verantwortliche).
  static const String collections = '$works/sammlungen';

  /// "Sammlung bearbeiten".
  static String collection(int id) => '$collections/$id';

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

  /// Verwaltung › Gruppen (replaces `/settings/instruments` in the Beta).
  static const String groups = '$manage/gruppen';

  /// "Gruppe bearbeiten" of the new design.
  static String groupEdit(int id) => '$groups/$id';

  /// Verwaltung › Anwesenheits-Typen (list; a type opens the old page).
  static const String attendanceTypes = '$manage/terminarten';

  /// Verwaltung › Schichtpläne (list; a plan opens the old page).
  static const String shiftPlans = '$manage/schichtplaene';

  /// Verwaltung › Rollen und Rechte (replaces `/settings/role-permissions`).
  static const String rolePermissions = '$manage/rollen';

  /// Verwaltung › Admins (replaces the old admins sheet; super admins only).
  static const String admins = '$manage/admins';

  /// Verwaltung › Eltern (replaces the old parents sheet).
  static const String parents = '$manage/eltern';

  /// Verwaltung › Beobachter (replaces the old viewers sheet).
  static const String viewers = '$manage/beobachter';

  /// Verwaltung › Archiv: persons who left (replaces the old archive sheet).
  static const String archive = '$manage/archiv';

  /// Verwaltung › Freigaben: persons waiting for approval (replaces the old
  /// pending sheet).
  static const String approvals = '$manage/freigaben';

  /// Freigaben › "Anfrage prüfen" of a person (replaces the old review
  /// page `/people/:id` in the Beta; leads only like [approvals]).
  static String approvalReview(int id) => '$approvals/$id';

  /// Verwaltung › Lehrer (replaces `/settings/teachers` in the Beta).
  static const String teachers = '$manage/lehrer';

  /// "Lehrer bearbeiten" of the new design.
  static String teacherEdit(int id) => '$teachers/$id';

  /// Verwaltung › Zusatzfelder (replaces `/settings/general/extra-fields`).
  static const String extraFields = '$manage/zusatzfelder';

  /// "Zusatzfeld bearbeiten": field ids are unique per list only, so the
  /// list (persons or works) is part of the path.
  static String extraFieldEdit({required bool song, required String id}) =>
      '$extraFields/${song ? 'werke' : 'personen'}/${Uri.encodeComponent(id)}';

  /// Gruppen › Kategorien (replaces the old group categories sheet; its own
  /// path because `gruppen/:id` is a group).
  static const String groupCategories = '$manage/gruppen-kategorien';

  /// Verwaltung › Werk-Kategorien (replaces the old categories sheet).
  static const String workCategories = '$manage/werk-kategorien';

  /// Verwaltung › Werkhistorie (replaces the old history modal).
  static const String workHistory = '$manage/werkhistorie';

  /// Ich › Benachrichtigungen.
  static const String notifications = '$me/benachrichtigungen';

  /// Pages for leads only (Admins and Verantwortliche, like the old
  /// statistics, messages and archive entries, the old group, type and
  /// shift pages and `/settings/parents|viewers|pending|left`); their sub
  /// pages too.
  static const _leadOnly = {
    stats,
    compose,
    bulkMembers,
    groups,
    attendanceTypes,
    shiftPlans,
    parents,
    viewers,
    archive,
    approvals,
    rolePermissions,
    extraFields,
    workCategories,
    groupCategories,
  };

  /// Pages for super admins only (the old admins sheet: `role.isAdmin`).
  static const _adminOnly = {admins};

  static bool _matches(Set<String> routes, String location) =>
      routes.any((route) => location == route || location.startsWith('$route/'));

  static bool _isLeadOnly(String location) => _matches(_leadOnly, location);

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

  /// The old song page while the new design is on: `/settings/songs/:id`
  /// and `/songs-tab/:id` open the Werk page, `/settings/songs/:id/edit`
  /// "Werk bearbeiten" (links from the old pages, e.g. "Alle Details" of a
  /// Termin). Null for every other location.
  static String? oldSongTarget(String location) {
    final m = RegExp(r'^/(?:settings/songs|songs-tab)/(\d+)(/edit)?$').firstMatch(location);
    if (m == null) return null;
    final id = int.parse(m.group(1)!);
    if (m.group(2) != null && !location.startsWith('/songs-tab/')) return workEdit(id);
    return work(id);
  }

  /// Role checks of the new design's routes (the router runs them after the
  /// Beta check); null when [role] may open [location].
  ///
  /// * Termine: parents answer in the parents portal, applicants have none.
  /// * A Termin opens only for roles that may open it in the old design
  ///   (`Role.canAddAttendance`, like `/attendance/:id`); an own Termin
  ///   (`/termine/meine/…`) for everyone else too.
  /// * Mitglieder and its persons only for roles with the old people tab
  ///   (`Role.canSeePeopleTab`, like `/people`); "Neue Person" and "Person
  ///   bearbeiten" only for Admins and Verantwortliche.
  /// * Werke like `/songs-tab` (not for parents and applicants).
  /// * Verwaltung not for applicants and parents (nothing to manage there);
  ///   each entry keeps the guard of the page it opens.
  /// * Lehrer like `/settings/teachers` (`Role.isConductor`: Admins,
  ///   Verantwortliche and Beobachter see the list); a teacher opens only
  ///   for Admins and Verantwortliche, like on the old page.
  static String? roleRedirect(String location, Role role) {
    if (location == manage || location.startsWith('$manage/')) {
      if (role.isApplicant || role.isParent) return me;
      if (_isLeadOnly(location) && !(role.isAdmin || role.isResponsible)) return manage;
      if (_matches(_adminOnly, location) && !role.isAdmin) return manage;
      // Werkhistorie like the old entry: leads and helpers.
      if (_matches({workHistory}, location) && !(role.isAdmin || role.isResponsible || role.isHelperRole)) {
        return manage;
      }
      if (location == teachers || location.startsWith('$teachers/')) {
        if (!role.isConductor) return manage;
        if (location != teachers && !(role.isAdmin || role.isResponsible)) return teachers;
      }
      return null;
    }
    if (location == members || location.startsWith('$members/')) {
      if (!role.canSeePeopleTab) return today;
      // "Neue Person" and "Person bearbeiten" like the old person form:
      // Admins and Verantwortliche.
      final lead = role.isAdmin || role.isResponsible;
      if (location == personNew && !lead) return members;
      final edit = RegExp('^$members/(\\d+)/bearbeiten\$').firstMatch(location);
      if (edit != null && !lead) return person(int.parse(edit.group(1)!));
      return null;
    }
    if (location == works || location.startsWith('$works/')) {
      if (!canOpenSongsTab(role)) return today;
      if (location == worksImport && !(role.isAdmin || role.isResponsible)) return works;
      // "Neues Werk" and "Werk bearbeiten" like the old song form: Admins
      // and Verantwortliche.
      if (location == newWork && !(role.isAdmin || role.isResponsible)) return works;
      // Sammlungen like the song categories: Admins and Verantwortliche.
      if ((location == collections || location.startsWith('$collections/')) &&
          !(role.isAdmin || role.isResponsible)) {
        return works;
      }
      final edit = RegExp('^$works/(\\d+)/bearbeiten\$').firstMatch(location);
      if (edit != null && !(role.isAdmin || role.isResponsible)) return work(int.parse(edit.group(1)!));
      return null;
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
