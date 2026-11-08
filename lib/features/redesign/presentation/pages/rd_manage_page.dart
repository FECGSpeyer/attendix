import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/admin_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/parent_providers.dart';
import '../../../../core/providers/player_providers.dart';
import '../../../../core/providers/shift_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/viewer_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/presentation/pages/general_settings_page.dart' show holidayRegions;
import '../../../settings/presentation/pages/left_players_page.dart' show leftPlayersProvider;
import '../../data/rd_manage_logic.dart';
import '../widgets/rd_split_view.dart';
import '../widgets/manage/rd_manage_entries.dart';
import '../widgets/manage/rd_settings_sheets.dart' show RdListNote;
import '../widgets/rd_widgets.dart';
import '../widgets/today/rd_today_common.dart' show RdInfoCard;

/// REDESIGN: Ich › Verwaltung (canvas "Beta: Verwaltung neu gedacht"): only
/// for Dirigent and Verantwortliche. The group on top, a search that also
/// finds what moved into the tabs, then five sections on one page. On wide
/// screens the sections stay on the left and the chosen one opens on the
/// right ([RdManageSplit]).
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
    final searchable = rdManageSearchable(access);
    final areas = rdManageAreas(access);
    final split = RdSplitScope.of(context);
    final recent = ref.watch(rdManageRecentProvider).where(searchable.contains).toList();
    final searching = _query.trim().isNotEmpty;
    final results = [
      for (final e in searchable)
        if (rdManageMatches(
          _query,
          rdManageTitle(l10n, e),
          rdManagePlace(l10n, e, access),
          rdManageHint(l10n, e, access),
          [rdManageFormerName(l10n, e) ?? '', ...rdManageKeywords(l10n, e)].join(' '),
        ))
          e,
    ];
    final unused = rdManageUnused(access);

    return RdPage(
      children: [
        RdBackLink(
          label: l10n.redesignTabMe,
          // In the split, a section route sits on top of /verwaltung:
          // popping would land on the Verwaltung again instead of "Ich".
          onTap: () => split == null && context.canPop() ? context.pop() : context.go(RedesignRoutes.me),
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(l10n.redesignMeAdmin, style: RdType.largeTitle(p)),
        ),
        const SizedBox(height: 14),
        const _GroupHero(),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          focusNode: _focus,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.rdAdminSearch,
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
                for (final e in results) _EntryRow(entry: e, subtitle: _searchSubtitle(l10n, access, e)),
              ],
            ),
        ] else ...[
          if (_focus.hasFocus && recent.isNotEmpty) ...[
            RdGroupLabel(l10n.redesignManageRecent),
            RdGroupedList(
              children: [
                for (final e in recent) _EntryRow(entry: e, subtitle: rdManagePlace(l10n, e, access)),
              ],
            ),
            const SizedBox(height: 20),
          ],
          if (split != null)
            // Desktop: the sections on the left, the chosen one on the right.
            RdGroupedList(
              children: [
                for (final area in areas)
                  RdListRow(
                    leading: RdRowIcon(rdManageAreaIcon(area)),
                    title: rdManageAreaName(l10n, area),
                    subtitle: _areaSummary(l10n, access, area),
                    selected: split.selectedId == area.index,
                    onTap: () => RdSplitScope.open(context, RedesignRoutes.manageArea(area.key)),
                  ),
              ],
            )
          else
            for (final (i, area) in areas.indexed) ...[
              if (i > 0) const SizedBox(height: 20),
              RdGroupLabel(rdManageAreaName(l10n, area)),
              _AreaList(area: area, access: access),
            ],
          if (unused.isNotEmpty) ...[
            const SizedBox(height: 28),
            RdGroupLabel(l10n.rdAdminUnused),
            RdGroupedList(
              children: [
                for (final e in unused) _EntryRow(entry: e, subtitle: rdManageUnusedText(l10n, e)),
              ],
            ),
            RdListNote(l10n.rdAdminUnusedNote),
          ],
        ],
      ],
    );
  }

  /// Where the result is ("Mitglieder", "Im Werke-Tab unter •••"), plus
  /// the old name or the switch when only that matched ("früher
  /// „Gruppen“", "Auswertung · Saisonbeginn").
  String _searchSubtitle(AppLocalizations l10n, RdManageAccess access, RdManageEntry e) {
    final place = rdManagePlace(l10n, e, access);
    final title = rdManageTitle(l10n, e);
    if (rdManageMatches(_query, title, place, rdManageHint(l10n, e, access))) return place;
    final former = rdManageFormerName(l10n, e);
    if (former != null && rdManageMatches(_query, title, place, former)) {
      return '$place · ${l10n.rdAdminFormerly(former)}';
    }
    final keyword = rdManageKeywords(l10n, e).where((k) => rdManageMatches(_query, title, place, k)).firstOrNull;
    return keyword == null ? place : '$place · $keyword';
  }

  /// "Register, Eigene Felder, Archiv …" (the section's rows).
  String _areaSummary(AppLocalizations l10n, RdManageAccess access, RdManageArea area) {
    final titles = [for (final e in rdManageEntries(access, area: area)) rdManageTitle(l10n, e)];
    if (titles.length <= 4) return titles.join(', ');
    return '${titles.take(4).join(', ')} …';
  }
}

