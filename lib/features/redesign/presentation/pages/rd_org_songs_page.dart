import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/song_copy.dart';
import '../../../../l10n/l10n.dart';
import '../../../organisation/presentation/pages/org_songs_page.dart';
import '../widgets/manage/rd_settings_sheets.dart';
import '../widgets/rd_widgets.dart';

/// REDESIGN: Werke der Organisation (canvas "Beta: Gruppe und Daten", board
/// "G2 Werke der Organisation"). Search like the Werke tab; "Schon bei dir"
/// as a mark, otherwise "Übernehmen". Same search, paging and copy sheet as
/// the old page ([OrgSongsLogic]).
class RdOrgSongsPage extends ConsumerStatefulWidget {
  const RdOrgSongsPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<RdOrgSongsPage> createState() => _RdOrgSongsPageState();
}

class _RdOrgSongsPageState extends ConsumerState<RdOrgSongsPage> with OrgSongsLogic {
  @override
  String? get initialOrgSongQuery => widget.initialQuery;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings/org-settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final role = ref.watch(effectiveRoleProvider);
    ref.listen(currentTenantIdProvider, (prev, next) {
      if (prev != next) resetOrgSongs();
    });
    final orgAsync = ref.watch(currentOrganisationProvider);
    final org = orgAsync.isReloading ? null : orgAsync.valueOrNull;
    final allowed = (role.isAdmin || role.isResponsible) && org != null;
    if (allowed && !orgSongsInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !orgSongsInitialized) initOrgSongs();
      });
    }
    final header = <Widget>[
      RdBackLink(label: l10n.commonBack, onTap: _back),
      const SizedBox(height: 4),
      Semantics(header: true, child: Text(l10n.rdOrgWorks, style: RdType.largeTitle(p))),
      const SizedBox(height: 12),
    ];
    if (orgAsync.isLoading && org == null) {
      return RdPage(children: [
        ...header,
        Center(child: Padding(padding: const EdgeInsets.all(32), child: CircularProgressIndicator(color: p.primary))),
      ]);
    }
    if (!allowed) return RdPage(children: [...header, RdListNote(l10n.rdOrgWorksNoPermission)]);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) loadMoreOrgSongs();
        return false;
      },
      child: RdPage(
        children: [
          ...header,
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.orgSongsSearchPh,
              prefixIcon: Icon(Icons.search, color: p.text2),
              filled: true,
              fillColor: p.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(p.buttonRadius), borderSide: BorderSide.none),
              enabledBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(p.buttonRadius), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RdChoiceChip(label: l10n.orgSongsOnlyWithFiles, selected: onlyWithFiles, onTap: toggleOnlyWithFiles),
              for (final chip in chips)
                RdChoiceChip(label: chip.name, selected: chip.selected, onTap: () => toggleChip(chip)),
            ],
          ),
          const SizedBox(height: 18),
          if (hasSearched && !searching) RdGroupLabel(l10n.orgSongsResultCount(total)),
          if (results.isNotEmpty)
            RdGroupedList(children: [
              for (final song in results)
                RdListRow(
                  key: ValueKey('${song.tenantId}-${song.id}'),
                  title: orgSongLabel(song.prefix, song.number, song.name),
                  subtitle: [
                    song.tenantName,
                    if (song.files.isNotEmpty) l10n.orgSongsFileCount(song.files.length),
                    if (song.categoryNames.isNotEmpty) song.categoryNames.join(', '),
                  ].join(' · '),
                  showChevron: false,
                  trailing: ownNames.contains(normOrgSongName(song.name))
                      ? RdPill(l10n.orgSongsAlreadyOwn, tone: RdTone.present)
                      : Text(l10n.rdOrgTakeOver, style: RdType.body(p).copyWith(color: p.primary)),
                  onTap: () => openCopy(song),
                ),
            ])
          else if (hasSearched && !searching)
            RdListNote(l10n.orgSongsNoResults),
          if ((searching && results.isEmpty) || loadingMore)
            Center(child: Padding(padding: const EdgeInsets.all(16), child: CircularProgressIndicator(color: p.primary))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
