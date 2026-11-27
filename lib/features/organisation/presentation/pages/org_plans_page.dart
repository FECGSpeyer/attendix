import 'package:flutter/foundation.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/adaptive/adaptive.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/optional_tabs_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../planning/presentation/pages/plan_viewer_page.dart';
import '../../../planning/presentation/widgets/plan_export_actions.dart';
import '../../../planning/presentation/widgets/plan_field_dialogs.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/services/native/native_file_service.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../planning/presentation/widgets/rd_plan_widgets.dart';
import '../../../redesign/presentation/widgets/manage/rd_manage_list.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';

/// Short date "Mo, 03.11.2026" (Ionic dayjs `dd, ${dateFmt()}`).
String orgPlanDate(String date) {
  final d = DateTime.tryParse(date);
  if (d == null) return '';
  const minDays = {
    'de': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
    'en': ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
  };
  final day = minDays[currentLanguage()]?[d.weekday - 1] ?? DateFormat('E', currentIntlLocale()).format(d);
  return '$day, ${DateFormat(dateFmt()).format(d)}';
}

String orgPlanPoints(int count) => l10nWithoutContext.plansPoints(count);

/// Opens an org plan entry in the plan viewer (live by default on its day).
Future<void> openOrgPlanEntry(BuildContext context, OrgPlanEntry entry) {
  final d = entry.dateTime;
  final now = DateTime.now();
  final isToday = d != null && d.year == now.year && d.month == now.month && d.day == now.day;
  final att = entry.attendance ?? PlanAttendance(id: null, date: entry.date);
  return showPlanViewer(
    context,
    attendance: att,
    plan: entry.plan,
    title: entry.title,
    defaultLive: isToday,
  );
}

/// Org-Pläne of the organisation (Ionic `OrgPlansPage`).
class OrgPlansPage extends ConsumerStatefulWidget {
  const OrgPlansPage({super.key});

  @override
  ConsumerState<OrgPlansPage> createState() => _OrgPlansPageState();
}

class _OrgPlansPageState extends ConsumerState<OrgPlansPage> {
  Future<void> _deleteAdHoc(OrgPlanEntry entry) async {
    final action = await showPlanActionSheet<String>(
      context,
      title: entry.title,
      actions: [
        PlanSheetAction('delete', context.l10n.planningDeletePlan, icon: AppIcons.deleteOutline, destructive: true),
      ],
    );
    if (action != 'delete') return;
    final ok = await ref.read(planSettingsNotifierProvider.notifier).deleteAdHocOrgPlan(entry.sharedPlan!.id);
    if (!ok && mounted) ToastHelper.showError(context, context.l10n.plansDeleteFailed);
  }

