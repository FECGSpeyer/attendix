import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../data/models/plan/plan.dart' show isPlanPublished;
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/components/components.dart';
import '../../../attendance/data/providers/events_providers.dart' show RdEventSection, rdGroupEvents;
import '../../../today/presentation/widgets/today_common.dart' show RdEventDateBox, RdInfoCard;
import '../pages/org_plans_page.dart' show openOrgPlanEntry, orgPlanPoints;
import 'org_info_sheet.dart' show showRdOrgInfoSheet;

/// One ORG-Plan dated today, annotated with whether it is running right now.
class RdTodayOrgPlan {
  const RdTodayOrgPlan({
    required this.entry,
    required this.isLive,
    this.timeRange = '',
    this.currentItem,
  });

  final OrgPlanEntry entry;
  final bool isLive;
  final String timeRange;
  final String? currentItem;
}

/// Pure selector for the ORG-Plan card on "Heute": published ORG-Pläne dated
/// today that are either ad-hoc ORG-Pläne or belong to another group of the
/// organisation (own-group Termine already appear as the main Termin card).
/// Live plans come first, then by start time.
List<RdTodayOrgPlan> rdTodayOrgPlans(
  List<OrgPlanEntry> entries, {
  int? currentTenantId,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final result = <({RdTodayOrgPlan item, int sortMin})>[];

  for (final e in entries) {
    final plan = e.plan;
    if (!isPlanPublished(e.isAdHoc ? e.sharedPlan : e.attendance?.plan)) continue;
    // Own-group Termine are already represented on Heute as the primary card.
    if (!e.isAdHoc && currentTenantId != null && e.attendance?.tenantId == currentTenantId) {
      continue;
    }
    final d = e.dateTime;
    if (d == null) continue;
    final day = DateTime(d.year, d.month, d.day);
    if (day != today) continue;

    final startMin = PlanUtils.parseTimeToMinutes(plan.time);
    final totalMin = PlanUtils.totalMinutes(plan.fields);
    final timeRange = startMin != null && plan.fields.isNotEmpty
        ? '${PlanUtils.formatMinutes(startMin)}–${PlanUtils.formatMinutes(startMin + totalMin)}'
        : (plan.time.isNotEmpty ? plan.time : '');
    final isLive = _isPlanLiveAt(day, plan.time, plan.fields, current);
    final currentItem = isLive ? _currentItemName(day, plan.time, plan.fields, current) : null;

    result.add((
      item: RdTodayOrgPlan(
        entry: e,
        isLive: isLive,
        timeRange: timeRange,
        currentItem: currentItem,
      ),
      sortMin: startMin ?? 9999,
    ));
  }

  result.sort((a, b) {
    if (a.item.isLive != b.item.isLive) return a.item.isLive ? -1 : 1;
    return a.sortMin.compareTo(b.sortMin);
  });
  return [for (final r in result) r.item];
}

bool _isPlanLiveAt(DateTime day, String time, List<dynamic> fields, DateTime now) {
  final startMin = PlanUtils.parseTimeToMinutes(time);
  if (startMin == null || fields.isEmpty) return false;
  final total = PlanUtils.totalMinutes(fields.cast());
  if (total <= 0) return false;
  final start = DateTime(day.year, day.month, day.day).add(Duration(minutes: startMin));
  final end = start.add(Duration(minutes: total));
  return !now.isBefore(start.subtract(const Duration(minutes: 15))) && now.isBefore(end);
}

String? _currentItemName(DateTime day, String time, List<dynamic> fields, DateTime now) {
  final startMin = PlanUtils.parseTimeToMinutes(time);
  if (startMin == null || fields.isEmpty) return null;
  var cursor = DateTime(day.year, day.month, day.day).add(Duration(minutes: startMin));
  for (final f in fields) {
    final mins = int.tryParse('${f.time}'.trim()) ?? 0;
    final end = cursor.add(Duration(minutes: mins));
    if (!now.isBefore(cursor) && now.isBefore(end)) {
      final name = '${f.name}'.trim();
      if (name.isNotEmpty) return name;
    }
    cursor = end;
  }
  return null;
}

/// Compact card on "Heute" showing today's (or currently live) ORG-Pläne of
/// other groups and ad-hoc ORG-Pläne. Renders nothing when there is no
/// organisation or no matching ORG-Plan today.
class RdTodayOrgPlansCard extends ConsumerWidget {
  const RdTodayOrgPlansCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(currentOrganisationProvider).valueOrNull;
    if (org == null) return const SizedBox.shrink();
    final entries = ref.watch(orgPlansProvider).valueOrNull;
    if (entries == null || entries.isEmpty) return const SizedBox.shrink();

    final tenantId = ref.watch(currentTenantIdProvider);
    final items = rdTodayOrgPlans(entries, currentTenantId: tenantId);
    if (items.isEmpty) return const SizedBox.shrink();

    final p = context.rd;
    final l10n = context.l10n;
    final anyLive = items.any((i) => i.isLive);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: RdCard(
        key: const Key('rd-today-org-plans-card'),
        border: Border.all(color: p.primary.withValues(alpha: 0.35)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: RdEyebrow(
                    anyLive ? l10n.rdOrgTodayLiveEyebrow : l10n.rdOrgTodayEyebrow,
                  ),
                ),
                RdOrgPill(
                  org.name,
                  compact: true,
                  showInfo: true,
                  tooltip: l10n.rdOrgInfoButtonTooltip,
                  onTap: () => showRdOrgInfoSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 18, thickness: 1, color: p.line),
              _TodayOrgPlanTile(
                item: items[i],
                orgName: org.name,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact neutral origin tag used inside an ORG container (Heute ORG card or
/// Termine › Org-Pläne), where the organisation itself is already named above.
Widget? _orgOriginPill(BuildContext context, OrgPlanEntry entry) {
  final l10n = context.l10n;
  if (entry.isAdHoc) {
    return RdPill(l10n.rdOrgAdHocShort, icon: Icons.edit_note);
  }
  if (entry.tenantLabel.isNotEmpty) {
    return RdPill(entry.tenantLabel, icon: Icons.groups_outlined);
  }
  return null;
}

class _TodayOrgPlanTile extends StatelessWidget {
  const _TodayOrgPlanTile({required this.item, required this.orgName});

  final RdTodayOrgPlan item;
  final String orgName;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final entry = item.entry;
    final origin = _orgOriginPill(context, entry);
    final meta = [
      if (item.timeRange.isNotEmpty) item.timeRange,
      if (item.currentItem != null) item.currentItem!,
      if (item.currentItem == null && entry.fieldCount > 0) orgPlanPoints(entry.fieldCount),
    ].join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => openOrgPlanEntry(
        context,
        entry,
        backLabel: l10n.redesignTabToday,
        orgName: orgName,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                  ),
                  if (origin != null || meta.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (origin != null) origin,
                        if (meta.isNotEmpty)
                          Text(meta, style: RdType.meta(p, size: 13)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: p.text2),
          ],
        ),
      ),
    );
  }
}

/// Content of the 3rd segment "Org-Pläne" inside the Termine tab (for leads
/// whose group belongs to an organisation).
class RdOrgPlansSegmentBody extends ConsumerWidget {
  const RdOrgPlansSegmentBody({
    super.key,
    required this.query,
    required this.sectionHeaderBuilder,
  });

  final String query;
  final Widget Function(RdEventSection<OrgPlanEntry> section) sectionHeaderBuilder;

  bool _matches(OrgPlanEntry e) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return e.title.toLowerCase().contains(q) || e.tenantLabel.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final org = ref.watch(currentOrganisationProvider).valueOrNull;
    final async = ref.watch(orgPlansProvider);
    final entries = async.valueOrNull;

    if (entries == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: async.hasError
            ? RdInfoCard(
                text: l10n.redesignTodayLoadFailed,
                icon: Icons.error_outline,
                action: RdOutlineButton(
                  label: l10n.redesignCommonRetry,
                  onPressed: () => ref.invalidate(orgPlansProvider),
                ),
              )
            : RdInfoCard(text: l10n.redesignTodayLoading, loading: true),
      );
    }

    final split = splitOrgPlanEntries(entries);
    final filtered = split.upcoming.where(_matches).toList();
    final sections = rdGroupEvents(filtered, (e) => e.date, past: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            if (org != null)
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: RdOrgPill(
                    org.name,
                    showInfo: true,
                    tooltip: l10n.rdOrgInfoButtonTooltip,
                    onTap: () => showRdOrgInfoSheet(context),
                  ),
                ),
              ),
            if (org == null) const Spacer(),
            RdTextLink(
              key: const Key('rd-events-org-plans-manage'),
              label: l10n.plansManage,
              onTap: () => context.push('/settings/org-plans'),
            ),
          ],
        ),
        if (org != null) ...[
          const SizedBox(height: 4),
          Text(l10n.rdOrgEventsOrgSubtitle(org.name), style: RdType.meta(p, size: 13)),
        ],
        const SizedBox(height: 6),
        if (sections.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RdInfoCard(
              text: query.trim().isNotEmpty ? l10n.redesignEventsNoMatch : l10n.plansNoUpcomingOrgPlans,
              icon: Icons.hub_outlined,
              action: query.trim().isEmpty
                  ? RdOutlineButton(
                      label: l10n.plansOpenPlanning,
                      onPressed: () => context.push('/settings/org-plans/planung'),
                    )
                  : null,
            ),
          ),
        for (final section in sections) ...[
          sectionHeaderBuilder(section),
          for (final entry in section.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OrgPlanListCard(
                entry: entry,
                orgName: org?.name,
                borderColor: p.primary.withValues(alpha: 0.28),
              ),
            ),
        ],
      ],
    );
  }
}

