import 'package:flutter/foundation.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/optional_tabs_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../planning/presentation/pages/plan_viewer_page.dart';
import '../../../planning/presentation/widgets/plan_export_actions.dart';
import '../../../planning/presentation/widgets/plan_field_dialogs.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/widgets/ion_condense.dart';
import '../../../settings/presentation/widgets/settings_list.dart';
import '../../../../core/utils/error_message.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonTranslucentAppBar, IonContentTopInset, IonRefresher;
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/layout/ios_tab_bar.dart' show scrollEndPadding, TabBarFab;
import '../../../../core/services/native/native_file_service.dart';
import '../../../../shared/widgets/dialogs/ion_modal.dart' show showIonModal;
import '../../../../shared/widgets/layout/ionic_md.dart' show IonMd;
import '../../../../shared/widgets/loading/skeleton_base.dart' show SkeletonText;
import '../../../planning/presentation/widgets/ion_items.dart' show IonDetailIcon;
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../planning/presentation/widgets/rd_plan_widgets.dart';
import '../../../redesign/presentation/widgets/manage/rd_manage_list.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';

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

  /// Ionic: the history modal is bound to `pastPlans`, so a deleted plan
  /// disappears right away – the page watches the plans instead of a copy.
  /// ABL-08: an `ion-modal` with title, close ✕ and one inset list (full
  /// screen on phones, centred card from 768px).
  void _showHistory() {
    showIonModal<void>(
      context,
      builder: (_) => Consumer(builder: (context, ref, _) {
        final entries = ref.watch(orgPlansProvider).valueOrNull;
        final past = entries == null ? const <OrgPlanEntry>[] : splitOrgPlanEntries(entries).past;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(context.l10n.plansPastPlans),
            actions: const [IonCloseButton()],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (past.isNotEmpty)
                _orgPlansBox(context, [for (final e in past) _entryTile(e)], margin: const EdgeInsets.all(16)),
            ],
          ),
        );
      }),
    );
  }

  /// Ionic `ion-item button detail`: h2 title, `.plan-meta` line (0.8rem
  /// medium), `.tenant-label` (0.75rem, 600, uppercase, 0.04em) and, for
  /// ad-hoc plans, a medium trash button before the detail chevron (ABL-19).
  Widget _entryTile(OrgPlanEntry entry) {
    final count = entry.fieldCount;
    return ListTile(
      title: Text(entry.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${orgPlanDate(entry.date)}${count > 0 ? ' · ${orgPlanPoints(count)}' : ''}',
              style: const TextStyle(fontSize: 13.6, color: AppColors.medium)),
          if (entry.tenantLabel.isNotEmpty)
            Text(entry.tenantLabel.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.48, color: AppColors.medium)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.isAdHoc)
            IconButton(
              icon: Icon(AppIcons.deleteOutline, color: AppColors.medium, semanticLabel: context.l10n.commonDelete),
              onPressed: () => _deleteAdHoc(entry),
            ),
          const IonDetailIcon(),
        ],
      ),
      onTap: () => openOrgPlanEntry(context, entry),
    );
  }

  /// Ionic skeleton list while the plans load (three items, 55 % / 35 %).
  Widget _skeleton(BuildContext context) => _orgPlansBox(context, [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(widthFactor: 0.55, height: 16),
                SizedBox(height: 6),
                SkeletonText(widthFactor: 0.35, height: 12),
              ],
            ),
          ),
      ], margin: const EdgeInsets.all(16));

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
  Widget build(BuildContext context) {
    if (context.rdSkin != null) return _buildBeta(context);
    final orgAsync = ref.watch(currentOrganisationProvider);
    final org = orgAsync.valueOrNull;
    final plansAsync = ref.watch(orgPlansProvider);
    final key = org?.publicPlanKey;

    // UX_SETTINGS (WAVE 8): org-plans.page.html — condense title and
    // inset lists on the light page (iOS).
    return IonCondense(builder: (context, collapsed) => Scaffold(
      // IOS_R6: Ionic `ion-content fullscreen` under the translucent header
      extendBodyBehindAppBar: ionIsIos(context),
      // IOS_R6: `ion-header translucent` (blur once condensed)
      appBar: IonTranslucentAppBar(condensed: collapsed, child: AppBar(
        title: IonCondenseTitle(context.l10n.plansOrgPlans, collapsed: collapsed),
        // ABL-18: one `ion-buttons slot="end"` (iOS: one glass capsule).
        actions: [
          ToolbarButtonGroup(children: [
          // SETTINGS2: Ionic toggleOrgTab ("Als Tab anzeigen" / "Tab ausblenden")
          IconButton(
            tooltip: ref.watch(optionalTabsNotifierProvider).orgPlans
                ? context.l10n.plansFlutterHideTab
                : context.l10n.plansFlutterShowAsTab,
            icon: Icon(ref.watch(optionalTabsNotifierProvider).orgPlans
                ? AppIcons.bookmark
                : AppIcons.bookmarkOutline),
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
              icon: Icon(AppIcons.calendarMonthOutlined),
              onPressed: () => _subscribeCalendar(key),
            ),
          if (org != null)
            IconButton(
              tooltip: context.l10n.plansPublicLink,
              // ABL-19: Ionic `link` (active) / `link-outline`.
              icon: Icon(key != null ? AppIcons.linkFilled : AppIcons.addLink),
              onPressed: () => _managePublicLink(key),
            ),
          ]),
        ],
      )),
      // P10_SELF_PLAN: Ionic `@if (isTabRoute && isIos)` ion-fab "+".
      floatingActionButton: _isTabRoute(context) && ionIsIos(context)
          ? TabBarFab(
              child: FloatingActionButton(
                heroTag: 'orgPlansTabFab',
                tooltip: context.l10n.plansOpenPlanning,
                onPressed: () => context.push(_planningRoute(context)),
                child: Icon(AppIcons.add),
              ),
            )
          : null,
      body: IonRefresher(
        onRefresh: () async {
          ref.invalidate(orgPlansProvider);
          await ref.read(orgPlansProvider.future).catchError((_) => <OrgPlanEntry>[]);
        },
        child: ListView(
          // PARITY_R7: list end 16pt above the floating tab bar (Ionic
          // ion-content padding-bottom), like the other tab root pages.
          padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: 16)),
          children: [
            const IonContentTopInset(),
            IonLargeTitle(context.l10n.plansOrgPlans),
            if (orgAsync.isLoading)
              _skeleton(context)
            else if (org == null)
              _orgPlansBox(context, [
                ListTile(
                  leading: Icon(AppIcons.infoOutline, color: AppColors.medium),
                  title: Text(context.l10n.plansNoOrg),
                ),
              ], margin: const EdgeInsets.all(16))
            else
              ...plansAsync.when(
                loading: () => [_skeleton(context)],
                error: (e, _) => [ListTile(title: Text(context.l10n.planningFlutterErrorWith(friendlyErrorMessage(e))))],
                data: (entries) {
                  final split = splitOrgPlanEntries(entries);
                  return [
                    if (split.upcoming.isEmpty)
                      _orgPlansBox(context, [
                        ListTile(
                          leading: Icon(AppIcons.eventOutlined, color: AppColors.medium),
                          title: Text(context.l10n.plansNoUpcomingOrgPlans),
                        ),
                      ], margin: const EdgeInsets.all(16))
                    else
                      _orgPlansBox(context, [for (final e in split.upcoming) _entryTile(e)],
                          margin: const EdgeInsets.all(16)),
                    _orgPlansBox(context, margin: const EdgeInsets.symmetric(horizontal: 16), [
                          ListTile(
                            leading: Icon(AppIcons.addCircleOutline, color: AppColors.primary),
                            title: Text(context.l10n.plansOpenPlanning, style: const TextStyle(color: AppColors.primary)),
                            trailing: const IonDetailIcon(),
                            onTap: () => context.push(_planningRoute(context)),
                          ),
                          if (split.past.isNotEmpty)
                            ListTile(
                              leading: Icon(AppIcons.history, color: AppColors.medium),
                              title: Text(context.l10n.plansPastPlans, style: const TextStyle(color: AppColors.medium)),
                              onTap: _showHistory,
                            ),
                    ]),
                    if (key != null)
                      _orgPlansBox(context, margin: const EdgeInsets.all(16), [ListTile(
                          leading: Icon(AppIcons.public, color: AppColors.success),
                          title: Text(context.l10n.plansPublicLinkActive),
                          trailing: TextButton(
                            onPressed: () => _managePublicLink(key),
                            child: IonButtonLabel(context.l10n.plansManage),
                          ),
                        )]),
                  ];
                },
              ),
          ],
        ),
      ),
    ));
  }
}

