import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../core/providers/debug_providers.dart';
import '../../../../../core/providers/demo_providers.dart';
import '../../../../../core/providers/organisation_providers.dart';
import '../../../../../core/providers/player_providers.dart';
import '../../../../../core/providers/realtime_providers.dart';
import '../../../../../core/providers/role_permission_providers.dart';
import '../../../../../core/providers/team_org_providers.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/router/redesign_routes.dart';
import '../../../../../core/services/certificate_service.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../history/presentation/pages/history_page.dart' show showHistoryModal;
import '../../../../settings/presentation/pages/settings_page.dart'
    show createMissingAccounts, playersOfCurrentTenant;
import '../../../../settings/presentation/widgets/calendar_subscription_dialog.dart';
import '../../pages/rd_general_settings_page.dart' show showRdSharingSheet;
import 'rd_data_sheets.dart';
import '../../../../songs/presentation/widgets/song_categories_sheet.dart';
import '../../../data/providers/rd_members_providers.dart' show rdMembersSelectingProvider;
import '../../../data/rd_manage_logic.dart';

/// REDESIGN: titles, icons and actions of the Verwaltung entries. Every entry
/// opens what the old settings page opens (same pages, sheets and guards);
/// the Verwaltung sorts them into five sections, moved entries are found by
/// the search.

/// Persons of the current tenant with an e-mail but no account (Ionic
/// `getPlayersWithoutAccount`, like the old settings page).
final rdMissingAccountsProvider = Provider.autoDispose<List<Person>>((ref) {
  final role = ref.watch(effectiveRoleProvider);
  if (!(role.isAdmin || role.isResponsible)) return const [];
  return playersOfCurrentTenant(ref.watch(playersProvider), ref.watch(currentTenantIdProvider))
      .where((p) =>
          (p.appId == null || p.appId!.isEmpty) &&
          !p.pending &&
          p.left == null &&
          (p.email ?? '').trim().isNotEmpty)
      .toList();
});

/// Persons waiting for approval (live), only for admins.
final rdManagePendingProvider = Provider.autoDispose<List<Person>>((ref) {
  final role = ref.watch(effectiveRoleProvider);
  if (!(role.isAdmin || role.isResponsible)) return const [];
  return ref.watch(realtimePendingPlayersProvider).valueOrNull ?? const [];
});

/// What the current user may manage (see [rdManageVisible]).
final rdManageAccessProvider = Provider.autoDispose<RdManageAccess>((ref) {
  final role = ref.watch(effectiveRoleProvider);
  final isAdmin = role.isAdmin || role.isResponsible;
  // Only leads have a Verwaltung: nothing else is loaded for other roles.
  if (!isAdmin) return RdManageAccess(showTeam: ref.watch(rdShowTeamProvider));
  final tenant = ref.watch(currentTenantProvider);
  return RdManageAccess(
    isAdmin: true,
    isSuperAdmin: role.isAdmin,
    isGeneral: tenant?.type == 'general',
    isDemo: ref.watch(isDemoProvider),
    parentsEnabled: tenant?.parents == true,
    maintainTeachers: tenant?.maintainTeachers == true,
    canAccessFiles: ref.watch(canAccessFilesProvider),
    hasOrganisation: ref.watch(currentOrganisationProvider).valueOrNull != null,
    hasMissingAccounts: ref.watch(rdMissingAccountsProvider).isNotEmpty,
    isVorkurs: isVorkursTenantName(tenant?.shortName, tenant?.longName),
    showTeam: ref.watch(rdShowTeamProvider),
    isOrchestra: tenant?.type == 'orchestra',
    sharingEnabled: (tenant?.songSharingId ?? '').isNotEmpty,
  );
});

/// Whether "Ich" offers "Team" (the team organisation is on): team
/// leaders, the team circle and everyone with own tasks, like the old
/// settings entries Teamorganisation, Meine Aufgaben, Themen, Protokolle.
final rdShowTeamProvider = Provider.autoDispose<bool>((ref) {
  if (!ref.watch(teamOrgEnabledProvider)) return false;
  if (ref.watch(isTeamLeaderProvider) || ref.watch(inTeamCircleProvider)) return true;
  return ref.watch(myTasksProvider).valueOrNull?.isNotEmpty ?? false;
});

