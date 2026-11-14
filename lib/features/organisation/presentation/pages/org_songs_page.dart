import 'dart:async';

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/debug_providers.dart';
import '../../../../core/providers/org_song_providers.dart';
import '../../../../core/providers/organisation_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/song_copy.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/org_song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/theme/redesign/rd_theme.dart' show RdSkinContext;
import '../../../planning/presentation/widgets/ion_items.dart' show IonChip, IonBadge;
import '../../../../shared/widgets/layout/ionic_ios.dart';
import '../../../../shared/widgets/layout/ios_tab_bar.dart';
import '../widgets/org_song_copy_sheet.dart';

/// Werke in der Organisation suchen (Ionic 4.17.13 `OrgSongsPage`, route
/// `/settings/org-settings/songs`, optional `?q=`): search the Werke of all
/// other instances of the organisation and copy one into a target instance.
class OrgSongsPage extends ConsumerStatefulWidget {
  const OrgSongsPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<OrgSongsPage> createState() => _OrgSongsPageState();
}

class OrgSongTenantChip {
  OrgSongTenantChip(this.id, this.name);
  final int id;
  final String name;
  bool selected = true;
}

/// Name as compared with the own Werke ("Schon bei dir").
String normOrgSongName(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Search, paging and copy of the org Werke, shared by the old page and the
/// Beta page (`RdOrgSongsPage`).
mixin OrgSongsLogic<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// `?q=` of the route.
  String? get initialOrgSongQuery;

  static const _pageSize = 50;

  late final searchController = TextEditingController(text: initialOrgSongQuery ?? '');
  final scrollController = ScrollController();
  Timer? _debounce;

  bool orgSongsInitialized = false;
  List<OrgSongTenant> _orgTenants = const [];
  List<OrgSongTenantChip> chips = const [];
  List<OrgSongCopyTarget> _targets = const [];
  int? _ownLibraryId;
  Set<String> ownNames = const {};

  List<OrgSongResult> results = const [];
  int total = 0;
  bool searching = false;
  bool loadingMore = false;
  bool hasSearched = false;
  bool onlyWithFiles = false;
  int _searchRun = 0;
  int _initRun = 0;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }


  /// Starts over after a group switch: everything loaded belongs to the
  /// previous group, the next build loads again.
  void resetOrgSongs() {
    _searchRun++;
    _initRun++;
    setState(() {
      orgSongsInitialized = false;
      _orgTenants = const [];
      chips = const [];
      _targets = const [];
      _ownLibraryId = null;
      ownNames = const {};
      results = const [];
      total = 0;
      searching = false;
      hasSearched = false;
    });
  }

  /// Ionic `ngOnInit`: instances, copy targets, own names, first search.
  Future<void> initOrgSongs() async {
    orgSongsInitialized = true;
    final run = ++_initRun;
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = ref.read(orgSongRepositoryWithTenantProvider);
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return;
    // Everything is collected locally and taken over together, only while
    // this load is still the latest one for the current group.
    List<OrgSongTenant> orgTenants;
    try {
      orgTenants = await repo.getOrgTenants();
    } catch (_) {
      orgTenants = const [];
    }
    final own = orgTenants.where((t) => t.id == tenantId).firstOrNull;
    final ownLibraryId = own?.libraryId ?? tenantId;
    final newChips = [
      for (final t in orgTenants)
        if (t.songSourceTenantId == null && t.id != ownLibraryId) OrgSongTenantChip(t.id, t.shortName),
    ];
    List<OrgSongCopyTarget> targets;
    try {
      final tenants = await container.read(userTenantsProvider.future);
      targets = buildOrgSongCopyTargets(
        currentTenantId: tenantId,
        orgTenants: orgTenants,
        rolesByTenant: {
          for (final t in tenants)
            if (t.id != null && t.role != null) t.id!: t.role!,
        },
      );
    } catch (_) {
      targets = const [];
    }
    var names = const <String>{};
    try {
      final rows = await repo.getLibrarySongRows(ownLibraryId);
      names = {for (final r in rows) normOrgSongName((r['name'] as String?) ?? '')};
    } catch (_) {}
    // Group switched or reset meanwhile: [resetOrgSongs] loads for the new one.
    if (!mounted || run != _initRun || container.read(currentTenantIdProvider) != tenantId) return;
    setState(() {
      _orgTenants = orgTenants;
      _ownLibraryId = ownLibraryId;
      chips = newChips;
      _targets = targets;
      ownNames = names;
    });
    await _search();
  }

  Future<List<OrgSongResult>> _fetchPage(int offset) {
    final selected = chips.where((c) => c.selected).map((c) => c.id).toList();
    final allSelected = selected.length == chips.length;
    return ref
        .read(orgSongRepositoryWithTenantProvider)
        .searchOrgSongs(
          searchController.text.trim(),
          tenantIds: allSelected ? null : selected,
          onlyWithFiles: onlyWithFiles,
          limit: _pageSize,
          offset: offset,
        );
  }

  Future<void> _search() async {
    final run = ++_searchRun;
    setState(() => searching = true);
    try {
      final rows = await _fetchPage(0);
      if (!mounted || run != _searchRun) return;
      setState(() {
        results = rows;
        total = rows.firstOrNull?.totalCount ?? 0;
      });
    } catch (e) {
      if (!mounted || run != _searchRun) return;
      setState(() {
        results = const [];
        total = 0;
      });
      ToastHelper.showError(context, context.l10n.orgSongsSearchFailed(friendlyErrorMessage(e)));
    } finally {
      if (mounted && run == _searchRun) {
        setState(() {
          searching = false;
          hasSearched = true;
        });
      }
    }
  }

  void onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  bool get canLoadMoreOrgSongs => results.length < total;

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final pos = scrollController.position;
    if (pos.pixels > pos.maxScrollExtent - 300) loadMoreOrgSongs();
  }

  Future<void> loadMoreOrgSongs() async {
    if (loadingMore || searching || !canLoadMoreOrgSongs) return;
    final run = _searchRun;
    setState(() => loadingMore = true);
    try {
      final rows = await _fetchPage(results.length);
      if (mounted && run == _searchRun) setState(() => results = [...results, ...rows]);
    } catch (_) {
      // Ionic: a failed page is ignored
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  void toggleChip(OrgSongTenantChip chip) {
    setState(() {
      chip.selected = !chip.selected;
      if (!chips.any((c) => c.selected)) {
        for (final c in chips) {
          c.selected = true;
        }
      }
    });
    _search();
  }

  void toggleOnlyWithFiles() {
    setState(() => onlyWithFiles = !onlyWithFiles);
    _search();
  }

  Future<void> openCopy(OrgSongResult song) async {
    final targets = _targets.where((t) => t.libraryId != song.tenantId).toList();
    if (targets.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.orgSongsNoTargets);
      return;
    }
    await showOrgSongCopySheet(
      context,
      source: song,
      targets: targets,
      orgTenants: _orgTenants,
      onCopied: (libraryId) {
        if (libraryId == _ownLibraryId && mounted) {
          setState(() => ownNames = {...ownNames, normOrgSongName(song.name)});
        }
      },
    );
  }
}

