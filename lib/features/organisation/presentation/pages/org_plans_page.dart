import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/optional_tabs_providers.dart'; // SETTINGS2
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../planning/presentation/pages/plan_viewer_page.dart';
import '../../../planning/presentation/widgets/plan_export_actions.dart';
import '../../../planning/presentation/widgets/plan_field_dialogs.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

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
        PlanSheetAction('delete', context.l10n.planningDeletePlan, icon: Icons.delete_outline, destructive: true),
      ],
    );
    if (action != 'delete') return;
    final ok = await ref.read(planSettingsNotifierProvider.notifier).deleteAdHocOrgPlan(entry.sharedPlan!.id);
    if (!ok && mounted) ToastHelper.showError(context, context.l10n.plansDeleteFailed);
  }

  Future<void> _subscribeCalendar(String key) async {
    final base = '${SupabaseConfig.supabaseUrl}/functions/v1/ical-org-plans?key=$key';
    final link = await showPlanActionSheet<String>(
      context,
      title: context.l10n.plansSubscribeCalendar,
      actions: [
        PlanSheetAction(base, context.l10n.plansSimpleCalendar, icon: Icons.event),
        PlanSheetAction('$base&detailed=true', context.l10n.plansDetailedCalendar, icon: Icons.event_note),
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
              launchUrl(
                Uri.parse(ios
                    ? 'https://support.apple.com/de-de/102301'
                    : 'https://support.google.com/calendar/answer/37100?hl=de&co=GENIE.Platform%3DAndroid'),
                mode: LaunchMode.externalApplication,
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
          PlanSheetAction('copy', context.l10n.plansCopyLink, icon: Icons.copy),
          PlanSheetAction('revoke', context.l10n.plansRevokeLink, icon: Icons.link_off, destructive: true),
        ],
      );
      if (!mounted) return;
      if (action == 'copy') {
        await copyPlanLink(context, url);
      } else if (action == 'revoke') {
        final ok = await notifier.revokePublicPlanKey();
        if (mounted && ok) ToastHelper.showSuccess(context, context.l10n.plansRevokeLink);
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

  void _showHistory(List<OrgPlanEntry> past) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.plansPastPlans)),
        body: ListView(children: [for (final e in past) _entryTile(e)]),
      ),
    ));
  }

  Widget _entryTile(OrgPlanEntry entry) {
    final count = entry.fieldCount;
    return ListTile(
      title: Text(entry.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${orgPlanDate(entry.date)}${count > 0 ? ' · ${orgPlanPoints(count)}' : ''}'),
          if (entry.tenantLabel.isNotEmpty)
            Text(entry.tenantLabel, style: const TextStyle(fontSize: 12, color: AppColors.medium)),
        ],
      ),
      trailing: entry.isAdHoc
          ? IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.medium),
              onPressed: () => _deleteAdHoc(entry),
            )
          : const Icon(Icons.chevron_right),
      onTap: () => openOrgPlanEntry(context, entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(currentOrganisationProvider);
    final org = orgAsync.valueOrNull;
    final plansAsync = ref.watch(orgPlansProvider);
    final key = org?.publicPlanKey;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.plansOrgPlans),
        actions: [
          // SETTINGS2: Ionic toggleOrgTab ("Als Tab anzeigen" / "Tab ausblenden")
          IconButton(
            tooltip: ref.watch(optionalTabsNotifierProvider).orgPlans
                ? context.l10n.plansFlutterHideTab
                : context.l10n.plansFlutterShowAsTab,
            icon: Icon(ref.watch(optionalTabsNotifierProvider).orgPlans
                ? Icons.bookmark
                : Icons.bookmark_outline),
            onPressed: () async {
              final current = ref.read(optionalTabsNotifierProvider).orgPlans;
              try {
                await ref
                    .read(optionalTabsNotifierProvider.notifier)
                    .setShowOrgPlansTab(!current);
              } catch (_) {
                if (context.mounted) ToastHelper.showError(context, context.l10n.plansSaveFailed);
              }
            },
          ),
          if (key != null)
            IconButton(
              tooltip: context.l10n.plansSubscribeCalendar,
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: () => _subscribeCalendar(key),
            ),
          if (org != null)
            IconButton(
              tooltip: context.l10n.plansPublicLink,
              icon: Icon(key != null ? Icons.link : Icons.add_link),
              onPressed: () => _managePublicLink(key),
            ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(orgPlansProvider);
          await ref.read(orgPlansProvider.future).catchError((_) => <OrgPlanEntry>[]);
        },
        child: ListView(
          children: [
            if (orgAsync.isLoading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: AppSpinner()))
            else if (org == null)
              ListTile(
                leading: const Icon(Icons.info_outline, color: AppColors.medium),
                title: Text(context.l10n.plansNoOrg),
              )
            else
              ...plansAsync.when(
                loading: () => [
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: AppSpinner())),
                ],
                error: (e, _) => [ListTile(title: Text(context.l10n.planningFlutterErrorWith(friendlyErrorMessage(e))))],
                data: (entries) {
                  final split = splitOrgPlanEntries(entries);
                  return [
                    if (split.upcoming.isEmpty)
                      ListTile(
                        leading: const Icon(Icons.event_outlined, color: AppColors.medium),
                        title: Text(context.l10n.plansNoUpcomingOrgPlans),
                      )
                    else
                      Card(
                        margin: const EdgeInsets.all(12),
                        child: Column(children: [for (final e in split.upcoming) _entryTile(e)]),
                      ),
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                            title: Text(context.l10n.plansOpenPlanning, style: const TextStyle(color: AppColors.primary)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/settings/org-plans/planung'),
                          ),
                          if (split.past.isNotEmpty)
                            ListTile(
                              leading: const Icon(Icons.history, color: AppColors.medium),
                              title: Text(context.l10n.plansPastPlans, style: const TextStyle(color: AppColors.medium)),
                              onTap: () => _showHistory(split.past),
                            ),
                        ],
                      ),
                    ),
                    if (key != null)
                      Card(
                        margin: const EdgeInsets.all(12),
                        child: ListTile(
                          leading: const Icon(Icons.public, color: AppColors.success),
                          title: Text(context.l10n.plansPublicLinkActive),
                          trailing: TextButton(
                            onPressed: () => _managePublicLink(key),
                            child: Text(context.l10n.plansManage),
                          ),
                        ),
                      ),
                  ];
                },
              ),
          ],
        ),
      ),
    );
  }
}

