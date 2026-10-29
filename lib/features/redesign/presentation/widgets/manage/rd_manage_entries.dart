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
import '../../../../../core/router/route_access.dart' show canOpenSongsTab;
import '../../../../../core/services/certificate_service.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../export/presentation/pages/export_page.dart' show showExportModal;
import '../../../../history/presentation/pages/history_page.dart' show showHistoryModal;
import '../../../../settings/presentation/pages/left_players_page.dart' show showArchiveSheet;
import '../../../../settings/presentation/pages/parents_page.dart' show showParentsSheet;
import '../../../../settings/presentation/pages/pending_players_page.dart'
    show showPendingPersonsSheet;
import '../../../../settings/presentation/pages/settings_page.dart'
    show createMissingAccounts, playersOfCurrentTenant;
import '../../../../settings/presentation/pages/viewers_page.dart' show showViewersSheet;
import '../../../../settings/presentation/widgets/calendar_subscription_dialog.dart';
import '../../../../settings/presentation/widgets/settings_admins_sheet.dart';
import '../../../../settings/presentation/widgets/vorkurs_certificates.dart';
import '../../../../songs/presentation/widgets/song_categories_sheet.dart';
import '../../../../statistics/presentation/pages/statistics_page.dart' show showStatisticsModal;
import '../../../data/rd_manage_logic.dart';

/// REDESIGN: titles, icons and actions of the Verwaltung entries. Every entry
/// opens what the old settings page opens (same pages, sheets and guards);
/// the Verwaltung only sorts them into six areas.

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
  final tenant = ref.watch(currentTenantProvider);
  final isAdmin = role.isAdmin || role.isResponsible;
  final teamOrgEnabled = ref.watch(teamOrgEnabledProvider);
  final isTeamLeader = ref.watch(isTeamLeaderProvider);
  final hasOwnTasks = teamOrgEnabled &&
      !isTeamLeader &&
      (ref.watch(myTasksProvider).valueOrNull?.isNotEmpty ?? false);
  return RdManageAccess(
    isAdmin: isAdmin,
    isSuperAdmin: role.isAdmin,
    isHelper: role.isHelperRole,
    isApplicant: role.isApplicant,
    isVoiceLeader: role.canSeeVoiceLeaderSettings,
    canOpenWorks: canOpenSongsTab(role),
    isGeneral: tenant?.type == 'general',
    isDemo: ref.watch(isDemoProvider),
    parentsEnabled: tenant?.parents == true,
    maintainTeachers: tenant?.maintainTeachers == true,
    canAccessFiles: ref.watch(canAccessFilesProvider),
    hasOrganisation: isAdmin && ref.watch(currentOrganisationProvider).valueOrNull != null,
    hasPending: ref.watch(rdManagePendingProvider).isNotEmpty,
    hasMissingAccounts: ref.watch(rdMissingAccountsProvider).isNotEmpty,
    isVorkurs: isVorkursTenantName(tenant?.shortName, tenant?.longName),
    teamOrgEnabled: teamOrgEnabled,
    isTeamLeader: isTeamLeader,
    inTeamCircle: ref.watch(inTeamCircleProvider),
    hasOwnTasks: hasOwnTasks,
  );
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
      RdManageArea.members => l10n.redesignManageAreaMembers,
      RdManageArea.events => l10n.redesignManageAreaEvents,
      RdManageArea.works => l10n.redesignManageAreaWorks,
      RdManageArea.data => l10n.redesignManageAreaData,
      RdManageArea.communication => l10n.redesignManageAreaCommunication,
      RdManageArea.group => l10n.redesignManageAreaGroup,
    };

IconData rdManageAreaIcon(RdManageArea area) => switch (area) {
      RdManageArea.members => Icons.people_alt_outlined,
      RdManageArea.events => Icons.event_note_outlined,
      RdManageArea.works => Icons.library_music_outlined,
      RdManageArea.data => Icons.insert_chart_outlined,
      RdManageArea.communication => Icons.campaign_outlined,
      RdManageArea.group => Icons.tune,
    };