const rdManageRecentStorageKey = 'redesign.manageRecent';

/// Recently opened entries ("Zuletzt geöffnet" of the search), stored on
/// this device only.
class RdManageRecentNotifier extends Notifier<List<RdManageEntry>> {
  @override
  List<RdManageEntry> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = (prefs.getStringList(rdManageRecentStorageKey) ?? const <String>[])
          .map(RdManageEntry.fromName)
          .whereType<RdManageEntry>();
      // Entries opened while loading stay in front.
      var merged = state;
      for (final e in stored) {
        if (!merged.contains(e)) merged = [...merged, e];
      }
      state = merged.take(3).toList();
    } catch (_) {
      // Storage unavailable (private mode): no recent entries.
    }
  }

  void push(RdManageEntry entry) {
    state = rdPushRecent(state, entry);
    final names = state.map((e) => e.name).toList();
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setStringList(rdManageRecentStorageKey, names))
        .catchError((_) => false);
  }
}

final rdManageRecentProvider =
    NotifierProvider<RdManageRecentNotifier, List<RdManageEntry>>(RdManageRecentNotifier.new);

String rdManageAreaName(AppLocalizations l10n, RdManageArea area) => switch (area) {
      RdManageArea.members => l10n.rdAdminAreaMembers,
      RdManageArea.access => l10n.rdAdminAreaAccess,
      RdManageArea.events => l10n.rdAdminAreaEvents,
      RdManageArea.data => l10n.rdAdminAreaData,
      RdManageArea.group => l10n.rdAdminAreaGroup,
    };

IconData rdManageAreaIcon(RdManageArea area) => switch (area) {
      RdManageArea.members => Icons.people_alt_outlined,
      RdManageArea.access => Icons.key_outlined,
      RdManageArea.events => Icons.event_note_outlined,
      RdManageArea.data => Icons.insert_chart_outlined,
      RdManageArea.group => Icons.tune,
    };

/// "Im Werke-Tab unter •••": where a moved entry is now.
String rdManageHomeName(AppLocalizations l10n, RdManageHome home) => switch (home) {
      RdManageHome.members => l10n.rdAdminHomeMembers,
      RdManageHome.works => l10n.rdAdminHomeWorks,
      RdManageHome.event => l10n.rdAdminHomeEvent,
      RdManageHome.stats => l10n.rdAdminHomeStats,
      RdManageHome.organisation => l10n.rdAdminHomeOrganisation,
      RdManageHome.me => l10n.rdAdminHomeMe,
    };

/// Title of [entry]; the pages it opens use the same title.
String rdManageTitle(AppLocalizations l10n, RdManageEntry entry) => switch (entry) {
      RdManageEntry.groups => l10n.rdAdminGroups,
      RdManageEntry.extraFields => l10n.rdAdminExtraFields,
      RdManageEntry.registration => l10n.rdAdminRegistration,
      RdManageEntry.critical => l10n.rdAdminCritical,
      RdManageEntry.teachers => l10n.settingsTeachers,
      RdManageEntry.bulkMembers => l10n.redesignBulkTitle,
      RdManageEntry.missingAccounts => l10n.rdAdminMissing,
      RdManageEntry.archive => l10n.settingsArchive,
      RdManageEntry.rolesPermissions => l10n.rdAdminRoles,
      RdManageEntry.admins => l10n.rdAdminAdmins,
      RdManageEntry.parents => l10n.settingsParents,
      RdManageEntry.viewers => l10n.settingsViewers,
      RdManageEntry.attendanceTypes => l10n.rdAdminTypes,
      RdManageEntry.reasons => l10n.rdAdminReasons,
      RdManageEntry.shiftPlans => l10n.generalSettingsShiftPlans,
      RdManageEntry.holidays => l10n.rdAdminHolidays,
      RdManageEntry.adHocPlanning => l10n.rdAdminAdHoc,
      RdManageEntry.statistics => l10n.redesignStatsTitle,
      RdManageEntry.announcements => l10n.settingsAnnouncements,
      RdManageEntry.general => l10n.rdAdminName,
      RdManageEntry.organisation => l10n.settingsOrganisation,
      RdManageEntry.approvals => l10n.redesignManagePendingTitle,
      RdManageEntry.workHistory => l10n.rdAdminWorkHistory,
      RdManageEntry.workCategories => l10n.songsSongCategories,
      RdManageEntry.fileStorage => l10n.settingsFileStorage,
      RdManageEntry.sharing => l10n.rdAdminSharing,
      RdManageEntry.runSheets => l10n.settingsRunSheets,
      RdManageEntry.export => l10n.settingsExport,
      RdManageEntry.certificates => l10n.rdAdminCertificates,
      RdManageEntry.branding => l10n.generalSettingsBranding,
      RdManageEntry.planningTemplates => l10n.settingsTemplatesFields,
      RdManageEntry.orgPlans => l10n.plansOrgPlans,
      RdManageEntry.calendar => l10n.settingsSubscribeCalendar,
      RdManageEntry.team => l10n.rdAdminTeam,
    };

