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

  /// The current Problemfälle as a list of their own, pushed from "Heute"
  /// or Verwaltung › Problemfälle so back returns there. [from] names the
  /// page below for the back link ('heute' / 'verwaltung').
  static String criticalMembers({String? from}) =>
      from == null ? '$members/problemfaelle' : '$members/problemfaelle?von=$from';

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

  /// Werke › + › "Werkliste importieren" (Excel/CSV) as a page of the tab
  /// (was the classic full-screen modal); leads only like [worksImport].
  static const String workListImport = '$works/werkliste';

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

  /// Ich › Verwaltung (Dirigent and Verantwortliche: one page, five
  /// sections).
  static const String manage = '/ich/verwaltung';

  /// One section of the Verwaltung (`RdManageArea.key`; desktop).
  static String manageArea(String key) => '$manage/$key';

  /// Verwaltung › Auswertung (statistics of the new design).
  static const String stats = '$manage/auswertung';

  /// Verwaltung › Mitteilung schreiben.
  static const String compose = '$manage/mitteilung';

  /// Verwaltung › Name und Kürzel (same page as `/settings/general`, here
  /// so it opens on the right of the list on wide screens).
  static const String groupName = '$manage/name';

  /// Verwaltung › Mitteilungen (same page as `/settings/messages`).
  static const String messages = '$manage/mitteilungen';

  /// Verwaltung › Organisation (same page as `/settings/org-settings`).
  static const String organisation = '$manage/organisation';

  /// Verwaltung › Anmeldung per Link (from the old "Allgemein").
  static const String registration = '$manage/anmeldung';

  /// Verwaltung › Abmeldegründe (from the old "Allgemein").
  static const String reasons = '$manage/abmeldegruende';

  /// Verwaltung › Problemfälle (rules; from the old "Allgemein").
  static const String critical = '$manage/problemfaelle';

  /// Verwaltung › Ferien und Feiertage (from the old "Allgemein").
  static const String holidays = '$manage/feiertage';

  /// Verwaltung › Register (replaces `/settings/instruments` in the Beta).
  static const String groups = '$manage/gruppen';

  /// "Gruppe bearbeiten" of the new design.
  static String groupEdit(int id) => '$groups/$id';

  /// Verwaltung › Anwesenheits-Typen (list; a type opens the old page).
  static const String attendanceTypes = '$manage/terminarten';

  /// Verwaltung › Schichtpläne (list; a plan opens the old page).
  static const String shiftPlans = '$manage/schichtplaene';

  /// Verwaltung › Rollen und Rechte (replaces `/settings/role-permissions`).
  static const String rolePermissions = '$manage/rollen';

  /// One role of Rollen und Rechte (`RdRoleView.key`).
  static String role(String key) => '$rolePermissions/$key';

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

  /// [approvals] pushed from another page: [from] names it for the back
  /// link ('heute').
  static String approvalsFrom(String from) => '$approvals?von=$from';

  /// Freigaben › "Anfrage prüfen" of a person (replaces the old review
  /// page `/people/:id` in the Beta; leads only like [approvals]).
  static String approvalReview(int id) => '$approvals/$id';

  /// [archive] opened from the Mitglieder tab (•••): the same page inside
  /// that tab with "‹ Mitglieder" (leads only).
  static const String membersArchive = '$members/archiv';

  /// [approvalReview] opened from the Mitglieder tab or a person: the same
  /// page inside that tab with "‹ Mitglieder" (leads only).
  static String membersReview(int id) => '$members/anfrage/$id';

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

  /// Werke › ••• › Werk-Kategorien (replaces the old categories sheet).
  static const String workCategories = '$manage/werk-kategorien';

  /// Werke › ••• › Gespielte Werke (replaces the old history modal; the
  /// path stays under the Verwaltung, the tab is Werke).
  static const String workHistory = '$manage/werkhistorie';

  /// Ich › Benachrichtigungen.
  static const String notifications = '$me/benachrichtigungen';

  /// "Meine Gruppen" inside the tab "Ich" (the list of `/tenants`, which
  /// stays the entry without a group and right after the sign-in).
  static const String myGroups = '$me/gruppen';

  /// Pages for super admins only (the old admins sheet: `role.isAdmin`).
  static const _adminOnly = {admins};

  static bool _matches(Set<String> routes, String location) =>
      routes.any((route) => location == route || location.startsWith('$route/'));

  /// Routes that only exist in the standard app design.
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

  /// Where a notification, a push or an "open attendance" link leads: the old
  /// Termin page, "Meine Termine", the Termin list and the people list map to
  /// their pages (`/termine`, `/termine/:id`, `/mitglieder`). Other locations
  /// stay as they are. Query and fragment (e.g. a push's `tenantId`) are kept.
  static String betaTarget(String location) {
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

  /// Translates all removed classic routes (and legacy start pages) to their
  /// destinations while preserving query and fragment parameters. Returns `null`
  /// for routes that are still active directly.
  static String? legacyTarget(String location) {
    final uri = Uri.tryParse(location);
    if (uri == null) return null;
    final path = uri.path;

    String? mapped;
    final personMatch = RegExp(r'^/people/(\d+)$').firstMatch(path);
    final songMatch = RegExp(r'^/(?:settings/songs|songs-tab)/(\d+)(/edit)?$').firstMatch(path);

    if (path == '/settings' || path == '/settings/profile' || path == '/settings/calendar') {
      mapped = me;
    } else if (path == '/settings/meetings' || path.startsWith('/settings/meetings/')) {
      mapped = '/settings/team-organization';
    } else if (path == '/overview' || path == '/home-dashboard') {
      mapped = today;
    } else if (path == '/attendance/new') {
      mapped = newEvent;
    } else if (path == '/people/new') {
      mapped = personNew;
    } else if (personMatch != null) {
      mapped = person(int.parse(personMatch.group(1)!));
    } else if (path == '/statistics') {
      mapped = stats;
    } else if (path == '/history') {
      mapped = workHistory;
    } else if (path == '/settings/songs/new') {
      mapped = newWork;
    } else if (songMatch != null) {
      final id = int.parse(songMatch.group(1)!);
      mapped = (songMatch.group(2) != null && !path.startsWith('/songs-tab/'))
          ? workEdit(id)
          : work(id);
    } else if (path == '/settings/songs' || path == '/songs-tab') {
      mapped = works;
    } else if (path == '/settings/instruments') {
      mapped = groups;
    } else if (path == '/settings/teachers') {
      mapped = teachers;
    } else if (path == '/settings/users') {
      mapped = admins;
    } else if (path == '/settings/types') {
      // Only exact root; /settings/types/:id stays active for detail editing.
      mapped = attendanceTypes;
    } else if (path == '/settings/shifts') {
      // Only exact root; /settings/shifts/:id stays active for detail editing.
      mapped = shiftPlans;
    } else if (path == '/settings/pending') {
      mapped = approvals;
    } else if (path == '/settings/left') {
      mapped = archive;
    } else if (path == '/settings/viewers') {
      mapped = viewers;
    } else if (path == '/settings/parents') {
      mapped = parents;
    } else if (path == '/settings/role-permissions') {
      mapped = rolePermissions;
    } else if (path == '/settings/general/extra-fields') {
      mapped = extraFields;
    } else if (path == '/settings/dashboard') {
      mapped = manage;
    } else if (path == '/org-plans-tab') {
      mapped = '/settings/org-plans';
    } else if (path == '/org-plans-tab/planung') {
      mapped = '/settings/org-plans/planung';
    } else {
      final b = betaTarget(location);
      return b == location ? null : b;
    }

    return uri.replace(path: mapped).toString();
  }

  /// Legacy song path mapper; equivalent paths are also handled by [legacyTarget].
  static String? oldSongTarget(String location) {
    final uri = Uri.tryParse(location);
    if (uri == null) return null;
    final m = RegExp(r'^/(?:settings/songs|songs-tab)/(\d+)(/edit)?$').firstMatch(uri.path);
    if (m == null) return null;
    final id = int.parse(m.group(1)!);
    final mapped = (m.group(2) != null && !uri.path.startsWith('/songs-tab/'))
        ? workEdit(id)
        : work(id);
    return uri.replace(path: mapped).toString();
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
  /// * Verwaltung and its pages only for Admins and Verantwortliche (like
  ///   the old statistics, messages, archive, group, type and shift pages
  ///   and `/settings/parents|viewers|pending|left`); Admins only for the
  ///   super admins. Two pages stay open to others, like on the old page:
  ///   the Werkhistorie for helpers (Werke tab › •••) and the Lehrer list
  ///   for Beobachter (`Role.isConductor`); a teacher opens only for leads.
  static String? roleRedirect(String location, Role role) {
    if (location == manage || location.startsWith('$manage/')) {
      if (role.isAdmin || role.isResponsible) {
        if (_matches(_adminOnly, location) && !role.isAdmin) return manage;
        return null;
      }
      if (role.isHelperRole && _matches({workHistory}, location)) return null;
      if (role.isConductor && location == teachers) return null;
      if (role.isConductor && location.startsWith('$teachers/')) return teachers;
      return me;
    }
    if (location == members || location.startsWith('$members/')) {
      if (!role.canSeePeopleTab) return today;
      // "Neue Person" and "Person bearbeiten" like the old person form:
      // Admins and Verantwortliche.
      final lead = role.isAdmin || role.isResponsible;
      if (location == personNew && !lead) return members;
      // Archiv and "Anfrage prüfen" like in the Verwaltung: leads only.
      if ((location == membersArchive || location.startsWith('$members/anfrage/')) && !lead) return members;
      final edit = RegExp('^$members/(\\d+)/bearbeiten\$').firstMatch(location);
      if (edit != null && !lead) return person(int.parse(edit.group(1)!));
      return null;
    }
    if (location == works || location.startsWith('$works/')) {
      if (!canOpenSongsTab(role)) return today;
      if ((location == worksImport || location == workListImport) && !(role.isAdmin || role.isResponsible)) {
        return works;
      }
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
