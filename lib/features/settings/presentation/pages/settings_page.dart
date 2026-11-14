import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/shorebird_providers.dart';
import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/parent_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/viewer_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/sheets/feedback_sheet.dart';
import '../../../../shared/widgets/tenant/tenant_switcher_title.dart';
import '../../../planning/presentation/pages/planning_page.dart' show openPlanningEditor;
import '../../../profile/presentation/widgets/account_dialogs.dart';
import '../../../profile/presentation/widgets/profile_hero_card.dart';
import '../../../../shared/widgets/sheets/version_history_sheet.dart';
import '../../../messages/presentation/widgets/notification_bell.dart';
import '../../../../core/services/certificate_service.dart';
import '../widgets/vorkurs_certificates.dart';
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/services/app_update_service.dart';
import '../widgets/app_promo_card.dart';
import '../../../assistant/presentation/widgets/assistant_entry_card.dart';
import '../widgets/settings_admins_sheet.dart';
import '../widgets/calendar_subscription_dialog.dart';
import '../widgets/settings_list.dart';
import 'left_players_page.dart' show leftPlayersProvider, showArchiveSheet;
// IOS_SETTINGS2: Ionic inline ion-modal sheets + "Fehlende Accounts erstellen"
import 'pending_players_page.dart' show showPendingPersonsSheet;
import 'parents_page.dart' show showParentsSheet;
import 'viewers_page.dart' show showViewersSheet;
import '../../../tenant_selection/presentation/pages/tenant_selection_page.dart'
    show showTenantsSheet;
import '../../../../core/providers/user_registration_providers.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/providers/demo_providers.dart'; // DEMO_GUARD
import '../../../../l10n/l10n.dart';
import '../widgets/language_picker_tile.dart';
import '../widgets/redesign_beta_tile.dart';
import '../../../../core/providers/push_providers.dart';
import '../../../../shared/widgets/layout/ios_tab_bar.dart';
import '../../../../shared/widgets/layout/side_nav/side_nav_layout.dart';
import '../../../history/presentation/pages/history_page.dart' show showHistoryModal;
import '../../../statistics/presentation/pages/statistics_page.dart' show showStatisticsModal;
import '../../../export/presentation/pages/export_page.dart' show showExportModal;
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonTranslucentAppBar, IonContentTopInset, IonRefresher;

