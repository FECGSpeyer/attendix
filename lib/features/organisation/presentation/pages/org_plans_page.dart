import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

/// Short German date "Mo, 03.11.2026".
String orgPlanDate(String date) {
  final d = DateTime.tryParse(date);
  if (d == null) return '';
  const days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  return '${days[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

String orgPlanPoints(int count) => count == 1 ? '1 Punkt' : '$count Punkte';

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
      actions: const [PlanSheetAction('delete', 'Plan löschen', icon: Icons.delete_outline, destructive: true)],
    );
    if (action != 'delete') return;
    final ok = await ref.read(planSettingsNotifierProvider.notifier).deleteAdHocOrgPlan(entry.sharedPlan!.id);
    if (!ok && mounted) ToastHelper.showError(context, 'Fehler beim Löschen');
  }

  Future<void> _subscribeCalendar(String key) async {
    final base = '${SupabaseConfig.supabaseUrl}/functions/v1/ical-org-plans?key=$key';
    final link = await showPlanActionSheet<String>(
      context,
      title: 'Kalender abonnieren',
      actions: [
        PlanSheetAction(base, 'Einfach (1 Termin je Plan)', icon: Icons.event),
        PlanSheetAction('$base&detailed=true', 'Detailliert (je Programmpunkt)', icon: Icons.event_note),
      ],
    );
    if (link == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kalender abonnieren'),
        content: SelectableText('Kopiere den folgenden Link in deine Kalender-App:\n\n$link'),
        actions: [
          TextButton(
            onPressed: () => copyPlanLink(ctx, link),
            child: const Text('Link kopieren'),
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
            child: const Text('Anleitung öffnen'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Schließen')),
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
        title: 'Öffentlicher Link',
        actions: const [
          PlanSheetAction('copy', 'Link kopieren', icon: Icons.copy),
          PlanSheetAction('revoke', 'Link widerrufen', icon: Icons.link_off, destructive: true),
        ],
      );
      if (!mounted) return;
      if (action == 'copy') {
        await copyPlanLink(context, url);
      } else if (action == 'revoke') {
        final ok = await notifier.revokePublicPlanKey();
        if (mounted && ok) ToastHelper.showSuccess(context, 'Link widerrufen');
      }
      return;
    }
    final newKey = await notifier.generatePublicPlanKey();
    if (!mounted) return;
    if (newKey == null) {
      ToastHelper.showError(context, 'Fehler beim Erstellen des Links');
      return;
    }
    await copyPlanLink(context, planPublicUrl('/org-plan?key=$newKey'), message: 'Link erstellt und kopiert');
  }

  void _showHistory(List<OrgPlanEntry> past) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Vergangene Pläne')),
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
        title: const Text('Org-Pläne'),
        actions: [
          // SETTINGS2: Ionic toggleOrgTab ("Als Tab anzeigen" / "Tab ausblenden")
          IconButton(
            tooltip: ref.watch(optionalTabsNotifierProvider).orgPlans
                ? 'Tab ausblenden'
                : 'Als Tab anzeigen',
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
                if (context.mounted) ToastHelper.showError(context, 'Fehler beim Speichern');
              }
            },
          ),
          if (key != null)
            IconButton(
              tooltip: 'Kalender abonnieren',
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: () => _subscribeCalendar(key),
            ),
          if (org != null)
            IconButton(
              tooltip: 'Öffentlicher Link',
              icon: Icon(key != null ? Icons.link : Icons.add_link),
              onPressed: () => _managePublicLink(key),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(orgPlansProvider);
          await ref.read(orgPlansProvider.future).catchError((_) => <OrgPlanEntry>[]);
        },
        child: ListView(
          children: [
            if (orgAsync.isLoading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (org == null)
              const ListTile(
                leading: Icon(Icons.info_outline, color: AppColors.medium),
                title: Text('Diese Instanz ist keiner Organisation zugeordnet.'),
              )
            else
              ...plansAsync.when(
                loading: () => [
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                ],
                error: (e, _) => [ListTile(title: Text('Fehler: $e'))],
                data: (entries) {
                  final split = splitOrgPlanEntries(entries);
                  return [
                    if (split.upcoming.isEmpty)
                      const ListTile(
                        leading: Icon(Icons.event_outlined, color: AppColors.medium),
                        title: Text(
                            'Keine bevorstehenden Org-Pläne. Pläne können über die Ablaufplanung zur Organisation hinzugefügt werden.'),
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
                            title: const Text('Ablaufplanung öffnen', style: TextStyle(color: AppColors.primary)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/settings/org-plans/planung'),
                          ),
                          if (split.past.isNotEmpty)
                            ListTile(
                              leading: const Icon(Icons.history, color: AppColors.medium),
                              title: const Text('Vergangene Pläne', style: TextStyle(color: AppColors.medium)),
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
                          title: const Text(
                              'Öffentlicher Link aktiv. Alle Org-Pläne sind für jeden mit dem Link einsehbar.'),
                          trailing: TextButton(
                            onPressed: () => _managePublicLink(key),
                            child: const Text('Verwalten'),
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