/// The group on top of the Verwaltung: logo letters, name, type, members
/// and short name.
class _GroupHero extends ConsumerWidget {
  const _GroupHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final tenant = ref.watch(currentTenantProvider);
    if (tenant == null) return const SizedBox.shrink();
    final name = tenant.longName.isNotEmpty ? tenant.longName : tenant.shortName;
    final members = ref.watch(playersProvider).valueOrNull?.length;
    final meta = [
      switch (tenant.type) {
        'choir' => l10n.registerTypeChoir,
        'general' => l10n.registerTypeGeneral,
        _ => l10n.registerTypeOrchestra,
      },
      if (members != null) l10n.rdAdminHeroMembers(members),
      if (tenant.shortName.isNotEmpty && tenant.shortName != name) tenant.shortName,
    ].join(' · ');
    return RdCard(
      child: Row(
        children: [
          RdInitials(rdInitialsOf(tenant.shortName.isNotEmpty ? tenant.shortName : name), size: 48, square: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: RdType.section(p), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(meta, style: RdType.meta(p, size: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The rows of one section with their hint and counts.
class _AreaList extends StatelessWidget {
  const _AreaList({required this.area, required this.access});

  final RdManageArea area;
  final RdManageAccess access;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RdGroupedList(
      children: [
        for (final e in rdManageEntries(access, area: area))
          _EntryRow(entry: e, subtitle: rdManageHint(l10n, e, access), counts: true),
      ],
    );
  }
}

/// REDESIGN: the Verwaltung on wide screens, like the system settings of a
/// Mac: the sections stay on the left, the chosen one (first: the first
/// section) is open on the right (canvas "Beta: Desktop-UX").
class RdManageSplit extends ConsumerWidget {
  const RdManageSplit({super.key, this.area});

  /// null: nothing chosen yet (the first section).
  final RdManageArea? area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = rdManageAreas(ref.watch(rdManageAccessProvider));
    final shown = area != null && areas.contains(area) ? area : areas.firstOrNull;
    return RdSplitView(
      list: const RdManagePage(),
      detail: shown == null ? null : RdManageAreaPage(key: ValueKey('rd-manage-${shown.key}'), area: shown),
      selectedId: shown?.index,
      emptyText: context.l10n.redesignManageNoMatch,
    );
  }
}

/// One section of the Verwaltung with its rows (desktop detail; on phones
/// only reached by an old link).
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
    final empty = area == null || rdManageEntries(access, area: area).isEmpty;

    return RdPage(
      children: [
        if (RdSplitScope.of(context)?.isDetail ?? false)
          const SizedBox(height: 20)
        else
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
        if (empty)
          RdInfoCard(icon: Icons.info_outline, text: l10n.redesignManageNoMatch)
        else
          _AreaList(area: area, access: access),
      ],
    );
  }
}

/// A row that opens [entry]; with [counts] it shows how many the entry
/// holds (Register, Admins, Archiv …) or how it is set (Anmeldung An,
/// Feiertage Bundesland). Moved entries show ↗: they open in another tab or
/// page.
class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.entry, this.subtitle, this.counts = false});

  final RdManageEntry entry;
  final String? subtitle;
  final bool counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.rd;
    final l10n = context.l10n;
    final warn = entry == RdManageEntry.missingAccounts;
    final count = !counts
        ? null
        : switch (entry) {
            RdManageEntry.groups => ref.watch(groupsProvider).valueOrNull?.length,
            RdManageEntry.missingAccounts => ref.watch(rdMissingAccountsProvider).length,
            RdManageEntry.archive => ref.watch(leftPlayersProvider).valueOrNull?.length,
            RdManageEntry.admins => ref.watch(adminsProvider).valueOrNull?.length,
            RdManageEntry.parents => ref.watch(parentsProvider).valueOrNull?.length,
            RdManageEntry.viewers => ref.watch(viewersProvider).valueOrNull?.length,
            RdManageEntry.attendanceTypes => ref.watch(attendanceTypesProvider).valueOrNull?.length,
            RdManageEntry.shiftPlans => ref.watch(shiftsProvider).valueOrNull?.length,
            _ => null,
          };
    final shown = count != null && count > 0;
    return RdListRow(
      leading: RdRowIcon(rdManageIcon(entry)),
      title: rdManageTitle(l10n, entry),
      subtitle: subtitle == null || subtitle!.isEmpty ? null : subtitle,
      value: shown && !warn ? '$count' : (counts ? _setting(ref, l10n) : null),
      trailing: shown && warn
          ? RdPill('$count', tone: RdTone.late)
          : entry.moved
              ? Icon(Icons.north_east, size: 18, color: p.text2)
              : null,
      showChevron: !entry.moved,
      onTap: () => rdOpenManageEntry(context, ref, entry),
    );
  }

  /// How a setting of the old "Allgemein" is set.
  String? _setting(WidgetRef ref, AppLocalizations l10n) {
    final t = ref.watch(currentTenantProvider);
    if (t == null) return null;
    return switch (entry) {
      RdManageEntry.registration => (t.registerId ?? '').isNotEmpty ? l10n.rdAdminOn : l10n.rdAdminOff,
      RdManageEntry.critical =>
        (t.criticalRules ?? const []).isEmpty ? null : l10n.rdAdminCriticalCount(t.criticalRules!.length),
      RdManageEntry.holidays => !t.showHolidays
          ? l10n.rdAdminOff
          : holidayRegions.where((r) => r.$1.isNotEmpty && r.$1 == t.region).map((r) => r.$1).firstOrNull ??
              l10n.rdAdminOn,
      _ => null,
    };
  }
}
