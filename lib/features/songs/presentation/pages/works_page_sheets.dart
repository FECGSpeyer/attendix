part of 'works_page.dart';

/// Action sheets (`•••`, `+`), PDF catalog export, and list row widget for [RdWorksPage].
extension _RdWorksPageSheets on _RdWorksPageState {
  /// "•••": rarely needed list actions (filter, import and the group
  /// folders have their own places now).
  Future<void> _more(SongsListData data, List<Song> shown, bool isAdmin) async {
    final l10n = context.l10n;
    final role = ref.read(effectiveRoleProvider);
    // Werke of another group: managed by the leads there.
    final canManage = isAdmin && ref.read(rdLibraryEditableProvider);
    final sharingId = data.songSharingId;
    // Sammlungen once the database has them (null before the migration).
    final collections = ref.read(songCollectionsProvider).valueOrNull != null;
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        // The Noten of one part, for the coming Termine or all Werke, also
        // as one PDF (was a button in the header).
        AppActionSheetAction(
          value: 'folders',
          icon: Icons.queue_music_outlined,
          label: l10n.redesignWorksFoldersMenu,
        ),
        if (canManage && collections)
          AppActionSheetAction(
            value: 'collections',
            icon: Icons.folder_copy_outlined,
            label: l10n.collectionsManage,
          ),
        if (canManage)
          AppActionSheetAction(value: 'categories', icon: Icons.sell_outlined, label: l10n.rdWmManageCategories),
        if (isAdmin && (ref.read(linkedTenantsProvider).valueOrNull?.isNotEmpty ?? false))
          AppActionSheetAction(value: 'org_songs', icon: Icons.hub_outlined, label: l10n.rdOrgWorks),
        // From the old Verwaltung (canvas "Werke-Tab: •••"): Werkhistorie
        // for leads and helpers, the Dateiablage for everyone with access.
        if (isAdmin || role.isHelperRole)
          AppActionSheetAction(value: 'history', icon: Icons.history, label: l10n.rdAdminWorkHistory),
        if (ref.read(canAccessFilesProvider))
          AppActionSheetAction(value: 'files', icon: Icons.folder_outlined, label: l10n.settingsFileStorage),
        // The public link straight into the system share sheet; leads
        // switch it on first if it is off (off again in Verwaltung).
        if (isAdmin || (sharingId != null && sharingId.isNotEmpty))
          AppActionSheetAction(value: 'share', icon: Icons.ios_share, label: l10n.generalSettingsShareSongs),
        // A list of the Werke, not their Noten.
        AppActionSheetAction(value: 'pdf', icon: Icons.description_outlined, label: l10n.rdWmListPdf),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'folders':
        await context.push(RedesignRoutes.folder);
      case 'collections':
        await context.push(RedesignRoutes.collections);
      case 'categories':
        await showSongCategoriesSheet(context);
      case 'org_songs':
        await context.push('/settings/org-settings/songs?from=werke');
      case 'history':
        await context.push(RedesignRoutes.workHistory);
      case 'files':
        await context.push('/settings/files');
      case 'share':
        final id =
            (sharingId ?? '').isNotEmpty ? sharingId : (isAdmin ? await rdEnableWorksSharing(context, ref) : null);
        if (id == null || !mounted) return;
        await rdShareLink(
          context,
          SongUtils.shareLink(id),
          subject: l10n.redesignTabWorks,
          copiedMessage: l10n.songsLinkCopied,
        );
      case 'pdf':
        await _exportPdf(data, shown);
    }
  }

  /// "+": a new Werk, a work list from Excel, or Werke of another group of
  /// the organisation.
  Future<void> _add(SongsListData data, {BuildContext? anchor}) async {
    final l10n = context.l10n;
    // "Aus der Organisation" needs the organisation: wait for it to load.
    var org = false;
    try {
      org = await ref.read(currentOrganisationProvider.future).timeout(const Duration(seconds: 5)) != null;
    } catch (_) {}
    final ownLibrary = await ref.read(rdImportOwnLibraryProvider.future).catchError((_) => false);
    if (!mounted || (anchor != null && !anchor.mounted)) return;
    final action = await showAppActionSheet<String>(
      context,
      title: l10n.redesignWorksAdd,
      anchor: anchor,
      actions: [
        AppActionSheetAction(
          value: 'new',
          icon: Icons.add,
          label: l10n.redesignWorksAddNew,
          subtitle: l10n.redesignWorksAddNewHint,
        ),
        AppActionSheetAction(
          value: 'import',
          icon: Icons.table_chart_outlined,
          label: l10n.redesignWorksAddImport,
          subtitle: l10n.redesignWorksAddImportHint,
        ),
        if (ownLibrary)
          AppActionSheetAction(
            value: 'files',
            icon: Icons.folder_zip_outlined,
            label: l10n.redesignImportTitle,
            subtitle: l10n.redesignImportMenuHint,
          ),
        if (org)
          AppActionSheetAction(
            value: 'org',
            icon: Icons.travel_explore,
            label: l10n.redesignWorksAddOrg,
            subtitle: l10n.redesignWorksAddOrgHint,
          ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'new':
        // In the Sammlung the list shows.
        final collection = rdShownCollectionId(
          ref.read(rdWorksCollectionProvider),
          ref.read(rdVisibleCollectionsProvider),
        );
        await context.push(
          collection == null ? RedesignRoutes.newWork : '${RedesignRoutes.newWork}?sammlung=$collection',
        );
      case 'import':
        // A page of this tab ("‹ Werke"), the sidebar stays on the desktop.
        final imported = await context.push<bool>(RedesignRoutes.workListImport);
        if (imported == true && mounted) {
          ref.invalidate(songsProvider);
          ref.invalidate(songsListDataProvider);
        }
      case 'files':
        // "Noten importieren": its controller refreshes the Werke.
        await context.push(RedesignRoutes.worksImport);
      case 'org':
        await context.push('/settings/org-settings/songs?from=werke');
    }
  }

  Future<void> _exportPdf(SongsListData data, List<Song> shown) async {
    final tenant = ref.read(currentTenantProvider);
    final view = ref.read(songViewOptionsProvider(data.tenantId));
    try {
      final branding = await resolvePdfBranding(ref);
      await ref
          .read(songPrintServiceProvider)
          .exportSongsCatalogPdf(
            branding: branding,
            songs: shown,
            tenantShortName: tenant?.shortName ?? '',
            viewOpts: view.opts,
            showLastSung: true,
            isOrchestra: data.isOrchestra,
            additionalFields: data.additionalFields,
          );
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.songsFlutterPdfCreateFailed(friendlyErrorMessage(e)));
    }
  }
}

/// Number, title, one status line and a pill (leads: missing Noten).
class _WorkRow extends StatelessWidget {
  const _WorkRow({
    super.key,
    required this.song,
    required this.subtitle,
    required this.onTap,
    this.pill,
    this.selected = false,
  });

  final Song song;
  final String subtitle;
  final Widget? pill;
  final VoidCallback? onTap;

  /// Open on the right of the split view.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final number = song.fullNumber;
    final second = subtitle.isNotEmpty ? subtitle : (song.composer ?? '');
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected ? p.soft : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      number,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: p.text2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text),
                        ),
                        if (second.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              second,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: RdType.meta(p, size: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (pill != null) ...[const SizedBox(width: 6), pill!],
                  if (onTap != null) ...[const SizedBox(width: 4), Icon(Icons.chevron_right, size: 20, color: p.text2)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
