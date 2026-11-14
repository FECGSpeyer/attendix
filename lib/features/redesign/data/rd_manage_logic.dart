// REDESIGN: pure logic of the Verwaltung (canvas "Beta: Verwaltung neu
// gedacht", boards "Nachher · Verwaltung auf einer Seite" and "Nachher ·
// Suche"): one page for Dirigent and Verantwortliche with five sections.
// Entries of the old settings page that now live where they are used
// (Mitglieder and Werke tab, Ich, Auswertung, Organisation) stay findable
// through the search, with a hint where they are now. The conditions mirror
// `settings_page.dart` (Ionic settings.page.html) and the route guards.

/// The sections of the Verwaltung, in page order. [key] is the path segment
/// of `/ich/verwaltung/:area` (desktop: the section open on the right).
enum RdManageArea {
  members('mitglieder'),
  access('zugaenge'),
  events('termine'),
  data('daten'),
  group('gruppe');

  const RdManageArea(this.key);
  final String key;

  static RdManageArea? fromKey(String? key) =>
      values.where((a) => a.key == key).firstOrNull;
}

/// Where an entry that left the Verwaltung lives now (search hint).
enum RdManageHome { members, works, worksCategories, event, stats, organisation, me, roles }

/// One entry of the Verwaltung. Entries with an [area] are rows of the page;
/// the others moved to their [home] and only show up in the search.
enum RdManageEntry {
  // Mitglieder
  groups(RdManageArea.members),
  extraFields(RdManageArea.members),
  registration(RdManageArea.members),
  critical(RdManageArea.members),
  teachers(RdManageArea.members),
  missingAccounts(RdManageArea.members),
  archive(RdManageArea.members),
  // Zugänge und Rechte: one row, the list of roles. Admins, Eltern and
  // Beobachter are rows of that list (below, "moved").
  rolesPermissions(RdManageArea.access),
  // Termine
  attendanceTypes(RdManageArea.events),
  reasons(RdManageArea.events),
  shiftPlans(RdManageArea.events),
  holidays(RdManageArea.events),
  adHocPlanning(RdManageArea.events),
  // Auswertung und Mitteilungen
  statistics(RdManageArea.data),
  announcements(RdManageArea.data),
  // Gruppe und Organisation
  general(RdManageArea.group),
  organisation(RdManageArea.group),
  // Moved to where they are used.
  admins(null, RdManageHome.roles),
  parents(null, RdManageHome.roles),
  viewers(null, RdManageHome.roles),
  approvals(null, RdManageHome.members),
  bulkMembers(null, RdManageHome.members),
  workHistory(null, RdManageHome.works),
  workCategories(null, RdManageHome.worksCategories),
  fileStorage(null, RdManageHome.works),
  sharing(null, RdManageHome.works),
  runSheets(null, RdManageHome.event),
  export(null, RdManageHome.stats),
  certificates(null, RdManageHome.stats),
  branding(null, RdManageHome.organisation),
  planningTemplates(null, RdManageHome.organisation),
  orgPlans(null, RdManageHome.organisation),
  calendar(null, RdManageHome.me),
  team(null, RdManageHome.me);

  const RdManageEntry(this.area, [this.home]);

  /// Section of the page; null when the entry moved ([home]).
  final RdManageArea? area;
  final RdManageHome? home;

  bool get moved => area == null;

  static RdManageEntry? fromName(String name) =>
      values.where((e) => e.name == name).firstOrNull;
}

/// What the current user may manage. Built from the role, the tenant and a
/// few providers in the page; kept plain so every rule is unit-testable.
class RdManageAccess {
  const RdManageAccess({
    this.isAdmin = false,
    this.isSuperAdmin = false,
    this.isGeneral = false,
    this.isDemo = false,
    this.parentsEnabled = false,
    this.maintainTeachers = false,
    this.canAccessFiles = false,
    this.hasOrganisation = false,
    this.hasMissingAccounts = false,
    this.isVorkurs = false,
    this.showTeam = false,
    this.isOrchestra = false,
    this.sharingEnabled = false,
  });

  /// Ionic `isAdmin`: ADMIN or RESPONSIBLE (Dirigent, Verantwortliche).
  final bool isAdmin;

  /// ADMIN only (Admins).
  final bool isSuperAdmin;

  /// `tenants.type == 'general'` (no Werke tab).
  final bool isGeneral;
  final bool isDemo;
  final bool parentsEnabled;
  final bool maintainTeachers;
  final bool canAccessFiles;
  final bool hasOrganisation;
  final bool hasMissingAccounts;

  /// A Vorkurs tenant (Urkunden).
  final bool isVorkurs;

  /// Team organisation on and the user in the team (Ich › Team).
  final bool showTeam;