class _OrgSongsPageState extends ConsumerState<OrgSongsPage> with OrgSongsLogic {
  @override
  String? get initialOrgSongQuery => widget.initialQuery;

  @override
  Widget build(BuildContext context) {
    // A group switch starts over (a load for the old group is dropped).
    ref.listen(currentTenantIdProvider, (prev, next) {
      if (prev != next) resetOrgSongs();
    });
    final role = ref.watch(effectiveRoleProvider);
    final isAdmin = role.isAdmin || role.isResponsible;
    final orgAsync = ref.watch(currentOrganisationProvider);
    final hasOrg = orgAsync.valueOrNull != null;
    final allowed = isAdmin && hasOrg;
    if (allowed && !orgSongsInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !orgSongsInitialized) initOrgSongs();
      });
    }

    // ABL-23: Ionic second header toolbar with the searchbar (stays fixed
    // while the results scroll). Beta keeps it in the list.
    final searchInHeader = allowed && context.rdSkin == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.orgSongsTitle),
        bottom: searchInHeader
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: IonSearchbar(
                    controller: searchController,
                    hintText: context.l10n.orgSongsSearchPh,
                    onChanged: onSearchChanged,
                  ),
                ),
              )
            : null,
      ),
      body:
          orgAsync.isLoading && !orgAsync.hasValue
              ? const Center(child: AppSpinner())
              : !allowed
              ? ListView(
                children: [
                  const SizedBox(height: 16),
                  IonInsetList(children: [IonItem(title: Text(context.l10n.orgSongsNoPermission))]),
                ],
              )
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: 24)),
      children: [
        if (context.rdSkin != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: IonSearchbar(
              controller: searchController,
              hintText: context.l10n.orgSongsSearchPh,
              onChanged: onSearchChanged,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (context.rdSkin != null) ...[
                FilterChip(
                  avatar: Icon(AppIcons.attachFile, size: 16),
                  label: Text(context.l10n.orgSongsOnlyWithFiles),
                  selected: onlyWithFiles,
                  onSelected: (_) => toggleOnlyWithFiles(),
                ),
                for (final chip in chips)
                  FilterChip(label: Text(chip.name), selected: chip.selected, onSelected: (_) => toggleChip(chip)),
              ] else ...[
                // ion-chip: outline medium, selected primary – no checkmark.
                IonChip(
                  icon: AppIcons.documentAttachOutline,
                  label: context.l10n.orgSongsOnlyWithFiles,
                  outline: !onlyWithFiles,
                  color: onlyWithFiles ? AppColors.primary : AppColors.medium,
                  onTap: toggleOnlyWithFiles,
                ),
                for (final chip in chips)
                  IonChip(
                    label: chip.name,
                    outline: !chip.selected,
                    color: chip.selected ? AppColors.primary : AppColors.medium,
                    onTap: () => toggleChip(chip),
                  ),
              ],
            ],
          ),
        ),
        if (hasSearched && !searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              context.l10n.orgSongsResultCount(total),
              style: const TextStyle(fontSize: 13, color: AppColors.medium),
            ),
          ),
        if (results.isNotEmpty)
          IonInsetList(
            children: [
              for (final song in results)
                IonItem(
                  key: ValueKey('${song.tenantId}-${song.id}'),
                  title: Text(orgSongLabel(song.prefix, song.number, song.name)),
                  subtitle: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: song.tenantName, style: const TextStyle(color: AppColors.primary)),
                        if (song.files.isNotEmpty)
                          TextSpan(text: ' · ${context.l10n.orgSongsFileCount(song.files.length)}'),
                        if (song.categoryNames.isNotEmpty) TextSpan(text: ' · ${song.categoryNames.join(', ')}'),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ownNames.contains(normOrgSongName(song.name)) && context.rdSkin == null)
                        // ABL-23: Ionic `ion-badge color="success"` slot end.
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: IonBadge(label: context.l10n.orgSongsAlreadyOwn, color: AppColors.success),
                        )
                      else if (ownNames.contains(normOrgSongName(song.name)))
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            context.l10n.orgSongsAlreadyOwn,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      Icon(AppIcons.copyOutlined, color: AppColors.medium, size: 20),
                    ],
                  ),
                  onTap: () => openCopy(song),
                ),
            ],
          )
        else if (hasSearched && !searching)
          IonInsetList(
            children: [
              IonItem(title: Text(context.l10n.orgSongsNoResults, style: const TextStyle(color: AppColors.medium))),
            ],
          ),
        if ((searching && results.isEmpty) || loadingMore)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: AppSpinner())),
      ],
    );
  }
}