/// "Mehr" tab — UX_SETTINGS: same sections, order and role visibility as the
/// Ionic settings page (src/app/settings/settings/settings.page.html):
/// App-Hinweis, ausstehende Registrierungen, Meine Stammdaten, Stimmführer,
/// Instanz-Verwaltung, Kommunikation, Benutzer & Rollen, Werke & Proben
/// (bzw. Dateien), Planung, Organisation, Auswertung & Daten, System.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    // Use effectiveRoleProvider to support debug role override
    final role = ref.watch(effectiveRoleProvider);

    // Ionic role flags (settings.page.ts)
    final isAdmin = role.isAdmin || role.isResponsible;
    final isSuperAdmin = role.isAdmin;
    final isHelper = role.isHelperRole;
    final isApplicant = role.isApplicant;
    final isVoiceLeader = role.canSeeVoiceLeaderSettings;
    final isGeneral = tenant?.type == 'general';
    final parentsEnabled = tenant?.parents == true;
    final canAccessFiles = ref.watch(canAccessFilesProvider);
    final isSuperDeveloper = ref.watch(isSuperDeveloperProvider);
    final isDemo = ref.watch(isDemoProvider); // DEMO_GUARD

    // MEDIA_REALTIME: live pending card (Ionic `pending-player-changes` channel)
    final pendingCount =
        isAdmin ? (ref.watch(realtimePendingPlayersProvider).valueOrNull?.length ?? 0) : 0;
    // Ionic getPlayersWithoutAccount: not pending, not left, e-mail, no appId
    // SOL_FIX13: only a settled list of the current tenant (during a tenant
    // switch `valueOrNull` may still hold the previous tenant's persons).
    final playersWithoutAccount = isAdmin
        ? playersOfCurrentTenant(
                ref.watch(playersProvider), ref.watch(currentTenantIdProvider))
            .where((p) =>
                (p.appId == null || p.appId!.isEmpty) &&
                !p.pending &&
                p.left == null &&
                (p.email ?? '').trim().isNotEmpty)
            .toList()
        : const <Person>[];

    // Planung (inkl. Teamorganisation)
    final showPlanning = isAdmin && !isApplicant;
    final teamOrgEnabled = ref.watch(teamOrgEnabledProvider);
    final isTeamLeader = ref.watch(isTeamLeaderProvider);
    final inTeamCircle = ref.watch(inTeamCircleProvider);
    final hasOwnTasks = teamOrgEnabled &&
        !isTeamLeader &&
        (ref.watch(myTasksProvider).valueOrNull?.isNotEmpty ?? false);
    final showTeam = teamOrgEnabled && (isTeamLeader || inTeamCircle || hasOwnTasks);
    final org = isAdmin ? ref.watch(currentOrganisationProvider).valueOrNull : null;

    void openTeamOrg(String tab) => context.push('/settings/team-organization?tab=$tab');

    final ios = ionIsIos(context);
    // SIDE_NAV (Ionic 4.19.0 `sp`): with the side panel (tablet/desktop)
    // every entry the panel already shows is left out here.
    final sp = SideNavScope.isActive(context);
    // IOS_SETTINGS2: Ionic `isInstancesModalOpen = true` (sheet, not a page).
    void openTenants() => showTenantsSheet(context);

    return Scaffold(
      // IOS_R6: Ionic `ion-content fullscreen` under the
      // `ion-header translucent` (no large title: always blurred)
      extendBodyBehindAppBar: ios,
      appBar: IonTranslucentAppBar(child: AppBar(
        // Ionic: tenant switcher (long name + chevron) in `ion-buttons
        // slot="start"`. iOS: left aligned glass button, no title (with
        // several tenants TenantSwitcherTitle draws the capsule itself,
        // UX_AUTH); elsewhere UX_AUTH alignment.
        // AUDIT_R4: md `ion-toolbar color="light"` – the page colour
        // (#f4f5f8; dark --ion-color-light #222428), not white.
        backgroundColor: ios
            ? null
            : (Theme.of(context).brightness == Brightness.dark
                ? AppColors.iosPageDark
                : AppColors.light),
        // SIDE_NAV: the menu button of the overlay panel (tablet portrait).
        leading: SideNavMenuButton.maybe(context),
        centerTitle: sp ? null : (ios ? false : TenantSwitcherTitle.centerTitle(ref)),
        titleSpacing: ios && !sp ? 12 : null,
        // SIDE_NAV: with the side panel the instance switcher sits there.
        title: sp
            ? Text(l10n.settingsSettings)
            : ios && TenantSwitcherTitle.centerTitle(ref) == null
                ? IonHeaderPill(child: TenantSwitcherTitle(fallbackTitle: l10n.settingsSettings))
                : TenantSwitcherTitle(fallbackTitle: l10n.settingsSettings),
        // IOS_SHELL: iOS → bell in a glass circle
        actions: const [ToolbarButtonGroup(children: [NotificationBell()])],
      )),
      // Ionic: `@if (isIos)` ion-fab (apps-outline) opens the instance list.
      // IOS_SHELL: rendered in the tab bar row (right of the floating bar).
      floatingActionButton: ios
          ? TabBarFab(
              child: FloatingActionButton(
                heroTag: 'settingsTenantsFab',
                onPressed: openTenants,
                tooltip: l10n.settingsSwitchTenant,
                child: Icon(AppIcons.cupertinoCircleGrid3x3), // apps-outline
              ),
            )
          : null,
      body: IonRefresher(
        onRefresh: () async {
          ref.invalidate(currentTenantProvider);
          ref.invalidate(userTenantsProvider);
          ref.invalidate(pendingPlayersProvider);
          ref.invalidate(realtimePendingPlayersProvider);
          ref.invalidate(playersProvider);
          ref.invalidate(viewersProvider);
          ref.invalidate(parentsProvider);
          ref.invalidate(adminsProvider);
          ref.invalidate(leftPlayersProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // iOS: inset lists 20pt from the edges (ios26 insetGrouped,
          // IOS_SETTINGS2), hero card margin-top 12; the ion-fab sits in the
          // tab bar row, the list ends above the floating tab bar (IOS_SHELL2).
          padding: ios
              ? EdgeInsets.fromLTRB(IonIos.insetMargin, 12, IonIos.insetMargin,
                  scrollEndPadding(context, base: 16))
              : EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM,
                  AppDimensions.paddingM,
                  scrollEndPadding(context, base: AppDimensions.paddingM)),
          children: [
            const IonContentTopInset(),
            // IOS_SETTINGS2: no Flutter-only PWA install hint here — Ionic
            // only shows its "Attendix als App" promo card.
            const AppPromoCard(), // SETTINGS2: "📱 Attendix als App"

            // Ionic: pending persons alert card (warning)
            if (pendingCount > 0) _PendingPersonsCard(count: pendingCount),

            // PROFILE_OFFLINE: profile card ("Meine Stammdaten")
            const ProfileHeroCard(),

            // Chat-Assistent: coloured card right under the profile.
            const AssistantEntryCard(margin: EdgeInsets.only(top: 12, bottom: 4)),

            // ============ STIMMFÜHRER ============
            if (isVoiceLeader && !isGeneral && !sp)
              SettingsListSection(
                icon: AppIcons.cupertinoMusicNote2, // musical-notes-outline
                title: l10n.settingsVoiceLeader,
                children: [
                  SettingsListTile(
                    icon: AppIcons.peopleOutline,
                    title: l10n.settingsMyVoice,
                    onTap: () => context.push('/settings/voice-leader'),
                  ),
                ],
              ),

            // ============ INSTANZ-VERWALTUNG ============
            if (isAdmin)
              SettingsListSection(
                icon: AppIcons.businessOutlined,
                title: l10n.settingsTenantAdmin,
                children: [
                  SettingsListTile(
                    icon: AppIcons.settingsOutlined,
                    title: l10n.settingsSettings,
                    onTap: () => context.push('/settings/general'),
                  ),
                  SettingsListTile(
                    icon: AppIcons.peopleOutline,
                    title: l10n.settingsGroups,
                    onTap: () => context.push('/settings/instruments'),
                  ),
                  if (tenant?.maintainTeachers == true)
                    SettingsListTile(
                      icon: AppIcons.schoolOutlined,
                      title: l10n.settingsTeachers,
                      onTap: () => context.push('/settings/teachers'),
                    ),
                  SettingsListTile(
                    icon: AppIcons.keyOutlined,
                    title: l10n.settingsRolesPerms,
                    onTap: () => context.push('/settings/role-permissions'),
                  ),
                  SettingsListTile(
                    icon: AppIcons.gridViewOutlined,
                    title: l10n.settingsConfigureDashboard,
                    onTap: () => context.push('/settings/dashboard'),
                  ),
                ],
              ),

            // ============ KOMMUNIKATION ============
            if (isAdmin && !sp)
              SettingsListSection(
                icon: AppIcons.campaignOutlined,
                title: l10n.settingsCommunication,
                children: [
                  SettingsListTile(
                    icon: AppIcons.mailOutline,
                    title: l10n.settingsAnnouncements,
                    subtitle: l10n.settingsMessagesHint,
                    onTap: () => context.push('/settings/messages'),
                  ),
                ],
              ),

            // ============ BENUTZER & ROLLEN ============
            if (isAdmin)
              SettingsListSection(
                icon: AppIcons.supervisedUserCircleOutlined,
                title: l10n.settingsUsersRoles,
                children: [
                  if (!isDemo && isSuperAdmin)
                    SettingsListTile(
                      icon: AppIcons.verifiedUserOutlined,
                      title: l10n.settingsAdmins,
                      detail: false,
                      trailing: SettingsCountBadge(ref.watch(adminsProvider).valueOrNull?.length ?? 0),
                      onTap: () => showAdminsSheet(context),
                    ),
                  if (parentsEnabled)
                    SettingsListTile(
                      icon: AppIcons.favoriteBorder,
                      title: l10n.settingsParents,
                      detail: false,
                      trailing: SettingsCountBadge(ref.watch(parentsProvider).valueOrNull?.length ?? 0),
                      onTap: () => showParentsSheet(context),
                    ),
                  SettingsListTile(
                    icon: AppIcons.visibilityOutlined,
                    title: l10n.settingsViewers,
                    detail: false,
                    trailing: SettingsCountBadge(ref.watch(viewersProvider).valueOrNull?.length ?? 0),
                    onTap: () => showViewersSheet(context),
                  ),
                  // IOS_SETTINGS2: no Flutter-only "Benutzerverwaltung" row —
                  // Ionic manages account roles on the person page.
                  if (playersWithoutAccount.isNotEmpty)
                    SettingsListTile(
                      icon: AppIcons.personAddAltOutlined,
                      iconColor: AppColors.warning,
                      title: l10n.settingsCreateMissing,
                      detail: false,
                      trailing: SettingsCountBadge(playersWithoutAccount.length, color: AppColors.warning),
                      onTap: () => createMissingAccounts(context, ref, playersWithoutAccount),
                    ),
                ],
              ),

            // ============ WERKE & PROBEN ============
            if (!isGeneral && !isApplicant && (!sp || isAdmin || isHelper))
              SettingsListSection(
                icon: AppIcons.cupertinoMusicNote2, // musical-notes-outline
                title: l10n.settingsSongsRehearsals,
                children: [
                  if (!sp)
                    SettingsListTile(
                      // Ionic library-outline: books on a shelf.
                      iconWidget: const IonLibraryOutlineIcon(),
                      title: l10n.settingsSongs,
                      onTap: () => context.push('/settings/songs'),
                    ),
                  if (isAdmin || isHelper)
                    SettingsListTile(
                      icon: AppIcons.schedule,
                      title: l10n.historyTitle,
                      detail: false,
                      // IOS_FORMS2: Ionic modal (iOS card sheet)
                      onTap: () => showHistoryModal(context),
                    ),
                  if (canAccessFiles && !sp)
                    SettingsListTile(
                      icon: AppIcons.folderOutlined,
                      title: l10n.settingsFileStorage,
                      onTap: () => context.push('/settings/files'),
                    ),
                ],
              ),

            // Allgemeine Instanzen: Dateiablage steht allein
            if (isGeneral && canAccessFiles && !sp)
              SettingsListSection(
                icon: AppIcons.folderOutlined,
                title: l10n.settingsFiles,
                children: [
                  SettingsListTile(
                    icon: AppIcons.folderOutlined,
                    title: l10n.settingsFileStorage,
                    onTap: () => context.push('/settings/files'),
                  ),
                ],
              ),

            // ============ PLANUNG (inkl. Teamorganisation) ============
            if (showPlanning || showTeam)
              SettingsListSection(
                icon: AppIcons.list,
                title: l10n.settingsPlanning,
                children: [
                  if (showPlanning) ...[
                    if (!sp)
                      SettingsListTile(
                        icon: AppIcons.list,
                        title: l10n.settingsRunSheets,
                        detail: false,
                        // F-ABL-01: classic opens the Ionic modal (no tab bar), Beta keeps its route.
                        onTap: () => openPlanningEditor(context),
                      ),
                    SettingsListTile(
                      icon: AppIcons.calendarTodayOutlined,
                      title: l10n.settingsAdHocPlanning,
                      detail: false,
                      onTap: () => context.push('/settings/planung'),
                    ),
                    if (org != null)
                      SettingsListTile(
                        icon: AppIcons.descriptionOutlined,
                        title: l10n.settingsTemplatesFields,
                        detail: false,
                        onTap: () => context.push('/settings/org-settings/planning-templates'),
                      ),
                  ],
                  if (showTeam) ...[
                    if (isTeamLeader)
                      SettingsListTile(
                        icon: AppIcons.supervisedUserCircleOutlined,
                        title: l10n.teamOrgTitle,
                        detail: false,
                        onTap: () => openTeamOrg('tasks'),
                      )
                    else ...[
                      SettingsListTile(
                        icon: AppIcons.checkCircleOutline,
                        title: l10n.tasksMyTasks,
                        detail: false,
                        onTap: () => openTeamOrg('tasks'),
                      ),
                      if (inTeamCircle) ...[
                        SettingsListTile(
                          icon: AppIcons.lightbulbOutline,
                          title: l10n.teamOrgSuggestTopic,
                          detail: false,
                          onTap: () => openTeamOrg('topics'),
                        ),
                        SettingsListTile(
                          icon: AppIcons.descriptionOutlined,
                          title: l10n.teamOrgTabProtocols,
                          detail: false,
                          onTap: () => openTeamOrg('protocols'),
                        ),
                      ],
                    ],
                  ],
                ],
              ),

            // ============ ORGANISATION ============
            if (isAdmin)
              SettingsListSection(
                icon: AppIcons.businessOutlined,
                title: l10n.settingsOrganisation,
                children: [
                  SettingsListTile(
                    icon: AppIcons.settingsOutlined,
                    title: org?.name ?? l10n.settingsOrganisation,
                    trailing: org == null ? IonNote(l10n.settingsNotLinked) : null,
                    onTap: () => context.push('/settings/org-settings'),
                  ),
                ],
              ),

            // ============ AUSWERTUNG & DATEN ============
            if (!isApplicant)
              SettingsListSection(
                icon: AppIcons.leaderboardOutlined, // bar-chart-outline
                title: l10n.settingsAnalyticsData,
                children: [
                  SettingsListTile(
                    icon: AppIcons.calendarTodayOutlined,
                    title: l10n.settingsSubscribeCalendar,
                    detail: false,
                    onTap: () => showCalendarSubscriptionDialog(context, ref),
                  ),
                  if (isAdmin) ...[
                    if (!sp)
                      SettingsListTile(
                        icon: AppIcons.insertChartOutlined,
                        title: l10n.statsTitle,
                        detail: false,
                        onTap: () => showStatisticsModal(context), // PARITY_R5: modal like Ionic
                      ),
                    SettingsListTile(
                      icon: AppIcons.downloadOutlined,
                      title: l10n.settingsExport,
                      detail: false,
                      onTap: () => showExportModal(context), // PARITY_R5: modal like Ionic
                    ),
                    // MISC2: Urkunden generieren (Vorkurs tenants only)
                    if (isVorkursTenantName(tenant?.shortName, tenant?.longName))
                      SettingsListTile(
                        icon: AppIcons.workspacePremiumOutlined,
                        title: l10n.settingsCertificates,
                        detail: false,
                        onTap: () => generateVorkursCertificates(context, ref),
                      ),
                    Builder(builder: (context) {
                      final left = ref.watch(leftPlayersProvider).valueOrNull?.length ?? 0;
                      return SettingsListTile(
                        icon: AppIcons.archiveOutlined,
                        title: l10n.settingsArchive,
                        detail: false,
                        trailing: left > 0 ? SettingsCountBadge(left) : null,
                        onTap: () => showArchiveSheet(context),
                      );
                    }),
                  ],
                ],
              ),

            // IOS_SETTINGS2: no Flutter-only applicant hint card (Ionic has
            // none on the settings page).

            // ============ SYSTEM ============
            SettingsListSection(
              icon: AppIcons.settingsOutlined,
              title: l10n.settingsSystem,
              // Ionic .delete-account-link: transparent, margin-top 24,
              // 13px, opacity .55, centered + underlined. It sits inside the
              // ion-list below the item group; on iOS global.scss gives the
              // group margin-bottom 16 → 40pt gap below the logout card.
              footer: Padding(
                padding: EdgeInsets.only(top: ios ? 40 : 24),
                child: Center(
                  child: InkWell(
                    onTap: () => context.push('/settings/delete-account'),
                    child: Opacity(
                      opacity: 0.55,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          l10n.settingsDeleteAccount,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              children: [
                SettingsListTile(
                  // Ionic apps-outline: 3×3 grid of round dots.
                  icon: AppIcons.cupertinoCircleGrid3x3,
                  title: l10n.settingsSwitchTenant,
                  subtitle: tenant?.longName,
                  detail: false,
                  onTap: openTenants,
                ),
                const LanguagePickerTile(),
                const RedesignBetaTile(),
                // ROLLEN-B-57: Ionic blocks the notifications page for
                // viewers / parents / applicants (Utils.isUrlAccessAllowed).
                if (role.canSeeNotifications)
                  SettingsListTile(
                    icon: AppIcons.notificationsOutlined,
                    title: l10n.settingsNotifications,
                    onTap: () => context.push('/settings/notifications'),
                  ),
                SettingsListTile(
                  icon: AppIcons.keyOutlined,
                  title: l10n.settingsChangePassword,
                  detail: false,
                  onTap: () => showChangePasswordDialog(context),
                ),
                // Ionic offers no "E-Mail ändern" here (nor anywhere else),
                // so the Mehr tab shows only "Passwort ändern".
                // LEGAL_HELP: help center (SIDE_NAV: in the panel)
                if (!sp)
                  SettingsListTile(
                    icon: AppIcons.helpOutline,
                    title: l10n.settingsHelp,
                    onTap: () => context.push('/settings/help'),
                  ),
                SettingsListTile(
                  // Ionic chatbubble-ellipses-outline (bubble with dots).
                  icon: AppIcons.smsOutlined,
                  title: l10n.settingsGiveFeedback,
                  detail: false,
                  onTap: () => showFeedbackSheet(context),
                ),
                SettingsListTile(
                  icon: AppIcons.autoAwesomeOutlined,
                  title: l10n.settingsWhatsNew,
                  detail: false,
                  // SHOREBIRD: "5.0.0 (Patch 2)" while a code push patch runs
                  trailing: IonBadge(text: ref.watch(appVersionLabelProvider)),
                  onTap: () => showVersionHistorySheet(context),
                ),
                // NATIVE_MISC: Ionic liveUpdate.updateAvailable() → "Update installieren"
                if (ref.watch(appUpdateAvailableProvider))
                  SettingsListTile(
                    icon: AppIcons.cloudDownloadOutlined,
                    title: l10n.settingsInstallUpdate,
                    detail: false,
                    color: AppColors.success,
                    iconColor: AppColors.success,
                    onTap: () => ref.read(appUpdateServiceProvider).applyUpdate(),
                  ),
                if (isSuperDeveloper)
                  SettingsListTile(
                    icon: AppIcons.constructionOutlined,
                    title: l10n.adminTitle,
                    onTap: () => context.push('/settings/administration'),
                  ),
                // Ionic: red `ion-item color="danger" button` row. IOS_R4: no
                // detail="false" → iOS shows the faint detail chevron
                // (--detail-icon-color: initial = white, opacity .25).
                // SIDE_NAV: in the panel's foot.
                if (!sp)
                SettingsListTile(
                  icon: AppIcons.logout,
                  title: l10n.settingsLogout,
                  detail: ionIsIos(context),
                  background: AppColors.danger,
                  onTap: () async {
                    // Ionic logs out directly (no confirmation)
                    final supabase = ref.read(supabaseClientProvider);
                    final tenantNotifier = ref.read(currentTenantProvider.notifier);
                    await removePushTokenBeforeSignOut(ref);
                    await signOutAndClearTenant(
                      signOut: supabase.auth.signOut,
                      clearTenant: tenantNotifier.clearTenant,
                    );
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingL),
          ],
        ),
      ),
    );
  }
}

/// Ionic `ion-card color="warning"` "X ausstehende Registrierung(en)".
class _PendingPersonsCard extends StatelessWidget {
  const _PendingPersonsCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: IonCardBox(
        color: AppColors.warning,
        onTap: () => showPendingPersonsSheet(context),
        child: Padding(
            padding: EdgeInsets.all(ionIsIos(context) ? 20 : AppDimensions.paddingM),
            child: Row(
              children: [
                Icon(AppIcons.personAdd, size: 32, color: Colors.black87),
                const SizedBox(width: AppDimensions.paddingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.settingsPendingCount(count),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.settingsWaitingApproval,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }
}

/// SOL_FIX13: the persons of [players] only while the list is settled
/// (not loading / refreshing, no error) and every entry belongs to
/// [tenantId]; otherwise empty (e.g. the previous tenant's list during a
/// tenant switch).
List<Person> playersOfCurrentTenant(AsyncValue<List<Person>> players, int? tenantId) {
  if (tenantId == null || players.isLoading || players.hasError) return const [];
  final list = players.valueOrNull ?? const <Person>[];
  if (list.any((p) => p.tenantId != tenantId)) return const [];
  return list;
}

/// IOS_SETTINGS2: Ionic `showAlertForAccountsCreation()` + `createAccounts()`:
/// confirm alert listing all names ("Accounts erstellen" / "Fortfahren"),
/// loading overlay, then one account after another (attendix-user Edge
/// Function via [AccountCreationNotifier]); the first failure stops the run
/// with "Fehler beim Erstellen der Accounts", otherwise "Accounts erstellt".
///
/// SOL_FIX13: the tenant is captured before the first await; the job only
/// runs when every person belongs to it, and the notifier refuses to start
/// when its repository is bound to another tenant by then.
Future<void> createMissingAccounts(
  BuildContext context,
  WidgetRef ref,
  List<Person> players,
) async {
  final l10n = context.l10n;
  final tenantId = ref.read(currentTenantIdProvider);
  if (tenantId == null || players.any((p) => p.tenantId != tenantId)) {
    ToastHelper.showError(context,
        l10n.settingsCreateAccountsFailed(l10n.coreFlutterRepoPersonsNotInTenant));
    return;
  }
  final confirmed = await DialogHelper.showConfirmation(
    context,
    title: l10n.settingsCreateAccounts,
    message: l10n.settingsCreateAccountsMessage(
        players.map((p) => '${p.firstName} ${p.lastName}').join(', ')),
    confirmText: l10n.settingsContinue,
    cancelText: l10n.commonCancel,
  );
  if (!confirmed || !context.mounted) return;

  // Ionic Utils.getLoadingElement(): blocking spinner until done.
  final navigator = Navigator.of(context, rootNavigator: true);
  showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: AppSpinner()),
    ),
  );
  final AccountCreationResult result;
  try {
    result = await ref
        .read(accountCreationNotifierProvider.notifier)
        .createAccounts(players, stopOnError: true, expectedTenantId: tenantId);
  } finally {
    navigator.pop();
  }
  if (!context.mounted) return;
  if (result.hasErrors) {
    ToastHelper.showError(
        context, l10n.settingsCreateAccountsFailed(result.errors.first));
  } else {
    ToastHelper.showSuccess(context, l10n.settingsAccountsCreated);
  }
}