  /// `tenants.type == 'orchestra'` (only orchestras keep teachers).
  final bool isOrchestra;

  /// Werke are shared by link (`song_sharing_id`).
  final bool sharingEnabled;
}

/// Whether "Ich" and the sidebar offer the Verwaltung: only Dirigent and
/// Verantwortliche. What other roles had there now sits in "Ich" or in its
/// tab (Meine Stimme, Team, Werkhistorie, Dateiablage).
bool rdShowsManage(RdManageAccess access) => access.isAdmin;

/// Whether [access] sees [entry] (rows of the page and search results).
bool rdManageVisible(RdManageEntry entry, RdManageAccess access) {
  final a = access;
  if (!a.isAdmin) return false;
  return switch (entry) {
    // Off: still found and shown under "Noch nicht genutzt" (the switch is
    // on its page).
    RdManageEntry.teachers => a.maintainTeachers || a.isOrchestra,
    RdManageEntry.missingAccounts => a.hasMissingAccounts,
    RdManageEntry.admins => a.isSuperAdmin && !a.isDemo,
    RdManageEntry.workHistory || RdManageEntry.workCategories => !a.isGeneral,
    RdManageEntry.fileStorage => a.canAccessFiles,
    RdManageEntry.certificates => a.isVorkurs,
    RdManageEntry.branding ||
    RdManageEntry.planningTemplates ||
    RdManageEntry.orgPlans =>
      a.hasOrganisation,
    RdManageEntry.team => a.showTeam,
    _ => true,
  };
}

/// Features that are off: "Noch nicht genutzt" with one sentence what they
/// are for; once on, they move into their section.
List<RdManageEntry> rdManageUnused(RdManageAccess access) => [
      if (access.isAdmin && access.isOrchestra && !access.maintainTeachers) RdManageEntry.teachers,
      if (access.isAdmin && !access.parentsEnabled) RdManageEntry.parents,
      if (access.isAdmin && !access.sharingEnabled) RdManageEntry.sharing,
    ];

/// Section of [entry] for [access], null when it moved. "Werke öffentlich
/// teilen" lives in the Werke tab; groups of type "Allgemein" have none, so
/// there it stays a row of "Gruppe und Organisation".
RdManageArea? rdManageAreaOf(RdManageEntry entry, RdManageAccess access) =>
    entry == RdManageEntry.sharing && access.isGeneral ? RdManageArea.group : entry.area;

/// The rows [access] sees, in page order (moved and unused entries are left
/// out).
List<RdManageEntry> rdManageEntries(RdManageAccess access, {RdManageArea? area}) {
  final unused = rdManageUnused(access);
  return [
    for (final e in RdManageEntry.values)
      if (rdManageAreaOf(e, access) case final a?)
        if ((area == null || a == area) && rdManageVisible(e, access) && !unused.contains(e)) e,
  ];
}

/// Every entry the search may find: the rows plus the moved ones.
List<RdManageEntry> rdManageSearchable(RdManageAccess access) => [
      for (final e in RdManageEntry.values)
        if (rdManageVisible(e, access)) e,
    ];

/// Sections with at least one row.
List<RdManageArea> rdManageAreas(RdManageAccess access) {
  final entries = rdManageEntries(access);
  return [
    for (final a in RdManageArea.values)
      if (entries.any((e) => rdManageAreaOf(e, access) == a)) a,
  ];
}

/// Where a moved entry lives for [access]: the Dateiablage sits in the
/// Werke tab, in groups without one under Ich.
RdManageHome? rdManageHome(RdManageEntry entry, RdManageAccess access) {
  if (rdManageAreaOf(entry, access) != null) return null;
  return entry == RdManageEntry.fileStorage && access.isGeneral ? RdManageHome.me : entry.home;
}

/// Search over title, section or new place, hint, former names and the
/// switches on the page (all words must match).
bool rdManageMatches(String query, String title, String place, [String hint = '', String keywords = '']) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final hay = '$title $place $hint $keywords'.toLowerCase();
  return q.split(RegExp(r'\s+')).every(hay.contains);
}

/// Adds [entry] in front of the recently opened entries, without
/// duplicates, keeping at most [max].
List<RdManageEntry> rdPushRecent(List<RdManageEntry> recent, RdManageEntry entry, {int max = 3}) =>
    [entry, ...recent.where((e) => e != entry)].take(max).toList();

/// Whether "Ich" shows "Dateien": groups without a Werke tab (there the
/// Dateiablage sits in the Werke tab's "•••").
bool rdMeShowsFiles({required bool canAccessFiles, required bool hasWorksTab}) =>
    canAccessFiles && !hasWorksTab;