/// Second line of a row: what the entry is for (also searched).
String rdManageHint(AppLocalizations l10n, RdManageEntry entry, RdManageAccess access) => switch (entry) {
      RdManageEntry.groups => l10n.rdAdminGroupsHint,
      RdManageEntry.extraFields => l10n.rdAdminExtraFieldsHint,
      RdManageEntry.registration => l10n.rdAdminRegistrationHint,
      RdManageEntry.critical => l10n.rdAdminCriticalHint,
      RdManageEntry.teachers => l10n.rdAdminTeachersHint,
      RdManageEntry.bulkMembers => l10n.rdAdminBulkHint,
      RdManageEntry.missingAccounts => l10n.redesignManageMissingHint,
      RdManageEntry.archive => l10n.rdAdminArchiveHint,
      RdManageEntry.rolesPermissions => l10n.rdAdminRolesHint,
      RdManageEntry.admins => l10n.rdAdminAdminsHint,
      RdManageEntry.parents => l10n.rdAdminParentsHint,
      RdManageEntry.viewers => l10n.rdAdminViewersHint,
      RdManageEntry.attendanceTypes => l10n.rdAdminTypesHint,
      RdManageEntry.reasons => l10n.rdAdminReasonsHint,
      RdManageEntry.shiftPlans => l10n.rdAdminShiftsHint,
      RdManageEntry.holidays => l10n.rdAdminHolidaysHint,
      RdManageEntry.adHocPlanning => l10n.rdAdminAdHocHint,
      RdManageEntry.statistics => access.isVorkurs ? l10n.rdAdminStatsHintCertificates : l10n.rdAdminStatsHint,
      RdManageEntry.announcements => l10n.redesignManageAnnouncementsHint,
      RdManageEntry.general => l10n.rdAdminNameHint,
      RdManageEntry.organisation => l10n.rdAdminOrganisationHint,
      RdManageEntry.team => l10n.rdAdminTeamHint,
      RdManageEntry.export => l10n.rdAdminExportHint,
      RdManageEntry.certificates => l10n.rdAdminCertificatesHint,
      RdManageEntry.sharing => l10n.rdAdminSharingHint,
      _ => '',
    };

/// One sentence for "Noch nicht genutzt": what a feature that is off is for.
String rdManageUnusedText(AppLocalizations l10n, RdManageEntry entry) => switch (entry) {
      RdManageEntry.teachers => l10n.rdAdminUnusedTeachers,
      RdManageEntry.parents => l10n.rdAdminUnusedParents,
      RdManageEntry.sharing => l10n.rdAdminUnusedSharing,
      _ => rdManageHint(l10n, entry, const RdManageAccess()),
    };

