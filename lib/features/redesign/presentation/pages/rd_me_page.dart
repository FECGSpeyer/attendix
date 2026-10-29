import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/player_absence_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/profile_providers.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/display/avatar.dart';
import '../../../../shared/widgets/sheets/feedback_sheet.dart';
import '../../../../shared/widgets/sheets/version_history_sheet.dart';
import '../../../profile/presentation/widgets/account_dialogs.dart';
import '../../../profile/presentation/widgets/master_data_sheet.dart';
import '../../../profile/presentation/widgets/profile_helpers.dart';
import '../../../self_service/presentation/widgets/self_service_absences.dart';
import '../../../settings/presentation/widgets/calendar_subscription_dialog.dart';
import '../rd_actions.dart';
import '../widgets/rd_group_switch.dart';
import '../widgets/rd_widgets.dart';
import 'rd_appearance_page.dart' show rdModeName, rdWorldName;

/// REDESIGN: tab "Ich" (canvas E1): own profile, things for me, the app,
/// help and the account. Verwaltung leads to the existing settings.
class RdMePage extends ConsumerWidget {
  const RdMePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    final tenant = ref.watch(currentTenantProvider);
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const [];
    final player = ref.watch(currentSelfServicePlayerProvider).valueOrNull;
    final settings = ref.watch(redesignSettingsProvider);
    final isLead = role.isAdmin || role.isResponsible;
    final pending = isLead ? (ref.watch(pendingPlayersProvider).valueOrNull?.length ?? 0) : 0;
    final canReportAbsence = player != null && ref.watch(canSelfReportAbsenceProvider);
    final canPause = player != null && ref.watch(canSelfPauseProvider);
    final language = ref.watch(localeProvider).languageCode;
    final appearance = settings.world.alwaysDark
        ? rdWorldName(l10n, settings.world)
        : '${rdWorldName(l10n, settings.world)} · ${rdModeName(l10n, settings.mode)}';

