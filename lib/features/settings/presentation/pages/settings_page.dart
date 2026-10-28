import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/parent_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/pwa_providers.dart';
import '../../../../core/providers/realtime_providers.dart'; // MEDIA_REALTIME
import '../../../../core/providers/role_permission_providers.dart'; // SETTINGS_EXT
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/viewer_providers.dart';
import '../../../../core/services/pwa_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/sheets/feedback_sheet.dart';
import '../../../../shared/widgets/tenant/tenant_switcher_title.dart';
// PROFILE_OFFLINE
import '../../../profile/presentation/widgets/account_dialogs.dart';
import '../../../profile/presentation/widgets/profile_hero_card.dart';
import '../../../../shared/widgets/sheets/version_history_sheet.dart';
import '../../../messages/presentation/widgets/notification_bell.dart'; // MESSAGES
import '../../../../core/services/certificate_service.dart'; // MISC2
import '../widgets/vorkurs_certificates.dart'; // MISC2
// SETTINGS2
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/services/app_update_service.dart'; // NATIVE_MISC
import '../widgets/app_promo_card.dart';
import '../widgets/settings_admins_sheet.dart';
// UX_SETTINGS
import '../widgets/calendar_subscription_dialog.dart';
import '../widgets/settings_list.dart';
import 'left_players_page.dart' show leftPlayersProvider;
import '../../../../core/providers/demo_providers.dart'; // DEMO_GUARD
// I18N_INFRA
import '../../../../l10n/l10n.dart';
import '../widgets/language_picker_tile.dart';
import '../../../../core/providers/push_providers.dart'; // PUSH

