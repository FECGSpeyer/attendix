// REDESIGN: pure logic of the Verwaltung (canvas "Verwaltung",
// "VerwSuche"): the six areas, the entries of the old settings page that
// sit in them and which role sees which entry. The conditions mirror
// `settings_page.dart` (Ionic settings.page.html) and the route guards.

/// The six areas of the Verwaltung, in canvas order. [key] is the path
/// segment of `/ich/verwaltung/:area`.
enum RdManageArea {
  members('mitglieder'),
  events('termine'),
  works('werke'),
  data('daten'),
  communication('kommunikation'),
  group('gruppe');

  const RdManageArea(this.key);
  final String key;

  static RdManageArea? fromKey(String? key) =>
      values.where((a) => a.key == key).firstOrNull;
}

/// One entry of the Verwaltung (one row of the old settings page).
enum RdManageEntry {
  approvals(RdManageArea.members),
  bulkMembers(RdManageArea.members),
  rolesPermissions(RdManageArea.members),
  admins(RdManageArea.members),
  parents(RdManageArea.members),
  viewers(RdManageArea.members),
  teachers(RdManageArea.members),
  missingAccounts(RdManageArea.members),
  archive(RdManageArea.members),
  myVoice(RdManageArea.members),
  attendanceTypes(RdManageArea.events),
  shiftPlans(RdManageArea.events),
  extraFields(RdManageArea.events),
  runSheets(RdManageArea.events),
  adHocPlanning(RdManageArea.events),
  planningTemplates(RdManageArea.events),
  works(RdManageArea.works),
  workHistory(RdManageArea.works),
  workCategories(RdManageArea.works),
  groups(RdManageArea.works),
  fileStorage(RdManageArea.works),
  statistics(RdManageArea.data),
  export(RdManageArea.data),
  certificates(RdManageArea.data),
  calendar(RdManageArea.data),
  writeMessage(RdManageArea.communication),
  announcements(RdManageArea.communication),
  teamOrg(RdManageArea.communication),
  myTasks(RdManageArea.communication),
  suggestTopic(RdManageArea.communication),
  protocols(RdManageArea.communication),
  general(RdManageArea.group),
  branding(RdManageArea.group),
  dashboard(RdManageArea.group),
  organisation(RdManageArea.group);

  const RdManageEntry(this.area);
  final RdManageArea area;

  static RdManageEntry? fromName(String name) =>
      values.where((e) => e.name == name).firstOrNull;
}

/// What the current user may manage. Built from the role, the tenant and a
/// few providers in the page; kept plain so every rule is unit-testable.
class RdManageAccess {
  const RdManageAccess({
    this.isAdmin = false,
    this.isSuperAdmin = false,
    this.isHelper = false,
    this.isApplicant = false,
    this.isVoiceLeader = false,
    this.canOpenWorks = false,
    this.isGeneral = false,
    this.isDemo = false,
    this.parentsEnabled = false,
    this.maintainTeachers = false,
    this.canAccessFiles = false,
    this.hasOrganisation = false,
    this.hasPending = false,
    this.hasMissingAccounts = false,
    this.isVorkurs = false,
    this.teamOrgEnabled = false,
    this.isTeamLeader = false,
    this.inTeamCircle = false,
    this.hasOwnTasks = false,
  });

  /// Ionic `isAdmin`: ADMIN or RESPONSIBLE.
  final bool isAdmin;

  /// ADMIN only (Administratoren).
  final bool isSuperAdmin;

  /// Helper or voice-leader helper.
  final bool isHelper;
  final bool isApplicant;

  /// Voice leader or voice-leader helper (`canSeeVoiceLeaderSettings`).
  final bool isVoiceLeader;

  /// The Werke tab is open to the role (`canOpenSongsTab`).
  final bool canOpenWorks;

  /// `tenants.type == 'general'` (no Werke area).
  final bool isGeneral;
  final bool isDemo;
  final bool parentsEnabled;
  final bool maintainTeachers;
  final bool canAccessFiles;
  final bool hasOrganisation;
  final bool hasPending;
  final bool hasMissingAccounts;

  /// A Vorkurs tenant (Urkunden).
  final bool isVorkurs;
  final bool teamOrgEnabled;
  final bool isTeamLeader;
  final bool inTeamCircle;
  final bool hasOwnTasks;

