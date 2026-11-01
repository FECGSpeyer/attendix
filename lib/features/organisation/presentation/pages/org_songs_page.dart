import 'dart:async';

import 'package:flutter/material.dart';
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

class _TenantChip {
  _TenantChip(this.id, this.name);
  final int id;
  final String name;
  bool selected = true;
}

class _OrgSongsPageState extends ConsumerState<OrgSongsPage> {
  static const _pageSize = 50;

  late final _searchController = TextEditingController(text: widget.initialQuery ?? '');
  final _scrollController = ScrollController();
  Timer? _debounce;

  bool _initialized = false;
  List<OrgSongTenant> _orgTenants = const [];
  List<_TenantChip> _chips = const [];
  List<OrgSongCopyTarget> _targets = const [];
  int? _ownLibraryId;
  Set<String> _ownNames = const {};

  List<OrgSongResult> _results = const [];
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasSearched = false;
  bool _onlyWithFiles = false;
  int _searchRun = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  static String _normName(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Ionic `ngOnInit`: instances, copy targets, own names, first search.
  Future<void> _init() async {
    _initialized = true;
    final repo = ref.read(orgSongRepositoryWithTenantProvider);
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return;
    try {
      _orgTenants = await repo.getOrgTenants();
    } catch (_) {
      _orgTenants = const [];
    }
    final own = _orgTenants.where((t) => t.id == tenantId).firstOrNull;
    _ownLibraryId = own?.libraryId ?? tenantId;
    _chips = [
      for (final t in _orgTenants)
        if (t.songSourceTenantId == null && t.id != _ownLibraryId) _TenantChip(t.id, t.shortName),
    ];
    try {
      final tenants = await ref.read(userTenantsProvider.future);
      _targets = buildOrgSongCopyTargets(
        currentTenantId: tenantId,
        orgTenants: _orgTenants,
        rolesByTenant: {
          for (final t in tenants)
            if (t.id != null && t.role != null) t.id!: t.role!,
        },
      );
    } catch (_) {
      _targets = const [];
    }
    try {
      final rows = await repo.getLibrarySongRows(_ownLibraryId!);
      _ownNames = {for (final r in rows) _normName((r['name'] as String?) ?? '')};
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
    await _search();
  }

  Future<List<OrgSongResult>> _fetchPage(int offset) {
    final selected = _chips.where((c) => c.selected).map((c) => c.id).toList();
    final allSelected = selected.length == _chips.length;
    return ref
        .read(orgSongRepositoryWithTenantProvider)
        .searchOrgSongs(
          _searchController.text.trim(),
          tenantIds: allSelected ? null : selected,
          onlyWithFiles: _onlyWithFiles,
          limit: _pageSize,
          offset: offset,
        );
  }

  Future<void> _search() async {
    final run = ++_searchRun;
    setState(() => _loading = true);
    try {
      final rows = await _fetchPage(0);
      if (!mounted || run != _searchRun) return;
      setState(() {
        _results = rows;
        _total = rows.firstOrNull?.totalCount ?? 0;
      });
    } catch (e) {
      if (!mounted || run != _searchRun) return;
      setState(() {
        _results = const [];
        _total = 0;
      });
      ToastHelper.showError(context, context.l10n.orgSongsSearchFailed(friendlyErrorMessage(e)));
    } finally {
      if (mounted && run == _searchRun) {
        setState(() {
          _loading = false;
          _hasSearched = true;
        });
      }
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  bool get _canLoadMore => _results.length < _total;

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels > pos.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_canLoadMore) return;
    final run = _searchRun;
    setState(() => _loadingMore = true);
    try {
      final rows = await _fetchPage(_results.length);
      if (mounted && run == _searchRun) setState(() => _results = [..._results, ...rows]);
    } catch (_) {
      // Ionic: a failed page is ignored
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _toggleChip(_TenantChip chip) {
    setState(() {
      chip.selected = !chip.selected;
      if (!_chips.any((c) => c.selected)) {
        for (final c in _chips) {
          c.selected = true;
        }
      }
    });
    _search();
  }

  void _toggleOnlyWithFiles() {
    setState(() => _onlyWithFiles = !_onlyWithFiles);
    _search();
  }

  Future<void> _openCopy(OrgSongResult song) async {
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
          setState(() => _ownNames = {..._ownNames, _normName(song.name)});
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(effectiveRoleProvider);
    final isAdmin = role.isAdmin || role.isResponsible;
    final orgAsync = ref.watch(currentOrganisationProvider);
    final hasOrg = orgAsync.valueOrNull != null;
    final allowed = isAdmin && hasOrg;
    if (allowed && !_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_initialized) _init();
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.orgSongsTitle)),
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
      controller: _scrollController,
      padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: 24)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: IonSearchbar(
            controller: _searchController,
            hintText: context.l10n.orgSongsSearchPh,
            onChanged: _onSearchChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              FilterChip(
                avatar: const Icon(Icons.attach_file, size: 16),
                label: Text(context.l10n.orgSongsOnlyWithFiles),
                selected: _onlyWithFiles,
                onSelected: (_) => _toggleOnlyWithFiles(),
              ),
              for (final chip in _chips)
                FilterChip(label: Text(chip.name), selected: chip.selected, onSelected: (_) => _toggleChip(chip)),
            ],
          ),
        ),
        if (_hasSearched && !_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              context.l10n.orgSongsResultCount(_total),
              style: const TextStyle(fontSize: 13, color: AppColors.medium),
            ),
          ),
        if (_results.isNotEmpty)
          IonInsetList(
            children: [
              for (final song in _results)
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
                      if (_ownNames.contains(_normName(song.name)))
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            context.l10n.orgSongsAlreadyOwn,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      const Icon(Icons.copy_outlined, color: AppColors.medium, size: 20),
                    ],
                  ),
                  onTap: () => _openCopy(song),
                ),
            ],
          )
        else if (_hasSearched && !_loading)
          IonInsetList(
            children: [
              IonItem(title: Text(context.l10n.orgSongsNoResults, style: const TextStyle(color: AppColors.medium))),
            ],
          ),
        if ((_loading && _results.isEmpty) || _loadingMore)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: AppSpinner())),
      ],
    );
  }
}