  Future<void> _subscribeCalendar(String key) async {
    // Ionic: calendar texts in the app language (German is the default).
    final lang = currentLanguage() != 'de' ? '&lang=${currentLanguage()}' : '';
    final base = '${SupabaseConfig.supabaseUrl}/functions/v1/ical-org-plans?key=$key$lang';
    final link = await showPlanActionSheet<String>(
      context,
      title: context.l10n.plansSubscribeCalendar,
      actions: [
        PlanSheetAction(base, context.l10n.plansSimpleCalendar, icon: AppIcons.event),
        PlanSheetAction('$base&detailed=true', context.l10n.plansDetailedCalendar, icon: AppIcons.eventNote),
      ],
    );
    if (link == null || !mounted) return;
    await showAppDialog<void>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(ctx.l10n.plansSubscribeCalendar),
        content: SelectableText(ctx.l10n.plansCalendarLinkMessage(link)),
        actions: [
          TextButton(
            onPressed: () => copyPlanLink(ctx, link),
            child: Text(ctx.l10n.plansCopyLink),
          ),
          TextButton(
            onPressed: () {
              final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
              NativeFileService.openLinkInApp(
                Uri.parse(ios
                    ? 'https://support.apple.com/de-de/102301'
                    : 'https://support.google.com/calendar/answer/37100?hl=de&co=GENIE.Platform%3DAndroid'),
              );
            },
            child: Text(ctx.l10n.plansOpenGuide),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.commonClose)),
        ],
      ),
    );
  }

  Future<void> _managePublicLink(String? key) async {
    final notifier = ref.read(planSettingsNotifierProvider.notifier);
    if (key != null) {
      final url = planPublicUrl('/org-plan?key=$key');
      final action = await showPlanActionSheet<String>(
        context,
        title: context.l10n.plansPublicLink,
        actions: [
          PlanSheetAction('copy', context.l10n.plansCopyLink, icon: AppIcons.copy),
          PlanSheetAction('revoke', context.l10n.plansRevokeLink, icon: AppIcons.linkOff, destructive: true),
        ],
      );
      if (!mounted) return;
      if (action == 'copy') {
        await copyPlanLink(context, url);
      } else if (action == 'revoke') {
        final ok = await notifier.revokePublicPlanKey();
        if (!mounted) return;
        // Ionic OrganisationService.revokePublicPlanKey: danger toast on error,
        // otherwise the admin doesn't learn that the link is still active.
        ok
            ? ToastHelper.showSuccess(context, context.l10n.plansRevokeLink)
            : ToastHelper.showError(context, context.l10n.svcRevokePublicLinkFailed);
      }
      return;
    }
    final newKey = await notifier.generatePublicPlanKey();
    if (!mounted) return;
    if (newKey == null) {
      ToastHelper.showError(context, context.l10n.plansLinkFailed);
      return;
    }
    await copyPlanLink(context, planPublicUrl('/org-plan?key=$newKey'), message: context.l10n.plansLinkCreated);
  }

  /// REDESIGN (Termin-Werkzeuge T2): Org-Pläne as a Verwaltungsliste. Tap
  /// opens "Ablauf ansehen", "+" the Ablaufplanung, calendar, public link,
  /// past plans and the tab switch sit behind •••.
  Widget _buildBeta(BuildContext context) {
    final l10n = context.l10n;
    final orgAsync = ref.watch(currentOrganisationProvider);
    // TENANT: after a group switch the providers still hold the old group's
    // values while reloading; show loading and offer no actions until then.
    final org = rdLoadedValue(orgAsync);
    final plansAsync = ref.watch(orgPlansProvider);
    final key = org?.publicPlanKey;
    final entries = rdLoadedValue(plansAsync);
    final orgReady = orgAsync.hasValue && !orgAsync.hasError && !(orgAsync.isLoading && !orgAsync.isRefreshing);
    final split = entries == null ? null : splitOrgPlanEntries(entries);
    final showTab = ref.watch(optionalTabsNotifierProvider).orgPlans;
    return RdManageListPage(
      title: l10n.plansOrgPlans,
      intro: org != null ? l10n.redesignPlanOrgPlansIntro(org.name) : (orgReady ? l10n.plansNoOrg : ''),
      notice: key != null ? l10n.plansPublicLinkActive : null,
      loadFailed: (orgAsync.hasError && org == null) || (plansAsync.hasError && entries == null),
      // The plans read the Organisation; a stored Organisation error must be
      // retried too, or the plans get the same error again.
      onRetry: () {
        if (orgAsync.hasError) ref.invalidate(currentOrganisationProvider);
        ref.invalidate(orgPlansProvider);
      },
      onRefresh: () async {
        if (orgAsync.hasError) ref.invalidate(currentOrganisationProvider);
        ref.invalidate(orgPlansProvider);
        await ref.read(orgPlansProvider.future).catchError((_) => <OrgPlanEntry>[]);
      },
      emptyText: l10n.plansNoUpcomingOrgPlans,
      emptyIcon: Icons.event_note_outlined,
      sections: !orgReady
          ? null
          : org == null
          ? const []
          : split == null
          ? null
          : [
              if (split.upcoming.isNotEmpty)
                RdManageListSection(
                  title: l10n.redesignPlanOrgPlansUpcoming,
                  items: [for (final e in split.upcoming) _rdItem(e)],
                ),
            ],
      addLabel: org == null ? null : l10n.plansOpenPlanning,
      onAdd: org == null ? null : () => context.push(_planningRoute(context)),
      actions: [
        if (split != null && split.past.isNotEmpty)
          RdManageListAction(label: l10n.plansPastPlans, icon: Icons.history, onSelected: _rdShowHistory),
        if (key != null)
          RdManageListAction(
            label: l10n.plansSubscribeCalendar,
            icon: Icons.calendar_month_outlined,
            onSelected: () => _subscribeCalendar(key),
          ),
        if (org != null)
          RdManageListAction(
            label: l10n.plansPublicLink,
            icon: key != null ? Icons.link : Icons.add_link,
            onSelected: () => _managePublicLink(key),
          ),
        RdManageListAction(
          label: showTab ? l10n.plansFlutterHideTab : l10n.plansFlutterShowAsTab,
          icon: showTab ? Icons.bookmark : Icons.bookmark_outline,
          onSelected: () async {
            try {
              await ref.read(optionalTabsNotifierProvider.notifier).setShowOrgPlansTab(!showTab);
            } catch (_) {
              if (context.mounted) ToastHelper.showError(context, context.l10n.plansSaveFailed);
            }
          },
        ),
      ],
    );
  }

  RdManageListItem _rdItem(OrgPlanEntry e) {
    final count = e.fieldCount;
    final sub = [
      orgPlanDate(e.date),
      if (count > 0) orgPlanPoints(count),
      if (e.tenantLabel.isNotEmpty) e.tenantLabel,
    ].join(' · ');
    return RdManageListItem(
      id: e.sharedPlan?.id ?? '${e.attendance?.id}-${e.date}-${e.title}',
      title: e.title,
      subtitle: sub,
      icon: e.isAdHoc ? Icons.edit_note : Icons.event_note_outlined,
      trailing: e.isAdHoc
          ? IconButton(
              tooltip: context.l10n.redesignPlanMore,
              icon: Icon(Icons.more_horiz, color: context.rd.text2),
              onPressed: () => _deleteAdHoc(e),
            )
          : null,
      onTap: () => openOrgPlanEntry(context, e),
    );
  }

  void _rdShowHistory() {
    showRdPlanSheet<void>(
      context,
      title: context.l10n.plansPastPlans,
      builder: (ctx, pop) => [
        Consumer(
          builder: (context, ref, _) {
            final entries = ref.watch(orgPlansProvider).valueOrNull;
            final past = entries == null ? const <OrgPlanEntry>[] : splitOrgPlanEntries(entries).past;
            return RdGroupedList(
              children: [
                for (final e in past)
                  RdListRow(
                    leading: const RdRowIcon(Icons.history),
                    title: e.title,
                    subtitle: [orgPlanDate(e.date), if (e.tenantLabel.isNotEmpty) e.tenantLabel].join(' · '),
                    showChevron: !e.isAdHoc,
                    trailing: e.isAdHoc
                        ? IconButton(
                          tooltip: context.l10n.commonDelete,
                          icon: Icon(Icons.delete_outline, color: context.rd.text2),
                          onPressed: () => _deleteAdHoc(e),
                        )
                        : null,
                    onTap: () => openOrgPlanEntry(context, e),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => _buildBeta(context);
}

/// P10_SELF_PLAN: Ionic `isTabRoute` – opened as the optional "Org" tab.
bool _isTabRoute(BuildContext context) =>
    GoRouterState.of(context).matchedLocation.startsWith('/org-plans-tab');

/// Ionic: '/tabs/org-plans/planung' in the tab, otherwise the settings route.
String _planningRoute(BuildContext context) =>
    _isTabRoute(context) ? '/org-plans-tab/planung' : '/settings/org-plans/planung';
