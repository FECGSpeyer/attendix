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
import '../widgets/app_promo_card.dart';
import '../widgets/settings_admins_sheet.dart';
// UX_SETTINGS
import '../widgets/calendar_subscription_dialog.dart';
import '../widgets/settings_list.dart';
import 'left_players_page.dart' show leftPlayersProvider;

/// "Mehr" tab — UX_SETTINGS: same sections, order and role visibility as the
/// Ionic settings page (src/app/settings/settings/settings.page.html):
/// App-Hinweis, ausstehende Registrierungen, Meine Stammdaten, Stimmführer,
/// Instanz-Verwaltung, Kommunikation, Benutzer & Rollen, Werke & Proben
/// (bzw. Dateien), Planung, Organisation, Auswertung & Daten, System.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final userEmail = ref.watch(supabaseClientProvider).auth.currentUser?.email;
    final isDemo = AppConstants.demoMail.isNotEmpty && userEmail == AppConstants.demoMail;

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

    return Scaffold(
      appBar: AppBar(
        // Ionic: tenant switcher (long name + chevron) in the header
        title: const TenantSwitcherTitle(fallbackTitle: 'Einstellungen'),
        actions: const [NotificationBell()], // MESSAGES
      ),
      body: RefreshIndicator(
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
          padding: const EdgeInsets.all(AppDimensions.paddingM),
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
                icon: Icons.music_note_outlined,
                title: 'Stimmführer',
                children: [
                  SettingsListTile(
                    icon: Icons.people_outline,
                    title: 'Meine Stimme',
                    onTap: () => context.push('/settings/voice-leader'),
                  ),
                ],
              ),

            // ============ INSTANZ-VERWALTUNG ============
            if (isAdmin)
              SettingsListSection(
                icon: Icons.business_outlined,
                title: 'Instanz-Verwaltung',
                children: [
                  SettingsListTile(
                    icon: Icons.settings_outlined,
                    title: 'Einstellungen',
                    onTap: () => context.push('/settings/general'),
                  ),
                  SettingsListTile(
                    icon: Icons.people_outline,
                    title: 'Gruppen',
                    onTap: () => context.push('/settings/instruments'),
                  ),
                  if (tenant?.maintainTeachers == true)
                    SettingsListTile(
                      icon: Icons.school_outlined,
                      title: 'Lehrer',
                      onTap: () => context.push('/settings/teachers'),
                    ),
                  SettingsListTile(
                    icon: Icons.key_outlined,
                    title: 'Rollen & Berechtigungen',
                    onTap: () => context.push('/settings/role-permissions'),
                  ),
                  SettingsListTile(
                    icon: Icons.grid_view_outlined,
                    title: 'Dashboard konfigurieren',
                    onTap: () => context.push('/settings/dashboard'),
                  ),
                ],
              ),

            // ============ KOMMUNIKATION ============
            if (isAdmin)
              SettingsListSection(
                icon: Icons.campaign_outlined,
                title: 'Kommunikation',
                children: [
                  SettingsListTile(
                    icon: Icons.mail_outline,
                    title: 'Mitteilungen',
                    subtitle: 'Nachricht an alle senden',
                    onTap: () => context.push('/settings/messages'),
                  ),
                ],
              ),

            // ============ BENUTZER & ROLLEN ============
            if (isAdmin)
              SettingsListSection(
                icon: Icons.supervised_user_circle_outlined,
                title: 'Benutzer & Rollen',
                children: [
                  if (!isDemo && isSuperAdmin)
                    SettingsListTile(
                      icon: Icons.verified_user_outlined,
                      title: 'Administratoren',
                      detail: false,
                      trailing: SettingsCountBadge(ref.watch(adminsProvider).valueOrNull?.length ?? 0),
                      onTap: () => showAdminsSheet(context),
                    ),
                  if (parentsEnabled)
                    SettingsListTile(
                      icon: Icons.favorite_border,
                      title: 'Eltern',
                      detail: false,
                      trailing: SettingsCountBadge(ref.watch(parentsProvider).valueOrNull?.length ?? 0),
                      onTap: () => context.push('/settings/parents'),
                    ),
                  SettingsListTile(
                    icon: Icons.visibility_outlined,
                    title: 'Beobachter',
                    detail: false,
                    trailing: SettingsCountBadge(ref.watch(viewersProvider).valueOrNull?.length ?? 0),
                    onTap: () => context.push('/settings/viewers'),
                  ),
                  // Flutter: Benutzerverwaltung (Rollen der Accounts) — in
                  // Ionic über die Person; hier im selben Block.
                  SettingsListTile(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Benutzer',
                    onTap: () => context.push('/settings/users'),
                  ),
                  if (playersWithoutAccount > 0)
                    SettingsListTile(
                      icon: Icons.person_add_alt_outlined,
                      iconColor: AppColors.warning,
                      title: 'Fehlende Accounts anlegen',
                      detail: false,
                      trailing: SettingsCountBadge(playersWithoutAccount, color: AppColors.warning),
                      onTap: () => context.push('/settings/batch-accounts'),
                    ),
                ],
              ),

            // ============ WERKE & PROBEN ============
            if (!isGeneral && !isApplicant)
              SettingsListSection(
                icon: Icons.music_note_outlined,
                title: 'Werke & Proben',
                children: [
                  SettingsListTile(
                    icon: Icons.library_music_outlined,
                    title: 'Werke',
                    onTap: () => context.push('/settings/songs'),
                  ),
                  if (isAdmin || isHelper)
                    SettingsListTile(
                      icon: Icons.schedule,
                      title: 'Werkhistorie',
                      detail: false,
                      onTap: () => context.push('/history'),
                    ),
                  if (canAccessFiles)
                    SettingsListTile(
                      icon: Icons.folder_outlined,
                      title: 'Dateiablage',
                      onTap: () => context.push('/settings/files'),
                    ),
                ],
              ),

            // Allgemeine Instanzen: Dateiablage steht allein
            if (isGeneral && canAccessFiles)
              SettingsListSection(
                icon: Icons.folder_outlined,
                title: 'Dateien',
                children: [
                  SettingsListTile(
                    icon: Icons.folder_outlined,
                    title: 'Dateiablage',
                    onTap: () => context.push('/settings/files'),
                  ),
                ],
              ),

            // ============ PLANUNG (inkl. Teamorganisation) ============
            if (showPlanning || showTeam)
              SettingsListSection(
                icon: Icons.list,
                title: 'Planung',
                children: [
                  if (showPlanning) ...[
                    SettingsListTile(
                      icon: Icons.list,
                      title: 'Ablaufpläne',
                      detail: false,
                      onTap: () => context.push('/planning'),
                    ),
                    SettingsListTile(
                      icon: Icons.calendar_today_outlined,
                      title: 'Ad-Hoc Ablaufplanung',
                      detail: false,
                      onTap: () => context.push('/settings/planung'),
                    ),
                    if (org != null)
                      SettingsListTile(
                        icon: Icons.description_outlined,
                        title: 'Planvorlagen & Felder',
                        detail: false,
                        onTap: () => context.push('/settings/org-settings/planning-templates'),
                      ),
                  ],
                  if (showTeam) ...[
                    if (isTeamLeader)
                      SettingsListTile(
                        icon: Icons.supervised_user_circle_outlined,
                        title: 'Teamorganisation',
                        detail: false,
                        onTap: () => openTeamOrg('tasks'),
                      )
                    else ...[
                      SettingsListTile(
                        icon: Icons.check_circle_outline,
                        title: 'Meine Aufgaben',
                        detail: false,
                        onTap: () => openTeamOrg('tasks'),
                      ),
                      if (inTeamCircle) ...[
                        SettingsListTile(
                          icon: Icons.lightbulb_outline,
                          title: 'Thema vorschlagen',
                          detail: false,
                          onTap: () => openTeamOrg('topics'),
                        ),
                        SettingsListTile(
                          icon: Icons.description_outlined,
                          title: 'Protokolle',
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
                title: 'Organisation',
                children: [
                  SettingsListTile(
                    icon: Icons.settings_outlined,
                    title: org?.name ?? 'Organisation',
                    trailing: org == null
                        ? const Text('Nicht verknüpft', style: TextStyle(color: AppColors.medium))
                        : null,
                    onTap: () => context.push('/settings/org-settings'),
                  ),
                ],
              ),

            // ============ AUSWERTUNG & DATEN ============
            if (!isApplicant)
              SettingsListSection(
                icon: Icons.bar_chart,
                title: 'Auswertung & Daten',
                children: [
                  SettingsListTile(
                    icon: Icons.calendar_today_outlined,
                    title: 'Kalender abonnieren',
                    detail: false,
                    onTap: () => showCalendarSubscriptionDialog(context, ref),
                  ),
                  if (isAdmin) ...[
                    SettingsListTile(
                      icon: Icons.insert_chart_outlined,
                      title: 'Statistiken',
                      detail: false,
                      onTap: () => context.push('/statistics'),
                    ),
                    SettingsListTile(
                      icon: Icons.download_outlined,
                      title: 'Export',
                      detail: false,
                      onTap: () => context.push('/export'),
                    ),
                    // MISC2: Urkunden generieren (Vorkurs tenants only)
                    if (isVorkursTenantName(tenant?.shortName, tenant?.longName))
                      SettingsListTile(
                        icon: Icons.workspace_premium_outlined,
                        title: 'Urkunden generieren',
                        detail: false,
                        onTap: () => generateVorkursCertificates(context, ref),
                      ),
                    Builder(builder: (context) {
                      final left = ref.watch(leftPlayersProvider).valueOrNull?.length ?? 0;
                      return SettingsListTile(
                        icon: Icons.archive_outlined,
                        title: 'Archiv',
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
              title: 'System',
              footer: Center(
                child: TextButton(
                  onPressed: () => context.push('/settings/delete-account'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.medium),
                  child: const Text('Konto löschen'),
                ),
              ),
              children: [
                SettingsListTile(
                  icon: Icons.apps,
                  title: 'Instanz wechseln',
                  subtitle: tenant?.longName,
                  detail: false,
                  onTap: () => context.go('/tenants'),
                ),
                SettingsListTile(
                  icon: Icons.notifications_outlined,
                  title: 'Benachrichtigungen',
                  onTap: () => context.push('/settings/notifications'),
                ),
                SettingsListTile(
                  icon: Icons.key_outlined,
                  title: 'Passwort ändern',
                  detail: false,
                  onTap: () => showChangePasswordDialog(context),
                ),
                // Flutter: E-Mail ändern (neben Passwort ändern)
                SettingsListTile(
                  icon: Icons.alternate_email,
                  title: 'E-Mail ändern',
                  detail: false,
                  onTap: () => showChangeEmailDialog(context),
                ),
                // LEGAL_HELP: help center
                SettingsListTile(
                  icon: Icons.help_outline,
                  title: 'Hilfe',
                  onTap: () => context.push('/settings/help'),
                ),
                SettingsListTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'Feedback geben',
                  detail: false,
                  onTap: () => showFeedbackSheet(context),
                ),
                SettingsListTile(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Was ist neu?',
                  detail: false,
                  trailing: _VersionBadge(version: AppConstants.appVersion),
                  onTap: () => showVersionHistorySheet(context),
                ),
                if (isSuperDeveloper)
                  SettingsListTile(
                    icon: Icons.construction_outlined,
                    title: 'Administration',
                    onTap: () => context.push('/settings/administration'),
                  ),
                SettingsListTile(
                  icon: Icons.logout,
                  title: 'Ausloggen',
                  detail: false,
                  background: AppColors.danger,
                  onTap: () async {
                    // Ionic logs out directly (no confirmation)
                    final supabase = ref.read(supabaseClientProvider);
                    final tenantNotifier = ref.read(currentTenantProvider.notifier);
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
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColors.warning,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/settings/pending'),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Row(
              children: [
                const Icon(Icons.person_add, size: 32, color: Colors.black87),
                const SizedBox(width: AppDimensions.paddingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count ausstehende Registrierung(en)',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Personen warten auf Genehmigung',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        version,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                      'Mitgliedschaft wird geprüft',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppDimensions.paddingXS),
                    Text(
                      'Ein Administrator wird deine Registrierung prüfen.',
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
                          'App installieren',
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
                    'Für ein besseres Erlebnis kannst du diese App installieren:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.medium,
                        ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  if (platform == PwaPlatform.ios) ...[
                    _buildInstructionStep(context, '1', 'Tippe auf das Teilen-Symbol'),
                    _buildInstructionStep(context, '2', '"Zum Home-Bildschirm"'),
                    _buildInstructionStep(context, '3', '"Hinzufügen"'),
                  ] else if (platform == PwaPlatform.android) ...[
                    _buildInstructionStep(context, '1', 'Tippe auf das Menü (⋮)'),
                    _buildInstructionStep(context, '2', '"App installieren" oder "Zum Startbildschirm"'),
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