  bool get _showPlanning => isAdmin && !isApplicant;
  bool get _showTeam => teamOrgEnabled && (isTeamLeader || inTeamCircle || hasOwnTasks);
}

/// Whether [access] sees [entry] (same conditions as the old settings page).
bool rdManageVisible(RdManageEntry entry, RdManageAccess access) {
  final a = access;
  return switch (entry) {
    RdManageEntry.approvals => a.isAdmin && a.hasPending,
    RdManageEntry.rolesPermissions => a.isAdmin,
    RdManageEntry.bulkMembers => a.isAdmin && !a.isApplicant,
    RdManageEntry.admins => a.isSuperAdmin && !a.isDemo,
    RdManageEntry.parents => a.isAdmin && a.parentsEnabled,
    RdManageEntry.viewers => a.isAdmin,
    RdManageEntry.teachers => a.isAdmin && a.maintainTeachers,
    RdManageEntry.missingAccounts => a.isAdmin && a.hasMissingAccounts,
    RdManageEntry.archive => a.isAdmin && !a.isApplicant,
    RdManageEntry.myVoice => a.isVoiceLeader && !a.isGeneral,
    RdManageEntry.attendanceTypes ||
    RdManageEntry.shiftPlans ||
    RdManageEntry.extraFields =>
      a.isAdmin,
    RdManageEntry.runSheets || RdManageEntry.adHocPlanning => a._showPlanning,
    RdManageEntry.planningTemplates => a._showPlanning && a.hasOrganisation,
    RdManageEntry.works => !a.isGeneral && !a.isApplicant && a.canOpenWorks,
    RdManageEntry.workHistory => (a.isAdmin || a.isHelper) && !a.isGeneral && !a.isApplicant,
    RdManageEntry.workCategories => a.isAdmin && !a.isGeneral && !a.isApplicant,
    RdManageEntry.groups => a.isAdmin,
    RdManageEntry.fileStorage => a.canAccessFiles && (a.isGeneral || !a.isApplicant),
    RdManageEntry.statistics || RdManageEntry.export => a.isAdmin && !a.isApplicant,
    RdManageEntry.certificates => a.isAdmin && !a.isApplicant && a.isVorkurs,
    RdManageEntry.calendar => !a.isApplicant,
    RdManageEntry.announcements || RdManageEntry.writeMessage => a.isAdmin,
    RdManageEntry.teamOrg => a._showTeam && a.isTeamLeader,
    RdManageEntry.myTasks => a._showTeam && !a.isTeamLeader,
    RdManageEntry.suggestTopic ||
    RdManageEntry.protocols =>
      a._showTeam && !a.isTeamLeader && a.inTeamCircle,
    RdManageEntry.general ||
    RdManageEntry.branding ||
    RdManageEntry.dashboard ||
    RdManageEntry.organisation =>
      a.isAdmin,
  };
}

/// The entries [access] sees, in area and list order.
List<RdManageEntry> rdManageEntries(RdManageAccess access, {RdManageArea? area}) => [
      for (final e in RdManageEntry.values)
        if ((area == null || e.area == area) && rdManageVisible(e, access)) e,
    ];

/// Areas with at least one visible entry.
List<RdManageArea> rdManageAreas(RdManageAccess access) {
  final entries = rdManageEntries(access);
  return [
    for (final a in RdManageArea.values)
      if (entries.any((e) => e.area == a)) a,
  ];
}

/// Entries that already have a place in the new design outside the
/// Verwaltung (Werke tab, Ich › Kalender abonnieren).
const rdManageElsewhere = {RdManageEntry.works, RdManageEntry.calendar};

/// Whether "Ich" offers the Verwaltung: leads always, everyone else when an
/// entry is left that the new design does not show anywhere else.
bool rdShowsManage(RdManageAccess access) =>
    access.isAdmin ||
    rdManageEntries(access).any((e) => !rdManageElsewhere.contains(e));

/// Search over the entry title and its area name (all words must match).
bool rdManageMatches(String query, String title, String areaName, [String hint = '']) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final hay = '$title $areaName $hint'.toLowerCase();
  return q.split(RegExp(r'\s+')).every(hay.contains);
}

/// Adds [entry] in front of the recently opened entries, without
/// duplicates, keeping at most [max].
List<RdManageEntry> rdPushRecent(List<RdManageEntry> recent, RdManageEntry entry, {int max = 3}) =>
    [entry, ...recent.where((e) => e != entry)].take(max).toList();