/// The switches and values on the page an entry opens: found by the search
/// (e.g. "Saison" finds Auswertung, "Dienstplan" Rollen und Rechte) and
/// shown there next to the place.
List<String> rdManageKeywords(AppLocalizations l10n, RdManageEntry entry) => switch (entry) {
      RdManageEntry.registration => [
          l10n.rdSettingsAllowRegister,
          l10n.rdSettingsAutoApprove,
          l10n.rdSettingsRegisterFields,
        ],
      RdManageEntry.critical => [l10n.rdSettingsAddRule],
      RdManageEntry.teachers => [l10n.generalSettingsMaintainTeachers, l10n.redesignManageGeneralTitle],
      RdManageEntry.rolesPermissions => [
          l10n.redesignManageGeneralTitle,
          l10n.rdSettingsAllEvents,
          l10n.rdSettingsInfoText,
          l10n.rdSettingsDutyView,
          l10n.rdSettingsMembersList,
        ],
      RdManageEntry.parents => [l10n.generalSettingsParentsFeature, l10n.redesignManageGeneralTitle],
      RdManageEntry.reasons => [l10n.generalSettingsAbsenceReasons, l10n.generalSettingsLateReasons],
      RdManageEntry.holidays => [l10n.rdSettingsRegion],
      RdManageEntry.statistics => [
          l10n.redesignManageGeneralTitle,
          l10n.rdSettingsSeasonStart,
          l10n.rdSettingsShiftPresent,
        ],
      RdManageEntry.general => [l10n.rdSettingsName, l10n.rdSettingsShortName],
      RdManageEntry.sharing => [l10n.generalSettingsShareSongs, l10n.rdSettingsCopyWorksLink],
      _ => const [],
    };

/// The name the entry had on the old settings page, when it changed:
/// found by the search and shown there ("früher „Gruppen“").
String? rdManageFormerName(AppLocalizations l10n, RdManageEntry entry) => switch (entry) {
      RdManageEntry.groups => l10n.settingsGroups,
      RdManageEntry.extraFields => l10n.settingsExtraFields,
      RdManageEntry.missingAccounts => l10n.settingsCreateMissing,
      RdManageEntry.rolesPermissions => l10n.settingsRolesPerms,
      RdManageEntry.admins => l10n.settingsAdmins,
      RdManageEntry.attendanceTypes => l10n.generalSettingsAttTypes,
      RdManageEntry.adHocPlanning => l10n.settingsAdHocPlanning,
      RdManageEntry.workHistory => l10n.historyTitle,
      RdManageEntry.certificates => l10n.settingsCertificates,
      RdManageEntry.team => l10n.teamOrgTitle,
      // Split from the old "Allgemeine Einstellungen".
      RdManageEntry.general ||
      RdManageEntry.registration ||
      RdManageEntry.critical ||
      RdManageEntry.reasons ||
      RdManageEntry.holidays ||
      RdManageEntry.sharing =>
        l10n.redesignManageGeneralTitle,
      _ => null,
    };

/// Section of a row or the new place of a moved entry.
String rdManagePlace(AppLocalizations l10n, RdManageEntry entry, RdManageAccess access) {
  final area = rdManageAreaOf(entry, access);
  if (area != null) return rdManageAreaName(l10n, area);
  final home = rdManageHome(entry, access);
  return home == null ? '' : rdManageHomeName(l10n, home);
}

IconData rdManageIcon(RdManageEntry entry) => switch (entry) {
      RdManageEntry.groups => Icons.groups_outlined,
      RdManageEntry.extraFields => Icons.dynamic_form_outlined,
      RdManageEntry.registration => Icons.link,
      RdManageEntry.critical => Icons.warning_amber_rounded,
      RdManageEntry.teachers => Icons.school_outlined,
      RdManageEntry.bulkMembers => Icons.checklist,
      RdManageEntry.missingAccounts => Icons.person_add_alt_outlined,
      RdManageEntry.archive => Icons.archive_outlined,
      RdManageEntry.rolesPermissions => Icons.key_outlined,
      RdManageEntry.admins => Icons.verified_user_outlined,
      RdManageEntry.parents => Icons.favorite_border,
      RdManageEntry.viewers => Icons.visibility_outlined,
      RdManageEntry.attendanceTypes => Icons.category_outlined,
      RdManageEntry.reasons => Icons.edit_note,
      RdManageEntry.shiftPlans => Icons.schedule,
      RdManageEntry.holidays => Icons.beach_access_outlined,
      RdManageEntry.adHocPlanning => Icons.view_agenda_outlined,
      RdManageEntry.statistics => Icons.insert_chart_outlined,
      RdManageEntry.announcements => Icons.mail_outline,
      RdManageEntry.general => Icons.badge_outlined,
      RdManageEntry.organisation => Icons.business_outlined,
      RdManageEntry.approvals => Icons.how_to_reg_outlined,
      RdManageEntry.workHistory => Icons.history,
      RdManageEntry.workCategories => Icons.label_outline,
      RdManageEntry.fileStorage => Icons.folder_outlined,
      RdManageEntry.sharing => Icons.share_outlined,
      RdManageEntry.runSheets => Icons.list,
      RdManageEntry.export => Icons.download_outlined,
      RdManageEntry.certificates => Icons.workspace_premium_outlined,
      RdManageEntry.branding => Icons.palette_outlined,
      RdManageEntry.planningTemplates => Icons.description_outlined,
      RdManageEntry.orgPlans => Icons.business_outlined,
      RdManageEntry.calendar => Icons.calendar_month_outlined,
      RdManageEntry.team => Icons.supervised_user_circle_outlined,
    };