/// P10_SELF_PLAN: Ionic `isTabRoute` – opened as the optional "Org" tab.
bool _isTabRoute(BuildContext context) =>
    GoRouterState.of(context).matchedLocation.startsWith('/org-plans-tab');

/// Ionic: '/tabs/org-plans/planung' in the tab, otherwise the settings route.
String _planningRoute(BuildContext context) =>
    _isTabRoute(context) ? '/org-plans-tab/planung' : '/settings/org-plans/planung';

/// Ionic `ion-list [inset]`: iOS item group with hairlines (margin 16);
/// ABL-07: md the md-ion-list-inset item group (radius 16, item
/// background, no shadow, 1px inset lines) instead of a Material card.
Widget _orgPlansBox(
  BuildContext context,
  List<Widget> children, {
  EdgeInsetsGeometry margin = EdgeInsets.zero,
}) {
  if (ionIsIos(context)) {
    return Padding(padding: margin, child: IonInsetGroup(children: children));
  }
  final b = Theme.of(context).brightness;
  return Padding(
    padding: margin,
    child: Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: IonMd.itemBackground(b),
      shape: IonMd.insetGroupShape,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: IonMd.lineWidth, thickness: IonMd.lineWidth, indent: IonMd.itemPaddingStart),
            children[i],
          ],
        ],
      ),
    ),
  );
}
