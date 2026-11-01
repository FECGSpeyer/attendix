import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/account_switch_providers.dart';
import '../../../../core/providers/dashboard_providers.dart';
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
import '../../../../core/services/app_update_service.dart';
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
import '../../data/providers/rd_today_providers.dart' show rdSignoutDataProvider;
import '../../data/rd_manage_logic.dart';
import '../rd_actions.dart';
import '../widgets/manage/rd_manage_entries.dart';
import '../widgets/rd_account_switch.dart';
import '../widgets/event/rd_absence_sheet.dart';
import '../widgets/rd_group_switch.dart';
import '../widgets/rd_logo.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/work/rd_work_files.dart' show showRdWorkFilesShortcuts;
import 'rd_appearance_page.dart' show rdModeName, rdWorldName;

/// REDESIGN: tab "Ich" (canvas E1): own profile, things for me, the app,
/// help and the account. Verwaltung leads to the old settings sorted into
/// six areas (rd_manage_page.dart).

/// Desktop and web (where the Werk file table and its keys are used).
bool get _hasKeyboard =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

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
    final showManage = rdShowsManage(ref.watch(rdManageAccessProvider));
    final pending = isLead ? (ref.watch(pendingPlayersProvider).valueOrNull?.length ?? 0) : 0;
    final canReportAbsence = player != null && ref.watch(canSelfReportAbsenceProvider);
    final canPause = player != null && ref.watch(canSelfPauseProvider);
    final language = ref.watch(localeProvider).languageCode;
    final accountCount = ref.watch(savedAccountsProvider).valueOrNull?.length ?? 0;
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
        if (showManage) ...[
          const SizedBox(height: 20),
          RdGroupedList(
            children: [
              RdListRow(
                leading: const RdRowIcon(Icons.admin_panel_settings_outlined),
                title: l10n.redesignMeAdmin,
                subtitle: isLead ? l10n.redesignMeAdminHint : null,
                trailing: pending > 0 ? RdCountBadge(pending) : null,
                onTap: () => context.push(RedesignRoutes.manage),
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
                onTap: () => showRdAbsenceSheet(
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
            // Everyone who had the old settings page (incl. parents and
            // viewers) keeps the notification settings.
            if (!role.isApplicant)
              RdListRow(
                leading: const RdRowIcon(Icons.notifications_outlined),
                title: l10n.redesignMeNotifications,
                onTap: () => context.push(RedesignRoutes.notifications),
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
            // Keys of the Werk file table: editors on devices with a
            // keyboard (desktop, web); the table shows once the Werk column
            // is wide enough. Kept here, off the main UI.
            if (isLead && _hasKeyboard)
              RdListRow(
                leading: const RdRowIcon(Icons.keyboard_outlined),
                title: l10n.redesignFilesShortcuts,
                onTap: () => showRdWorkFilesShortcuts(context),
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
            // Like the old settings: "Update installieren" while a new web
            // version is waiting, "Administration" for developers.
            if (ref.watch(appUpdateAvailableProvider))
              RdListRow(
                leading: RdRowIcon(Icons.cloud_download_outlined, color: p.present, background: p.presentSoft),
                title: l10n.settingsInstallUpdate,
                titleColor: p.present,
                showChevron: false,
                onTap: () => ref.read(appUpdateServiceProvider).applyUpdate(),
              ),
            if (ref.watch(isSuperDeveloperProvider))
              RdListRow(
                leading: const RdRowIcon(Icons.construction_outlined),
                title: l10n.adminTitle,
                onTap: () => context.push('/settings/administration'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.redesignMeAccount),
        RdGroupedList(
          children: [
            // ACCOUNT_SWITCH: saved accounts of this device.
            RdListRow(
              leading: const RdRowIcon(Icons.switch_account_outlined),
              title: l10n.redesignAccountsTitle,
              value: accountCount > 1 ? l10n.redesignAccountsCount(accountCount) : null,
              onTap: () => showRdAccountSwitchSheet(context),
            ),
            RdListRow(
              leading: const RdRowIcon(Icons.key_outlined),
              title: l10n.settingsChangePassword,
              onTap: () => showChangePasswordDialog(context),
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
        // Like the old settings (and required by the App Store): the
        // account can be deleted from the app.
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => context.push('/settings/delete-account'),
            style: TextButton.styleFrom(foregroundColor: p.text2),
            child: Text(
              l10n.settingsDeleteAccount,
              style: const TextStyle(fontSize: 13, decoration: TextDecoration.underline),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Center(child: RdLogo(size: 44)),
        const SizedBox(height: 8),
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
    // Own attendance (UX S1): until now only in the label of "Vergangen".
    final signout = role.canSeeSelfServiceTab ? ref.watch(rdSignoutDataProvider).valueOrNull : null;
    final showAttendance = person != null && signout != null && signout.past.isNotEmpty;
    // ACCOUNT_SWITCH: name, role and group for the account switcher (no-op
    // when unchanged or when the account is not saved).
    // Only a loaded profile of THIS account (the old account's profile can
    // still be shown for a moment after a switch).
    final userId = ref.watch(currentAuthUserIdProvider);
    final profile = ref.watch(ownProfileProvider);
    if (userId != null &&
        name.isNotEmpty &&
        !profile.isLoading &&
        !profile.hasError &&
        person?.appId == userId &&
        tenant != null &&
        person?.tenantId == tenant.id) {
      final label = [roleName, group].where((s) => s.isNotEmpty).join(' · ');
      final service = ref.read(accountSwitchServiceProvider);
      scheduleMicrotask(() => service.updateProfile(userId, name: name, label: label).catchError((_) {}));
    }

    final header = Row(
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
              Text([roleName, group].where((s) => s.isNotEmpty).join(' · '), style: RdType.meta(p)),
            ],
          ),
        ),
        if (person != null) Icon(Icons.chevron_right, color: p.text2),
      ],
    );

    return RdCard(
      onTap: person == null ? null : () => showMasterDataSheet(context),
      child: !showAttendance
          ? header
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 16),
                _OwnAttendance(percent: signout.percentage, lateCount: signout.lateCount),
              ],
            ),
    );
  }
}

/// "87 % · Deine Anwesenheit" with a bar, below the profile.
class _OwnAttendance extends StatelessWidget {
  const _OwnAttendance({required this.percent, required this.lateCount});

  final int percent;
  final int lateCount;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final color = percent >= 75 ? p.present : (percent >= 50 ? p.late : p.absent);
    final hint = [l10n.redesignMeAttendance, if (lateCount > 0) l10n.redesignMeAttendanceLate(lateCount)].join(' · ');
    return Semantics(
      label: '$hint: $percent %',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$percent %', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(width: 8),
              Expanded(child: Text(hint, style: RdType.meta(p))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 100) / 100,
              minHeight: 8,
              color: color,
              backgroundColor: p.track,
            ),
          ),
        ],
      ),
    );
  }
}