    return RdPage(
      children: [
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(l10n.redesignTabMe, style: RdType.largeTitle(p)),
        ),
        const SizedBox(height: 18),
        const _ProfileCard(),
        if (isLead) ...[
          const SizedBox(height: 20),
          RdGroupedList(
            children: [
              RdListRow(
                leading: const RdRowIcon(Icons.admin_panel_settings_outlined),
                title: l10n.redesignMeAdmin,
                subtitle: l10n.redesignMeAdminHint,
                trailing: pending > 0 ? RdCountBadge(pending) : null,
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignMeForMe),
        RdGroupedList(
          children: [
            if (canReportAbsence)
              RdListRow(
                leading: const RdRowIcon(Icons.event_busy_outlined),
                title: l10n.redesignMeAbsence,
                onTap: () => selfServiceReportAbsence(
                  context,
                  ref,
                  player,
                  canSelfPause: ref.read(canSelfPauseProvider),
                ),
              ),
            if (canPause)
              RdListRow(
                leading: RdRowIcon(player.paused ? Icons.play_circle_outline : Icons.pause_circle_outline),
                title: player.paused ? l10n.signoutEndPause : l10n.signoutPause,
                onTap: () => player.paused
                    ? selfServiceUnpause(context, ref, player)
                    : selfServicePause(context, ref, player),
              ),
            RdListRow(
              leading: const RdRowIcon(Icons.apps),
              title: l10n.redesignMeGroups,
              value: tenants.length > 1
                  ? l10n.redesignMeGroupsCount(tenants.length)
                  : (tenant?.shortName ?? ''),
              onTap: () => showRdGroupSwitchSheet(context),
            ),
            if (role.canSeeNotifications)
              RdListRow(
                leading: const RdRowIcon(Icons.notifications_outlined),
                title: l10n.redesignMeNotifications,
                onTap: () => context.push('/settings/notifications'),
              ),
            if (!role.isApplicant)
              RdListRow(
                leading: const RdRowIcon(Icons.calendar_month_outlined),
                title: l10n.redesignMeCalendar,
                onTap: () => showCalendarSubscriptionDialog(context, ref),
              ),
          ],
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignMeApp),
        RdGroupedList(
          children: [
            RdListRow(
              leading: const RdRowIcon(Icons.palette_outlined),
              title: l10n.redesignAppearanceTitle,
              value: appearance,
              onTap: () => context.push(RedesignRoutes.appearance),
            ),
            if (enabledLanguages.length > 1)
              RdListRow(
                leading: const RdRowIcon(Icons.translate),
                title: l10n.settingsLanguageTitle,
                value: languageNames[language] ?? language,
                onTap: () => _pickLanguage(context, ref, language),
              ),
            RdListRow(
              leading: const RdRowIcon(Icons.auto_awesome_outlined),
              title: l10n.redesignMeBeta,
              subtitle: l10n.redesignMeBetaHint,
              showChevron: false,
              trailing: Switch.adaptive(
                value: settings.enabled,
                activeTrackColor: p.primary,
                onChanged: (v) => rdSetRedesignEnabled(context, ref, v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignMeHelp),
        RdGroupedList(
          children: [
            RdListRow(
              leading: const RdRowIcon(Icons.help_outline),
              title: l10n.settingsHelp,
              onTap: () => context.push('/settings/help'),
            ),
            RdListRow(
              leading: const RdRowIcon(Icons.chat_bubble_outline),
              title: l10n.redesignMeFeedback,
              onTap: () => showFeedbackSheet(context),
            ),
            RdListRow(
              leading: const RdRowIcon(Icons.new_releases_outlined),
              title: l10n.redesignMeWhatsNew,
              value: AppConstants.appVersion,
              onTap: () => showVersionHistorySheet(context),
            ),
          ],
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignMeAccount),
        RdGroupedList(
          children: [
            RdListRow(
              leading: const RdRowIcon(Icons.key_outlined),
              title: l10n.settingsChangePassword,
              onTap: () => showChangePasswordDialog(context),
            ),
            if (!isLead && !role.isApplicant)
              RdListRow(
                leading: const RdRowIcon(Icons.settings_outlined),
                title: l10n.redesignMeAllSettings,
                onTap: () => context.push('/settings'),
              ),
            RdListRow(
              leading: RdRowIcon(Icons.logout, color: p.absent, background: p.absentSoft),
              title: l10n.redesignMeLogout,
              titleColor: p.absent,
              showChevron: false,
              onTap: () => rdLogout(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Attendix ${AppConstants.appVersion}',
            style: RdType.meta(p, size: 13),
          ),
        ),
      ],
    );
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref, String current) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.rd.bg,
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: RdGroupedList(
            children: [
              for (final lang in enabledLanguages)
                RdListRow(
                  title: languageNames[lang] ?? lang,
                  selected: lang == current,
                  showChevron: false,
                  trailing: lang == current
                      ? Icon(Icons.check_circle, color: sheet.rd.primary)
                      : null,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    if (lang != current) {
                      ref.read(localeProvider.notifier).setLanguage(lang);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar, name, role and group; opens the own master data.
class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final role = ref.watch(effectiveRoleProvider);
    final tenant = ref.watch(currentTenantProvider);
    final person = ref.watch(ownProfileProvider).valueOrNull?.person;
    final roleName = profileRoleName(role);
    final group = tenant?.shortName ?? '';
    final name = person == null ? '' : '${person.firstName} ${person.lastName}'.trim();

    return RdCard(
      onTap: person == null ? null : () => showMasterDataSheet(context),
      child: Row(
        children: [
          Avatar(
            imageUrl: person != null && hasCustomProfileImage(person.img) ? person.img : null,
            firstName: person?.firstName ?? '',
            lastName: person?.lastName ?? '',
            size: 56,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? context.l10n.redesignTabMe : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RdType.cardTitle(p),
                ),
                const SizedBox(height: 2),
                Text(
                  [roleName, group].where((s) => s.isNotEmpty).join(' · '),
                  style: RdType.meta(p),
                ),
              ],
            ),
          ),
          if (person != null) Icon(Icons.chevron_right, color: p.text2),
        ],
      ),
    );
  }
}