String rdManageTitle(AppLocalizations l10n, RdManageEntry entry) => switch (entry) {
      RdManageEntry.approvals => l10n.redesignManagePendingTitle,
      RdManageEntry.rolesPermissions => l10n.settingsRolesPerms,
      RdManageEntry.admins => l10n.settingsAdmins,
      RdManageEntry.parents => l10n.settingsParents,
      RdManageEntry.viewers => l10n.settingsViewers,
      RdManageEntry.teachers => l10n.settingsTeachers,
      RdManageEntry.missingAccounts => l10n.settingsCreateMissing,
      RdManageEntry.archive => l10n.settingsArchive,
      RdManageEntry.myVoice => l10n.settingsMyVoice,
      RdManageEntry.attendanceTypes => l10n.generalSettingsAttTypes,
      RdManageEntry.shiftPlans => l10n.generalSettingsShiftPlans,
      RdManageEntry.extraFields => l10n.settingsExtraFields,
      RdManageEntry.runSheets => l10n.settingsRunSheets,
      RdManageEntry.adHocPlanning => l10n.settingsAdHocPlanning,
      RdManageEntry.planningTemplates => l10n.settingsTemplatesFields,
      RdManageEntry.works => l10n.settingsSongs,
      RdManageEntry.workHistory => l10n.historyTitle,
      RdManageEntry.workCategories => l10n.songsSongCategories,
      RdManageEntry.groups => l10n.settingsGroups,
      RdManageEntry.fileStorage => l10n.settingsFileStorage,
      RdManageEntry.statistics => l10n.statsTitle,
      RdManageEntry.export => l10n.settingsExport,
      RdManageEntry.certificates => l10n.settingsCertificates,
      RdManageEntry.calendar => l10n.settingsSubscribeCalendar,
      RdManageEntry.announcements => l10n.settingsAnnouncements,
      RdManageEntry.teamOrg => l10n.teamOrgTitle,
      RdManageEntry.myTasks => l10n.tasksMyTasks,
      RdManageEntry.suggestTopic => l10n.teamOrgSuggestTopic,
      RdManageEntry.protocols => l10n.teamOrgTabProtocols,
      RdManageEntry.general => l10n.redesignManageGeneralTitle,
      RdManageEntry.branding => l10n.generalSettingsBranding,
      RdManageEntry.dashboard => l10n.settingsConfigureDashboard,
      RdManageEntry.organisation => l10n.settingsOrganisation,
    };

/// Second line of a few entries (also searched).
String rdManageHint(AppLocalizations l10n, RdManageEntry entry) => switch (entry) {
      RdManageEntry.general => l10n.redesignManageGeneralHint,
      RdManageEntry.announcements => l10n.settingsMessageAll,
      RdManageEntry.missingAccounts => l10n.redesignManageMissingHint,
      _ => '',
    };

