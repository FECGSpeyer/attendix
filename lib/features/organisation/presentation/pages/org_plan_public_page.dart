import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/services/plan_export_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/plan/plan.dart';
import '../../../../data/repositories/public_plan_repository.dart';
import '../../../planning/presentation/widgets/plan_export_actions.dart';
import '../../../planning/presentation/widgets/plan_field_dialogs.dart';
import '../../../planning/presentation/widgets/plan_view_list.dart';
import 'org_plans_page.dart' show orgPlanDate, orgPlanPoints;

/// Public list of all org plans via `/org-plan?key=<public_plan_key>`
/// (Ionic `OrgPlanPublicPage`). No login required.
class OrgPlanPublicPage extends ConsumerStatefulWidget {
  const OrgPlanPublicPage({super.key, this.publicKey});

  final String? publicKey;

  @override
  ConsumerState<OrgPlanPublicPage> createState() => _OrgPlanPublicPageState();
}

class _OrgPlanPublicPageState extends ConsumerState<OrgPlanPublicPage> {
  bool _loading = true;
  bool _notFound = false;
  String _orgName = '';
  int? _orgId;
  List<OrgPlanEntry> _upcoming = [];
  List<OrgPlanEntry> _past = [];
  final Set<String> _live = {};
  final List<RealtimeChannel> _channels = [];

  PublicPlanRepository get _repo => ref.read(publicPlanRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _unsubscribe() {
    for (final c in _channels) {
      _repo.unwatch(c);
    }
    _channels.clear();
  }

  Future<void> _init() async {
    final key = widget.publicKey;
    if (key == null || key.isEmpty) {
      setState(() {
        _notFound = true;
        _loading = false;
      });
      return;
    }
    try {
      final org = await _repo.getOrgByPublicKey(key);
      if (org == null) {
        setState(() {
          _notFound = true;
          _loading = false;
        });
        return;
      }
      _orgName = org.name;
      _orgId = org.id;
      await _loadPlans();
    } catch (_) {
      if (mounted) {
        setState(() {
          _notFound = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadPlans() async {
    if (_orgId == null) return;
    setState(() => _loading = true);
    _unsubscribe();
    final result = await _repo.getPublicOrgPlans(_orgId!);
    final entries = [
      ...result.attendances.where((a) => a.plan != null).map(OrgPlanEntry.attendance),
      ...result.adHoc.map(OrgPlanEntry.adHoc),
    ];
    final split = splitOrgPlanEntries(entries);
    if (!mounted) return;
    setState(() {
      _upcoming = split.upcoming;
      _past = split.past;
      _loading = false;
      _live
        ..clear()
        ..addAll(split.upcoming.where(_isLiveNow).map((e) => e.key));
    });
    for (final e in split.upcoming) {
      _subscribe(e);
    }
  }

  void _subscribe(OrgPlanEntry entry) {
    if (entry.attendance?.id != null) {
      final att = entry.attendance!;
      _channels.add(_repo.watchSharedAttendancePlan(att.id!, (row) {
        if (row['plan'] == null) return;
        try {
          final plan = Plan.fromJson(Map<String, dynamic>.from(row['plan'] as Map));
          _replace(entry.key, OrgPlanEntry.attendance(att.copyWith(plan: plan)));
        } catch (_) {}
      }));
    } else if (entry.sharedPlan != null) {
      final sp = entry.sharedPlan!;
      _channels.add(_repo.watchSharedPlan(sp.id, (row) {
        try {
          _replace(entry.key, OrgPlanEntry.adHoc(SharedPlan.fromJson({...sp.toJson(), ...row})));
        } catch (_) {}
      }));
    }
  }

  void _replace(String key, OrgPlanEntry updated) {
    if (!mounted) return;
    setState(() {
      _upcoming = [for (final e in _upcoming) e.key == key ? updated : e];
    });
  }

  bool _isLiveNow(OrgPlanEntry e) {
    final d = e.dateTime;
    final now = DateTime.now();
    if (d == null || d.year != now.year || d.month != now.month || d.day != now.day) return false;
    return PlanUtils.isLiveNow(d, e.plan.time, e.plan.fields);
  }

  Future<void> _subscribeCalendar() async {
    final base = '${SupabaseConfig.supabaseUrl}/functions/v1/ical-org-plans?key=${widget.publicKey}';
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
          TextButton(onPressed: () => copyPlanLink(ctx, link), child: const Text('Link kopieren')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Schließen')),
        ],
      ),
    );
  }

  Future<void> _export(OrgPlanEntry e) async {
    await showPlanExportSheet(
      context,
      ref,
      withImage: false,
      pages: () => [
        PlanExportPage(
          title: e.title,
          subtitle: PlanUtils.longDate(e.dateTime),
          time: e.plan.time,
          end: e.plan.end,
          fields: e.plan.fields,
        ),
      ],
      fileName: e.title,
    );
  }

  Widget _planCard(OrgPlanEntry e) {
    final live = _live.contains(e.key);
    final liveNow = _isLiveNow(e);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text([
              PlanUtils.longDate(e.dateTime),
              if (e.tenantLabel.isNotEmpty) e.tenantLabel,
            ].join(' · ')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (liveNow)
                  IconButton(
                    tooltip: 'Live',
                    icon: Icon(live ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: live ? Colors.red : null),
                    onPressed: () => setState(() => live ? _live.remove(e.key) : _live.add(e.key)),
                  ),
                IconButton(
                  tooltip: 'Exportieren',
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => _export(e),
                ),
              ],
            ),
          ),
          PlanViewList(plan: e.plan, date: e.dateTime, liveMode: live),
        ],
      ),
    );
  }

  void _showHistory() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Vergangene Pläne')),
        body: ListView(
          children: [
            for (final e in _past)
              ListTile(
                title: Text(e.title),
                subtitle: Text(
                    '${orgPlanDate(e.date)}${e.fieldCount > 0 ? ' · ${orgPlanPoints(e.fieldCount)}' : ''}'
                    '${e.tenantLabel.isNotEmpty ? '\n${e.tenantLabel}' : ''}'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(orgPlanDate(e.date))),
                    body: ListView(children: [_planCard(e)]),
                  ),
                )),
              ),
          ],
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_orgName.isNotEmpty ? _orgName : 'Org-Pläne'),
        actions: [
          if (!_notFound && !_loading)
            IconButton(
              tooltip: 'Kalender abonnieren',
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: _subscribeCalendar,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notFound
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Link ungültig oder abgelaufen.'),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPlans,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (_upcoming.isEmpty)
                        const ListTile(
                          leading: Icon(Icons.event_outlined, color: AppColors.medium),
                          title: Text('Keine bevorstehenden Org-Pläne vorhanden.'),
                        ),
                      for (final e in _upcoming) _planCard(e),
                      if (_past.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: OutlinedButton.icon(
                            onPressed: _showHistory,
                            icon: const Icon(Icons.history),
                            label: const Text('Vergangene Pläne'),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