/// "Mehr" tab — UX_SETTINGS: same sections, order and role visibility as the
/// Ionic settings page (src/app/settings/settings/settings.page.html):
/// App-Hinweis, ausstehende Registrierungen, Meine Stammdaten, Stimmführer,
/// Instanz-Verwaltung, Kommunikation, Benutzer & Rollen, Werke & Proben
/// (bzw. Dateien), Planung, Organisation, Auswertung & Daten, System.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n; // I18N_INFRA
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
    final playersWithoutAccount = isAdmin
        ? (ref.watch(playersProvider).valueOrNull ?? const [])
            .where((p) =>
                (p.appId == null || p.appId!.isEmpty) &&
                !p.pending &&
                p.left == null &&
                (p.email ?? '').trim().isNotEmpty)
            .length
        : 0;

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

    final ios = ionIsIos(context); // UX_SETTINGS (WAVE 8)
    void openTenants() => context.go('/tenants');

    return Scaffold(
      appBar: AppBar(
        // Ionic: tenant switcher (long name + chevron) in `ion-buttons
        // slot="start"`. iOS: left aligned glass button, no title (with
        // several tenants TenantSwitcherTitle draws the capsule itself,
        // UX_AUTH); elsewhere UX_AUTH alignment.
        centerTitle: ios ? false : TenantSwitcherTitle.centerTitle(ref),
        titleSpacing: ios ? 12 : null,
        title: ios && TenantSwitcherTitle.centerTitle(ref) == null
            ? IonHeaderPill(child: TenantSwitcherTitle(fallbackTitle: l10n.settingsSettings))
            : TenantSwitcherTitle(fallbackTitle: l10n.settingsSettings),
        actions: const [NotificationBell()], // MESSAGES
      ),
      // Ionic: `@if (isIos)` ion-fab (apps-outline) opens the instance list.
      floatingActionButton: ios
          ? FloatingActionButton(
              heroTag: 'settingsTenantsFab',
              onPressed: openTenants,
              tooltip: l10n.settingsSwitchTenant,
              child: const Icon(Icons.apps),
            )
          : null,
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(currentTenantProvider);
          ref.invalidate(userTenantsProvider);
          ref.invalidate(pendingPlayersProvider);
          ref.invalidate(realtimePendingPlayersProvider); // MEDIA_REALTIME
          ref.invalidate(playersProvider);
          ref.invalidate(viewersProvider);
          ref.invalidate(parentsProvider);
          ref.invalidate(adminsProvider);
          ref.invalidate(leftPlayersProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // iOS: inset lists 16pt from the edges, hero card margin-top 12,
          // room for the ion-fab at the bottom.
          padding: ios
              ? const EdgeInsets.fromLTRB(16, 12, 16, 88)
              : const EdgeInsets.all(AppDimensions.paddingM),
          children: [
            // PWA Install Hint (only shown on mobile web)
            const _PwaInstallHint(),
            const AppPromoCard(), // SETTINGS2: "📱 Attendix als App"

            // Ionic: pending persons alert card (warning)
            if (pendingCount > 0) _PendingPersonsCard(count: pendingCount),

            // PROFILE_OFFLINE: profile card ("Meine Stammdaten")
            const ProfileHeroCard(),

            // ============ STIMMFÜHRER ============
            if (isVoiceLeader && !isGeneral)
              SettingsListSection(
                icon: CupertinoIcons.music_note_2, // musical-notes-outline
                title: l10n.settingsVoiceLeader,
                children: [
                  SettingsListTile(
                    icon: Icons.people_outline,
                    title: l10n.settingsMyVoice,
                    onTap: () => context.push('/settings/voice-leader'),
                  ),
                ],
              ),

            // ============ INSTANZ-VERWALTUNG ============
            if (isAdmin)
              SettingsListSection(
                icon: Icons.business_outlined,
                title: l10n.settingsTenantAdmin,
                children: [
                  SettingsListTile(
                    icon: Icons.settings_outlined,
                    title: l10n.settingsSettings,
                    onTap: () => context.push('/settings/general'),
                  ),
                  SettingsListTile(
                    icon: Icons.people_outline,
                    title: l10n.settingsGroups,
                    onTap: () => context.push('/settings/instruments'),
                  ),
                  if (tenant?.maintainTeachers == true)
                    SettingsListTile(
                      icon: Icons.school_outlined,
                      title: l10n.settingsTeachers,
                      onTap: () => context.push('/settings/teachers'),
                    ),
                  SettingsListTile(
                    icon: Icons.key_outlined,
                    title: l10n.settingsRolesPerms,
                    onTap: () => context.push('/settings/role-permissions'),
                  ),
                  SettingsListTile(
                    icon: Icons.grid_view_outlined,
                    title: l10n.settingsConfigureDashboard,
                    onTap: () => context.push('/settings/dashboard'),
                  ),
                ],
              ),

            // ============ KOMMUNIKATION ============
            if (isAdmin)
              SettingsListSection(
                icon: Icons.campaign_outlined,
                title: l10n.settingsCommunication,
                children: [
                  SettingsListTile(
                    icon: Icons.mail_outline,
                    title: l10n.settingsAnnouncements,
                    subtitle: l10n.settingsMessageAll,
                    onTap: () => context.push('/settings/messages'),
                  ),
                ],
              ),

            // ============ BENUTZER & ROLLEN ============
            if (isAdmin)
              SettingsListSection(
                icon: Icons.supervised_user_circle_outlined,
                title: l10n.settingsUsersRoles,
                children: [
                  if (!isDemo && isSuperAdmin)
                    SettingsListTile(
                      icon: Icons.verified_user_outlined,
                      title: l10n.settingsAdmins,
                      detail: false,
                      trailing: SettingsCountBadge(ref.watch(adminsProvider).valueOrNull?.length ?? 0),
                      onTap: () => showAdminsSheet(context),
                    ),
                  if (parentsEnabled)
                    SettingsListTile(
                      icon: Icons.favorite_border,
                      title: l10n.settingsParents,
                      detail: false,
                      trailing: SettingsCountBadge(ref.watch(parentsProvider).valueOrNull?.length ?? 0),
                      onTap: () => context.push('/settings/parents'),
                    ),
                  SettingsListTile(
                    icon: Icons.visibility_outlined,
                    title: l10n.settingsViewers,
                    detail: false,
                    trailing: SettingsCountBadge(ref.watch(viewersProvider).valueOrNull?.length ?? 0),
                    onTap: () => context.push('/settings/viewers'),
                  ),
                  // Flutter: Benutzerverwaltung (Rollen der Accounts) — in
                  // Ionic über die Person; hier im selben Block.
                  SettingsListTile(
                    icon: Icons.manage_accounts_outlined,
                    title: l10n.settingsFlutterUsers,
                    onTap: () => context.push('/settings/users'),
                  ),
                  if (playersWithoutAccount > 0)
                    SettingsListTile(
                      icon: Icons.person_add_alt_outlined,
                      iconColor: AppColors.warning,
                      title: l10n.settingsCreateMissing,
                      detail: false,
                      trailing: SettingsCountBadge(playersWithoutAccount, color: AppColors.warning),
                      onTap: () => context.push('/settings/batch-accounts'),
                    ),
                ],
              ),

            // ============ WERKE & PROBEN ============
            if (!isGeneral && !isApplicant)
              SettingsListSection(
                icon: CupertinoIcons.music_note_2, // musical-notes-outline
                title: l10n.settingsSongsRehearsals,
                children: [
                  SettingsListTile(
                    // Ionic library-outline: books on a shelf.
                    iconWidget: const IonLibraryOutlineIcon(),
                    title: l10n.settingsSongs,
                    onTap: () => context.push('/settings/songs'),
                  ),
                  if (isAdmin || isHelper)
                    SettingsListTile(
                      icon: Icons.schedule,
                      title: l10n.historyTitle,
                      detail: false,
                      onTap: () => context.push('/history'),
                    ),
                  if (canAccessFiles)
                    SettingsListTile(
                      icon: Icons.folder_outlined,
                      title: l10n.settingsFileStorage,
                      onTap: () => context.push('/settings/files'),
                    ),
                ],
              ),

            // Allgemeine Instanzen: Dateiablage steht allein
            if (isGeneral && canAccessFiles)
              SettingsListSection(
                icon: Icons.folder_outlined,
                title: l10n.settingsFiles,
                children: [
                  SettingsListTile(
                    icon: Icons.folder_outlined,
                    title: l10n.settingsFileStorage,
                    onTap: () => context.push('/settings/files'),
                  ),
                ],
              ),

            // ============ PLANUNG (inkl. Teamorganisation) ============
            if (showPlanning || showTeam)
              SettingsListSection(
                icon: Icons.list,
                title: l10n.settingsPlanning,
                children: [
                  if (showPlanning) ...[
                    SettingsListTile(
                      icon: Icons.list,
                      title: l10n.settingsRunSheets,
                      detail: false,
                      onTap: () => context.push('/planning'),
                    ),
                    SettingsListTile(
                      icon: Icons.calendar_today_outlined,
                      title: l10n.settingsAdHocPlanning,
                      detail: false,
                      onTap: () => context.push('/settings/planung'),
                    ),
                    if (org != null)
                      SettingsListTile(
                        icon: Icons.description_outlined,
                        title: l10n.settingsTemplatesFields,
                        detail: false,
                        onTap: () => context.push('/settings/org-settings/planning-templates'),
                      ),
                  ],
                  if (showTeam) ...[
                    if (isTeamLeader)
                      SettingsListTile(
                        icon: Icons.supervised_user_circle_outlined,
                        title: l10n.teamOrgTitle,
                        detail: false,
                        onTap: () => openTeamOrg('tasks'),
                      )
                    else ...[
                      SettingsListTile(
                        icon: Icons.check_circle_outline,
                        title: l10n.tasksMyTasks,
                        detail: false,
                        onTap: () => openTeamOrg('tasks'),
                      ),
                      if (inTeamCircle) ...[
                        SettingsListTile(
                          icon: Icons.lightbulb_outline,
                          title: l10n.teamOrgSuggestTopic,
                          detail: false,
                          onTap: () => openTeamOrg('topics'),
                        ),
                        SettingsListTile(
                          icon: Icons.description_outlined,
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
                icon: Icons.business_outlined,
                title: l10n.settingsOrganisation,
                children: [
                  SettingsListTile(
                    icon: Icons.settings_outlined,
                    title: org?.name ?? l10n.settingsOrganisation,
                    trailing: org == null ? IonNote(l10n.settingsNotLinked) : null,
                    onTap: () => context.push('/settings/org-settings'),
                  ),
                ],
              ),

            // ============ AUSWERTUNG & DATEN ============
            if (!isApplicant)
              SettingsListSection(
                icon: Icons.bar_chart,
                title: l10n.settingsAnalyticsData,
                children: [
                  SettingsListTile(
                    icon: Icons.calendar_today_outlined,
                    title: l10n.settingsSubscribeCalendar,
                    detail: false,
                    onTap: () => showCalendarSubscriptionDialog(context, ref),
                  ),
                  if (isAdmin) ...[
                    SettingsListTile(
                      icon: Icons.insert_chart_outlined,
                      title: l10n.statsTitle,
                      detail: false,
                      onTap: () => context.push('/statistics'),
                    ),
                    SettingsListTile(
                      icon: Icons.download_outlined,
                      title: l10n.settingsExport,
                      detail: false,
                      onTap: () => context.push('/export'),
                    ),
                    // MISC2: Urkunden generieren (Vorkurs tenants only)
                    if (isVorkursTenantName(tenant?.shortName, tenant?.longName))
                      SettingsListTile(
                        icon: Icons.workspace_premium_outlined,
                        title: l10n.settingsCertificates,
                        detail: false,
                        onTap: () => generateVorkursCertificates(context, ref),
                      ),
                    Builder(builder: (context) {
                      final left = ref.watch(leftPlayersProvider).valueOrNull?.length ?? 0;
                      return SettingsListTile(
                        icon: Icons.archive_outlined,
                        title: l10n.settingsArchive,
                        detail: false,
                        trailing: left > 0 ? SettingsCountBadge(left) : null,
                        onTap: () => context.push('/settings/left'),
                      );
                    }),
                  ],
                ],
              ),

            // Applicant status hint (Flutter)
            if (isApplicant) const _ApplicantHint(),

            // ============ SYSTEM ============
            SettingsListSection(
              icon: Icons.settings_outlined,
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
                  icon: CupertinoIcons.circle_grid_3x3,
                  title: l10n.settingsSwitchTenant,
                  subtitle: tenant?.longName,
                  detail: false,
                  onTap: openTenants,
                ),
                const LanguagePickerTile(), // I18N_INFRA
                SettingsListTile(
                  icon: Icons.notifications_outlined,
                  title: l10n.settingsNotifications,
                  onTap: () => context.push('/settings/notifications'),
                ),
                SettingsListTile(
                  icon: Icons.key_outlined,
                  title: l10n.settingsChangePassword,
                  detail: false,
                  onTap: () => showChangePasswordDialog(context),
                ),
                // Ionic offers no "E-Mail ändern" here (nor anywhere else),
                // so the Mehr tab shows only "Passwort ändern".
                // LEGAL_HELP: help center
                SettingsListTile(
                  icon: Icons.help_outline,
                  title: l10n.settingsHelp,
                  onTap: () => context.push('/settings/help'),
                ),
                SettingsListTile(
                  // Ionic chatbubble-ellipses-outline (bubble with dots).
                  icon: Icons.sms_outlined,
                  title: l10n.settingsGiveFeedback,
                  detail: false,
                  onTap: () => showFeedbackSheet(context),
                ),
                SettingsListTile(
                  icon: Icons.auto_awesome_outlined,
                  title: l10n.settingsWhatsNew,
                  detail: false,
                  trailing: const IonBadge(text: AppConstants.appVersion),
                  onTap: () => showVersionHistorySheet(context),
                ),
                // NATIVE_MISC: Ionic liveUpdate.updateAvailable() → "Update installieren"
                if (ref.watch(appUpdateAvailableProvider))
                  SettingsListTile(
                    icon: Icons.cloud_download_outlined,
                    title: l10n.settingsInstallUpdate,
                    detail: false,
                    color: AppColors.success,
                    iconColor: AppColors.success,
                    onTap: () => ref.read(appUpdateServiceProvider).applyUpdate(),
                  ),
                if (isSuperDeveloper)
                  SettingsListTile(
                    icon: Icons.construction_outlined,
                    title: l10n.adminTitle,
                    onTap: () => context.push('/settings/administration'),
                  ),
                // Ionic: red `ion-item color="danger"` row, no detail chevron.
                SettingsListTile(
                  icon: Icons.logout,
                  title: l10n.settingsLogout,
                  detail: false,
                  background: AppColors.danger,
                  onTap: () async {
                    // Ionic logs out directly (no confirmation)
                    final supabase = ref.read(supabaseClientProvider);
                    final tenantNotifier = ref.read(currentTenantProvider.notifier);
                    await removePushTokenBeforeSignOut(ref); // PUSH
                    await supabase.auth.signOut();
                    await tenantNotifier.clearTenant();
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
        onTap: () => context.push('/settings/pending'),
        child: Padding(
            padding: EdgeInsets.all(ionIsIos(context) ? 20 : AppDimensions.paddingM),
            child: Row(
              children: [
                const Icon(Icons.person_add, size: 32, color: Colors.black87),
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

class _ApplicantHint extends StatelessWidget {
  const _ApplicantHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColors.warning.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Row(
            children: [
              const Icon(Icons.hourglass_empty, color: AppColors.warning),
              const SizedBox(width: AppDimensions.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.settingsFlutterApplicantTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppDimensions.paddingXS),
                    Text(
                      context.l10n.settingsFlutterApplicantText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.medium),
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

/// PWA install hint card for mobile web users
class _PwaInstallHint extends ConsumerWidget {
  const _PwaInstallHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showHint = ref.watch(showPwaInstallHintProvider);
    final platform = ref.watch(pwaPlatformProvider);

    return showHint.when(
      data: (show) {
        if (!show) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
          child: Card(
            color: AppColors.info.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.install_mobile, color: AppColors.info),
                      const SizedBox(width: AppDimensions.paddingS),
                      Expanded(
                        child: Text(
                          context.l10n.settingsFlutterPwaTitle,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          ref
                              .read(pwaHintNotifierProvider.notifier)
                              .dismissHint();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  Text(
                    context.l10n.settingsFlutterPwaText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.medium,
                        ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  if (platform == PwaPlatform.ios) ...[
                    _buildInstructionStep(context, '1', context.l10n.settingsFlutterPwaIosStep1),
                    _buildInstructionStep(context, '2', context.l10n.settingsFlutterPwaIosStep2),
                    _buildInstructionStep(context, '3', context.l10n.settingsFlutterPwaIosStep3),
                  ] else if (platform == PwaPlatform.android) ...[
                    _buildInstructionStep(context, '1', context.l10n.settingsFlutterPwaAndroidStep1),
                    _buildInstructionStep(context, '2', context.l10n.settingsFlutterPwaAndroidStep2),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildInstructionStep(BuildContext context, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.info,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
