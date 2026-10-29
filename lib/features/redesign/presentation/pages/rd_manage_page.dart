import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/admin_providers.dart';
import '../../../../core/providers/parent_providers.dart';
import '../../../../core/providers/viewer_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/pages/left_players_page.dart' show leftPlayersProvider;
import '../../../settings/presentation/pages/pending_players_page.dart' show showPendingPersonsSheet;
import '../../data/rd_manage_logic.dart';
import '../widgets/manage/rd_manage_entries.dart';
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: Ich › Verwaltung (canvas "Verwaltung", "VerwSuche"): the old
/// settings in six areas, a search over all entries and the waiting
/// approvals on top. Every entry opens the existing page or sheet.
class RdManagePage extends ConsumerStatefulWidget {
  const RdManagePage({super.key});

  @override
  ConsumerState<RdManagePage> createState() => _RdManagePageState();
}

class _RdManagePageState extends ConsumerState<RdManagePage> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _search.clear();
        _query = '';
      });

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final access = ref.watch(rdManageAccessProvider);
    final entries = rdManageEntries(access);
    final areas = rdManageAreas(access);
    final pending = ref.watch(rdManagePendingProvider).length;
    final recent = ref.watch(rdManageRecentProvider).where(entries.contains).toList();
    final searching = _query.trim().isNotEmpty;
    final results = [
      for (final e in entries)
        if (rdManageMatches(
          _query,
          rdManageTitle(l10n, e),
          rdManageAreaName(l10n, e.area),
          rdManageHint(l10n, e),
        ))
          e,
    ];

    return RdPage(
      children: [
        RdBackLink(
          label: l10n.redesignTabMe,
          onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.me),
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(l10n.redesignMeAdmin, style: RdType.largeTitle(p)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          focusNode: _focus,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.redesignManageSearch,
            prefixIcon: Icon(Icons.search, color: p.text2),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close, color: p.text2),
                    tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                    onPressed: _clear,
                  ),
            filled: true,
            fillColor: p.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(p.buttonRadius),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(p.buttonRadius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (searching) ...[
          if (results.isEmpty)
            RdInfoCard(icon: Icons.search_off, text: l10n.redesignManageNoMatch)
          else
            RdGroupedList(
              children: [
                for (final e in results)
                  _EntryRow(entry: e, subtitle: rdManageAreaName(l10n, e.area)),
              ],
            ),
        ] else ...[
          if (_focus.hasFocus && recent.isNotEmpty) ...[
            RdGroupLabel(l10n.redesignManageRecent),
            RdGroupedList(
              children: [
                for (final e in recent)
                  _EntryRow(entry: e, subtitle: rdManageAreaName(l10n, e.area)),
              ],
            ),
            const SizedBox(height: 20),
          ],
          if (pending > 0) ...[
            RdCard(
              onTap: () => showPendingPersonsSheet(context),
              child: Row(
                children: [
                  RdCountBadge(pending, tone: RdTone.late),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.redesignManagePending(pending),
                      style: RdType.body(p).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: p.text2),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          RdGroupedList(
            children: [
              for (final area in areas)
                RdListRow(
                  leading: RdRowIcon(rdManageAreaIcon(area)),
                  title: rdManageAreaName(l10n, area),
                  subtitle: _areaSummary(l10n, access, area),
                  onTap: () => context.push(RedesignRoutes.manageArea(area.key)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              l10n.redesignManageFooter(entries.length),
              textAlign: TextAlign.center,
              style: RdType.meta(p, size: 13),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Center(
          child: RdTextLink(
            label: l10n.redesignManageClassic,
            onTap: () => context.push('/settings'),
          ),
        ),
      ],
    );
  }

  /// "Rollen & Berechtigungen, Eltern, Lehrer …" (the area's entries).
  String _areaSummary(AppLocalizations l10n, RdManageAccess access, RdManageArea area) {
    final titles = [
      for (final e in rdManageEntries(access, area: area))
        if (e != RdManageEntry.approvals) rdManageTitle(l10n, e),
    ];
    if (titles.length <= 4) return titles.join(', ');
    return '${titles.take(4).join(', ')} …';
  }
}

/// One area of the Verwaltung with its entries.
class RdManageAreaPage extends ConsumerWidget {
  const RdManageAreaPage({super.key, required this.area});

  /// null for an unknown path segment.
  final RdManageArea? area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final area = this.area;
    final access = ref.watch(rdManageAccessProvider);
    final entries = area == null ? const <RdManageEntry>[] : rdManageEntries(access, area: area);

    return RdPage(
      children: [
        RdBackLink(
          label: l10n.redesignMeAdmin,
          onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.manage),
        ),
        const SizedBox(height: 4),
        if (area != null)
          Semantics(
            header: true,
            child: Text(rdManageAreaName(l10n, area), style: RdType.title(p)),
          ),
        const SizedBox(height: 18),
        if (entries.isEmpty)
          RdInfoCard(icon: Icons.info_outline, text: l10n.redesignManageNoMatch)
        else
          RdGroupedList(
            children: [
              for (final e in entries)
                _EntryRow(entry: e, subtitle: rdManageHint(l10n, e), counts: true),
            ],
          ),
      ],
    );
  }
}

/// A row that opens [entry]; with [counts] it shows how many persons the
/// entry holds (Freigaben, Administratoren, Eltern …).
class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.entry, this.subtitle, this.counts = false});

  final RdManageEntry entry;
  final String? subtitle;
  final bool counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final warn = entry == RdManageEntry.approvals || entry == RdManageEntry.missingAccounts;
    final count = !counts
        ? null
        : switch (entry) {
            RdManageEntry.approvals => ref.watch(rdManagePendingProvider).length,
            RdManageEntry.missingAccounts => ref.watch(rdMissingAccountsProvider).length,
            RdManageEntry.admins => ref.watch(adminsProvider).valueOrNull?.length,
            RdManageEntry.parents => ref.watch(parentsProvider).valueOrNull?.length,
            RdManageEntry.viewers => ref.watch(viewersProvider).valueOrNull?.length,
            RdManageEntry.archive => ref.watch(leftPlayersProvider).valueOrNull?.length,
            _ => null,
          };
    return RdListRow(
      leading: RdRowIcon(rdManageIcon(entry)),
      title: rdManageTitle(l10n, entry),
      subtitle: subtitle,
      value: count != null && count > 0 && !warn ? '$count' : null,
      trailing: count != null && count > 0 && warn ? RdPill('$count', tone: RdTone.late) : null,
      onTap: () => rdOpenManageEntry(context, ref, entry),
    );
  }
}
