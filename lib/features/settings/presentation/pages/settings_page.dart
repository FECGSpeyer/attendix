import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/pwa_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/pwa_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../shared/widgets/sheets/feedback_sheet.dart';
// PROFILE_OFFLINE
import '../../../profile/presentation/widgets/account_dialogs.dart';
import '../../../profile/presentation/widgets/profile_hero_card.dart';
import '../../../../shared/widgets/sheets/version_history_sheet.dart';

/// Settings page with role-based menu filtering
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(currentTenantProvider);
    // Use effectiveRoleProvider to support debug role override
    final role = ref.watch(effectiveRoleProvider);
    final pendingCount = ref.watch(pendingPlayersProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentTenantProvider);
          ref.invalidate(userTenantsProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          // PWA Install Hint (only shown on mobile web)
          const _PwaInstallHint(),
          // PROFILE_OFFLINE: profile card ("Meine Stammdaten")
          const ProfileHeroCard(),
          // Tenant info section
          if (tenant != null) ...[
            _SettingsSection(
              title: 'Aktuelle Gruppe',
              children: [
                _SettingsTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      StringUtils.getTenantInitials(
                        tenant.shortName,
                        tenant.longName,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: tenant.shortName.isNotEmpty
                      ? tenant.shortName
                      : tenant.longName,
                  subtitle: tenant.longName != tenant.shortName
                      ? tenant.longName
                      : null,
                  trailing: TextButton(
                    onPressed: () => context.go('/tenants'),
                    child: const Text('Wechseln'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],

          // Content management section - only for users who can edit
          if (role.canEdit) ...[
            _SettingsSection(
              title: 'Verwaltung',
              children: [
                // Only Admin/Responsible can manage attendance types
                if (role.isAdmin || role.isResponsible)
                  _SettingsTile(
                    leading: const _SettingsIcon(icon: Icons.category),
                    title: 'Terminarten',
                    subtitle: 'Proben, Auftritte, etc. verwalten',
                    onTap: () => context.push('/settings/types'),
                  ),
                // All roles can see songs
                _SettingsTile(
                  leading: const _SettingsIcon(icon: Icons.music_note),
                  title: 'Lieder',
                  subtitle: 'Lieder und Notenblätter verwalten',
                  onTap: () => context.push('/settings/songs'),
                ),
                // Only Admin/Responsible can manage instruments
                if (role.isAdmin || role.isResponsible)
                  _SettingsTile(
                    leading: const _SettingsIcon(icon: Icons.piano),
                    title: 'Instrumente',
                    subtitle: 'Instrumentenliste verwalten',
                    onTap: () => context.push('/settings/instruments'),
                  ),
                // Conductors (Admin, Responsible, Viewer) can see teachers
                if (role.isConductor)
                  _SettingsTile(
                    leading: const _SettingsIcon(icon: Icons.school),
                    title: 'Lehrer',
                    subtitle: 'Lehrer und Ausbilder verwalten',
                    onTap: () => context.push('/settings/teachers'),
                  ),
                // Only Admin/Responsible can manage meetings
                if (role.isAdmin || role.isResponsible)
                  _SettingsTile(
                    leading: const _SettingsIcon(icon: Icons.event),
                    title: 'Besprechungen',
                    subtitle: 'Vorstandsbesprechungen verwalten',
                    onTap: () => context.push('/settings/meetings'),
                  ),
                // Only Admin/Responsible can manage shifts
                if (role.isAdmin || role.isResponsible)
                  _SettingsTile(
                    leading: const _SettingsIcon(icon: Icons.schedule),
                    title: 'Schichtpläne',
                    subtitle: 'Arbeitsschichten für automatische Entschuldigungen',
                    onTap: () => context.push('/settings/shifts'),
                  ),
                // Only Admin can manage users
                if (role.isAdmin)
                  _SettingsTile(
                    leading: const _SettingsIcon(icon: Icons.people),
                    title: 'Benutzer',
                    subtitle: 'Rollen und Berechtigungen verwalten',
                    onTap: () => context.push('/settings/users'),
                  ),
                // Only Admin can manage viewers
                if (role.isAdmin)
                  _SettingsTile(
                    leading: const _SettingsIcon(icon: Icons.visibility),
                    title: 'Beobachter',
                    subtitle: 'Externe Beobachter verwalten',
                    onTap: () => context.push('/settings/viewers'),
                  ),
                // Only Admin can manage parents (if feature enabled)
                if (role.isAdmin && tenant?.parents == true)
                  _SettingsTile(
                    leading: const _SettingsIcon(icon: Icons.family_restroom),
                    title: 'Elternteile',
                    subtitle: 'Eltern-Accounts verwalten',
                    onTap: () => context.push('/settings/parents'),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],

          // Songs for players who can't edit but can view
          if (!role.canEdit && role.canView) ...[
            _SettingsSection(
              title: 'Inhalte',
              children: [
                _SettingsTile(
                  leading: const _SettingsIcon(icon: Icons.music_note),
                  title: 'Lieder',
                  subtitle: 'Lieder und Notenblätter ansehen',
                  onTap: () => context.push('/settings/songs'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],

          // Voice Leader settings - only for voice leaders
          if (role.canSeeVoiceLeaderSettings) ...[
            _SettingsSection(
              title: 'Stimmführer',
              children: [
                _SettingsTile(
                  leading: const _SettingsIcon(icon: Icons.record_voice_over),
                  title: 'Stimmführer-Bereich',
                  subtitle: 'Deine Stimmgruppe verwalten',
                  onTap: () => context.push('/settings/voice-leader'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],

          // Member management section - only for Admin/Responsible
          if (role.isAdmin || role.isResponsible) ...[
            _SettingsSection(
              title: 'Mitgliederverwaltung',
              children: [
                _SettingsTile(
                  leading: _SettingsIcon(
                    icon: Icons.hourglass_empty,
                    color: AppColors.warning,
                  ),
                  title: 'Ausstehende Registrierungen',
                  subtitle: 'Neue Selbst-Registrierungen prüfen',
                  trailing: pendingCount > 0
                      ? Badge(
                          label: Text('$pendingCount'),
                          child: const Icon(Icons.chevron_right, color: AppColors.medium),
                        )
                      : null,
                  onTap: () => context.push('/settings/pending'),
                ),
                if (role.isAdmin)
                  _SettingsTile(
                    leading: const _SettingsIcon(icon: Icons.person_add),
                    title: 'Fehlende Accounts anlegen',
                    subtitle: 'Accounts für Spieler ohne Login erstellen',
                    onTap: () => context.push('/settings/batch-accounts'),
                  ),
                _SettingsTile(
                  leading: const _SettingsIcon(icon: Icons.history),
                  title: 'Ehemalige Mitglieder',
                  subtitle: 'Archivierte Mitglieder verwalten',
                  onTap: () => context.push('/settings/left'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],

          // Calendar subscription - for all authenticated users
          _SettingsSection(
            title: 'Kalender',
            children: [
              _SettingsTile(
                leading: const _SettingsIcon(icon: Icons.calendar_month),
                title: 'Kalender-Abo',
                subtitle: 'Termine im eigenen Kalender anzeigen',
                onTap: () => context.push('/settings/calendar'),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // App settings section - for users with notification permission
          if (role.canSeeNotifications) ...[
            _SettingsSection(
              title: 'App-Einstellungen',
              children: [
                _SettingsTile(
                  leading: const _SettingsIcon(icon: Icons.notifications),
                  title: 'Benachrichtigungen',
                  subtitle: 'Push-Benachrichtigungen konfigurieren',
                  onTap: () => context.push('/settings/notifications'),
                ),
                // General settings only for Admin/Responsible
                if (role.isAdmin || role.isResponsible)
                  _SettingsTile(
                    leading: const _SettingsIcon(icon: Icons.tune),
                    title: 'Allgemein',
                    subtitle: 'Sprache, Theme und weitere Optionen',
                    onTap: () => context.push('/settings/general'),
                  ),
                _SettingsTile(
                  leading: const _SettingsIcon(icon: Icons.feedback),
                  title: 'Feedback & Hilfe',
                  subtitle: 'Fragen stellen oder Feedback geben',
                  onTap: () => showFeedbackSheet(context),
                ),
                _SettingsTile(
                  leading: _SettingsIcon(icon: Icons.telegram, color: const Color(0xFF0088CC)),
                  title: 'Telegram Support',
                  subtitle: 'Direkt per Telegram kontaktieren',
                  onTap: () => _openTelegramSupport(context),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],

          // Account section - for all users
          _SettingsSection(
            title: 'Konto',
            children: [
              _SettingsTile(
                leading: const _SettingsIcon(icon: Icons.person),
                title: 'Profil',
                subtitle: 'Persönliche Daten bearbeiten',
                onTap: () => context.push('/settings/profile'),
              ),
              // PROFILE_OFFLINE: account actions (Ionic system section)
              if (!role.canSeeNotifications)
                _SettingsTile(
                  leading: const _SettingsIcon(icon: Icons.notifications),
                  title: 'Benachrichtigungen',
                  onTap: () => context.push('/settings/notifications'),
                ),
              _SettingsTile(
                leading: const _SettingsIcon(icon: Icons.key),
                title: 'Passwort ändern',
                onTap: () => showChangePasswordDialog(context),
              ),
              _SettingsTile(
                leading: const _SettingsIcon(icon: Icons.alternate_email),
                title: 'E-Mail ändern',
                onTap: () => showChangeEmailDialog(context),
              ),
              _SettingsTile(
                leading: _SettingsIcon(
                  icon: Icons.logout,
                  color: AppColors.danger,
                ),
                title: 'Abmelden',
                titleColor: AppColors.danger,
                onTap: () async {
                  // Store refs before async gap to avoid using ref after dispose
                  final supabase = ref.read(supabaseClientProvider);
                  final tenantNotifier =
                      ref.read(currentTenantProvider.notifier);

                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Abmelden'),
                      content:
                          const Text('Möchtest du dich wirklich abmelden?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Abbrechen'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Abmelden'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    await supabase.auth.signOut();
                    await tenantNotifier.clearTenant();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingL),

          // Applicant status hint
          if (role.isApplicant) ...[
            Card(
              color: AppColors.warning.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: AppColors.warning),
                    const SizedBox(width: AppDimensions.paddingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mitgliedschaft wird geprüft',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: AppDimensions.paddingXS),
                          Text(
                            'Ein Administrator wird deine Registrierung prüfen.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.medium,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),
          ],

          // App info - tappable to show version history
          GestureDetector(
            onTap: () => showVersionHistorySheet(context),
            child: Center(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: AppDimensions.paddingXS),
                      Text(
                        'Was ist neu?',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.paddingXS),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'v${AppConstants.appVersion}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingL),
        ],
      ),
      ),
    );
  }
}

void _openTelegramSupport(BuildContext context) {
  launchUrl(
    Uri.parse('https://t.me/attendix_bot'),
    mode: LaunchMode.externalApplication,
  );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Filter out null children (from conditional rendering)
    final filteredChildren = children.whereType<Widget>().toList();
    if (filteredChildren.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingS,
            vertical: AppDimensions.paddingXS,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.medium,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: filteredChildren,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.medium,
              ),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right, color: AppColors.medium)
              : null),
      onTap: onTap,
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({
    required this.icon,
    this.color,
  });

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppColors.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Icon(
        icon,
        color: iconColor,
        size: 22,
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