class _OrgPlanListCard extends StatelessWidget {
  const _OrgPlanListCard({
    required this.entry,
    required this.orgName,
    required this.borderColor,
  });

  final OrgPlanEntry entry;
  final String? orgName;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final today = EventListUtils.isRunning(entry.date, entry.attendance?.durationDays);
    final startMin = PlanUtils.parseTimeToMinutes(entry.plan.time);
    final timeRange = startMin != null && entry.plan.fields.isNotEmpty
        ? '${PlanUtils.formatMinutes(startMin)}–${PlanUtils.formatMinutes(startMin + PlanUtils.totalMinutes(entry.plan.fields))}'
        : entry.plan.time;
    final origin = _orgOriginPill(context, entry);
    final meta = [
      if (timeRange.isNotEmpty) timeRange,
      if (entry.fieldCount > 0) orgPlanPoints(entry.fieldCount),
    ].join(' · ');

    return RdCard(
      padding: const EdgeInsets.all(14),
      border: Border.all(color: borderColor),
      onTap: () => openOrgPlanEntry(
        context,
        entry,
        backLabel: l10n.rdOrgPlanBackOrgPlans,
        orgName: orgName,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (entry.isAdHoc && entry.date.isEmpty)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Icon(Icons.edit_note, color: p.softText),
            )
          else
            RdEventDateBox(
              date: entry.date,
              durationDays: entry.attendance?.durationDays,
              highlight: today,
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                ),
                if (origin != null) ...[
                  const SizedBox(height: 5),
                  origin,
                ],
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(meta, style: RdType.meta(p, size: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, size: 20, color: p.text2),
        ],
      ),
    );
  }
}