IconData rdManageIcon(RdManageEntry entry) => switch (entry) {
      RdManageEntry.approvals => Icons.how_to_reg_outlined,
      RdManageEntry.rolesPermissions => Icons.key_outlined,
      RdManageEntry.admins => Icons.verified_user_outlined,
      RdManageEntry.parents => Icons.favorite_border,
      RdManageEntry.viewers => Icons.visibility_outlined,
      RdManageEntry.teachers => Icons.school_outlined,
      RdManageEntry.missingAccounts => Icons.person_add_alt_outlined,
      RdManageEntry.archive => Icons.archive_outlined,
      RdManageEntry.myVoice => Icons.people_outline,
      RdManageEntry.attendanceTypes => Icons.category_outlined,
      RdManageEntry.shiftPlans => Icons.schedule,
      RdManageEntry.extraFields => Icons.dynamic_form_outlined,
      RdManageEntry.runSheets => Icons.list,
      RdManageEntry.adHocPlanning => Icons.calendar_today_outlined,
      RdManageEntry.planningTemplates => Icons.description_outlined,
      RdManageEntry.works => Icons.music_note_outlined,
      RdManageEntry.workHistory => Icons.history,
      RdManageEntry.workCategories => Icons.label_outline,
      RdManageEntry.groups => Icons.groups_outlined,
      RdManageEntry.fileStorage => Icons.folder_outlined,
      RdManageEntry.statistics => Icons.insert_chart_outlined,
      RdManageEntry.export => Icons.download_outlined,
      RdManageEntry.certificates => Icons.workspace_premium_outlined,
      RdManageEntry.calendar => Icons.calendar_month_outlined,
      RdManageEntry.announcements => Icons.mail_outline,
      RdManageEntry.teamOrg => Icons.supervised_user_circle_outlined,
      RdManageEntry.myTasks => Icons.check_circle_outline,
      RdManageEntry.suggestTopic => Icons.lightbulb_outline,
      RdManageEntry.protocols => Icons.description_outlined,
      RdManageEntry.general => Icons.settings_outlined,
      RdManageEntry.branding => Icons.palette_outlined,
      RdManageEntry.dashboard => Icons.grid_view_outlined,
      RdManageEntry.organisation => Icons.business_outlined,
    };

/// Opens [entry] like the old settings page and remembers it.
void rdOpenManageEntry(BuildContext context, WidgetRef ref, RdManageEntry entry) {
  ref.read(rdManageRecentProvider.notifier).push(entry);
  void push(String location) => context.push(location);
  switch (entry) {
    case RdManageEntry.approvals:
      showPendingPersonsSheet(context);
    case RdManageEntry.rolesPermissions:
      push('/settings/role-permissions');
    case RdManageEntry.admins:
      showAdminsSheet(context);
    case RdManageEntry.parents:
      showParentsSheet(context);
    case RdManageEntry.viewers:
      showViewersSheet(context);
    case RdManageEntry.teachers:
      push('/settings/teachers');
    case RdManageEntry.missingAccounts:
      createMissingAccounts(context, ref, ref.read(rdMissingAccountsProvider));
    case RdManageEntry.archive:
      showArchiveSheet(context);
    case RdManageEntry.myVoice:
      push('/settings/voice-leader');
    case RdManageEntry.attendanceTypes:
      push('/settings/types');
    case RdManageEntry.shiftPlans:
      push('/settings/shifts');
    case RdManageEntry.extraFields:
      push('/settings/general/extra-fields');
    case RdManageEntry.runSheets:
      push('/planning');
    case RdManageEntry.adHocPlanning:
      push('/settings/planung');
    case RdManageEntry.planningTemplates:
      push('/settings/org-settings/planning-templates');
    case RdManageEntry.works:
      context.go(RedesignRoutes.works);
    case RdManageEntry.workHistory:
      showHistoryModal(context);
    case RdManageEntry.workCategories:
      showSongCategoriesSheet(context);
    case RdManageEntry.groups:
      push('/settings/instruments');
    case RdManageEntry.fileStorage:
      push('/settings/files');
    case RdManageEntry.statistics:
      showStatisticsModal(context);
    case RdManageEntry.export:
      showExportModal(context);
    case RdManageEntry.certificates:
      generateVorkursCertificates(context, ref);
    case RdManageEntry.calendar:
      showCalendarSubscriptionDialog(context, ref);
    case RdManageEntry.announcements:
      push('/settings/messages');
    case RdManageEntry.teamOrg || RdManageEntry.myTasks:
      push('/settings/team-organization?tab=tasks');
    case RdManageEntry.suggestTopic:
      push('/settings/team-organization?tab=topics');
    case RdManageEntry.protocols:
      push('/settings/team-organization?tab=protocols');
    case RdManageEntry.general:
      push('/settings/general');
    case RdManageEntry.branding:
      push('/settings/general/branding');
    case RdManageEntry.dashboard:
      push('/settings/dashboard');
    case RdManageEntry.organisation:
      push('/settings/org-settings');
  }
}
