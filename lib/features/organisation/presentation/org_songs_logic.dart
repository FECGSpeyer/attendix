import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/org_song_providers.dart';
import '../../../core/providers/tenant_providers.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../data/models/song/org_song.dart';
import '../../../l10n/l10n.dart';
import 'widgets/org_song_copy_sheet.dart';

class OrgSongTenantChip {
  OrgSongTenantChip(this.id, this.name);
  final int id;
  final String name;
  bool selected = true;
}

/// Normalized work name for comparing against the current group's library.
String normOrgSongName(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Search, paging, and copying of organisation works for `RdOrgSongsPage`.
mixin OrgSongsLogic<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  String? get initialOrgSongQuery;

  static const _pageSize = 50;

  late final searchController =
      TextEditingController(text: initialOrgSongQuery ?? '');
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

  Future<void> initOrgSongs() async {
    orgSongsInitialized = true;
    final run = ++_initRun;
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = ref.read(orgSongRepositoryWithTenantProvider);
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return;
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
        if (t.songSourceTenantId == null && t.id != ownLibraryId)
          OrgSongTenantChip(t.id, t.shortName),
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
      names = {
        for (final r in rows) normOrgSongName((r['name'] as String?) ?? ''),
      };
    } catch (_) {}
    if (!mounted ||
        run != _initRun ||
        container.read(currentTenantIdProvider) != tenantId) {
      return;
    }
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
      ToastHelper.showError(
        context,
        context.l10n.orgSongsSearchFailed(friendlyErrorMessage(e)),
      );
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
      if (mounted && run == _searchRun) {
        setState(() => results = [...results, ...rows]);
      }
    } catch (_) {
      // Ignore paging failures
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