/// Opens [entry] (same pages, sheets and guards as the old settings page)
/// and remembers it for "Zuletzt geöffnet".
void rdOpenManageEntry(BuildContext context, WidgetRef ref, RdManageEntry entry) {
  ref.read(rdManageRecentProvider.notifier).push(entry);
  void push(String location) => context.push(location);
  switch (entry) {
    case RdManageEntry.groups:
      push(RedesignRoutes.groups);
    case RdManageEntry.extraFields:
      push(RedesignRoutes.extraFields);
    case RdManageEntry.registration:
      push(RedesignRoutes.registration);
    case RdManageEntry.critical:
      push(RedesignRoutes.critical);
    case RdManageEntry.teachers:
      push(RedesignRoutes.teachers);
    case RdManageEntry.bulkMembers:
      // Now "Auswählen" in the Mitglieder tab.
      ref.read(rdMembersSelectingProvider.notifier).state = true;
      context.go(RedesignRoutes.members);
    case RdManageEntry.missingAccounts:
      createMissingAccounts(context, ref, ref.read(rdMissingAccountsProvider));
    case RdManageEntry.archive:
      push(RedesignRoutes.archive);
    case RdManageEntry.rolesPermissions:
      push(RedesignRoutes.rolePermissions);
    case RdManageEntry.admins:
      push(RedesignRoutes.admins);
    case RdManageEntry.parents:
      push(RedesignRoutes.parents);
    case RdManageEntry.viewers:
      push(RedesignRoutes.viewers);
    case RdManageEntry.attendanceTypes:
      push(RedesignRoutes.attendanceTypes);
    case RdManageEntry.reasons:
      push(RedesignRoutes.reasons);
    case RdManageEntry.holidays:
      push(RedesignRoutes.holidays);
    case RdManageEntry.shiftPlans:
      push(RedesignRoutes.shiftPlans);
    case RdManageEntry.adHocPlanning:
      push('/settings/planung');
    case RdManageEntry.statistics:
      push(RedesignRoutes.stats);
    case RdManageEntry.announcements:
      push('/settings/messages');
    case RdManageEntry.general:
      push('/settings/general');
    case RdManageEntry.organisation:
      push('/settings/org-settings');
    case RdManageEntry.approvals:
      push(RedesignRoutes.approvals);
    case RdManageEntry.workHistory:
      showHistoryModal(context);
    case RdManageEntry.workCategories:
      showSongCategoriesSheet(context);
    case RdManageEntry.fileStorage:
      push('/settings/files');
    case RdManageEntry.sharing:
      showRdSharingSheet(context);
    case RdManageEntry.runSheets:
      push('/planning');
    case RdManageEntry.export:
      push('/export');
    case RdManageEntry.certificates:
      rdGenerateCertificates(context, ref);
    case RdManageEntry.branding:
      push('/settings/general/branding');
    case RdManageEntry.planningTemplates:
      push('/settings/org-settings/planning-templates');
    case RdManageEntry.orgPlans:
      push('/settings/org-plans');
    case RdManageEntry.calendar:
      showCalendarSubscriptionDialog(context, ref);
    case RdManageEntry.team:
      push(rdTeamRoute);
  }
}

/// Ich › Team (the old entries Teamorganisation, Meine Aufgaben, Themen
/// and Protokolle open the same page with its three tabs).
const rdTeamRoute = '/settings/team-organization?tab=tasks';
