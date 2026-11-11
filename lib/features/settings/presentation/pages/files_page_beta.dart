part of 'files_page.dart';

/// REDESIGN: Dateiablage in the Beta design (canvas "Beta: Gruppe und
/// Daten", board "Dateiablage"). Same state, data and actions as the old
/// page, only the look differs:
/// * large title = the current folder, the back link goes one folder up
///   (in the root: back to Werke, without a Werke tab to Ich);
/// * storage as a thin bar under the title (only for editors, like before);
/// * "•••" holds everything for the whole folder (Mehrere auswählen,
///   Sortieren, Link teilen, Mehr Speicher anfragen, Suchhilfe), "+" asks
///   "Dateien hochladen" or "Ordner anlegen";
/// * entries as a grouped list; "•••" of an entry opens an action sheet
///   (Öffnen first, Löschen red and last).
extension _FilesPageBeta on _FilesPageState {
  Widget _buildBeta(
    BuildContext context, {
    required bool canAccess,
    required bool isRoleLoading,
    required bool canEdit,
  }) {
    final p = context.rd;
    final l10n = context.l10n;
    final segments = _pathSegments;
    final title = segments.isEmpty ? l10n.filesTitle : segments.last;
    final showAdd = canAccess && canEdit && !_selectionMode && !isRoleLoading;

    final Widget topBar;
    if (_selectionMode) {
      topBar = Row(
        children: [
          RdTextLink(key: const Key('rd-files-selection-done'), label: l10n.filesSelectionDone, onTap: _exitSelection),
          const Spacer(),
          RdTextLink(
            key: const Key('rd-files-select-all'),
            label: _allVisibleSelected ? l10n.filesSelectNone : l10n.filesSelectAll,
            onTap: _toggleSelectAll,
          ),
        ],
      );
    } else {
      topBar = Row(
        children: [
          Expanded(
            child: RdBackLink(
              label:
                  segments.isEmpty
                      ? l10n.redesignTabMe
                      : segments.length == 1
                      ? l10n.filesTitle
                      : segments[segments.length - 2],
              onTap: () => _betaBack(context),
            ),
          ),
          if (canAccess && !isRoleLoading)
            Builder(
              builder:
                  (button) => RdCircleButton(
                    key: const Key('rd-files-more'),
                    icon: Icons.more_horiz,
                    label: l10n.a11yMoreActions,
                    onPressed: () => _betaFolderActions(button),
                  ),
            ),
        ],
      );
    }

    final List<Widget> body;
    if (isRoleLoading) {
      body = [RdInfoCard(text: l10n.redesignTodayLoading, loading: true)];
    } else if (!canAccess) {
      body = [RdInfoCard(icon: Icons.lock_outline, text: l10n.filesNoAccess)];
    } else {
      body = [
        if (canEdit && _usedBytes != null) ...[_betaStorage(context), const SizedBox(height: 16)],
        _betaSearch(context),
        const SizedBox(height: 16),
        ..._betaList(context),
      ];
    }

    return PopScope(
      // In a sub folder "back" goes one folder up, like the back link.
      canPop: segments.isEmpty && !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _betaBack(context);
      },
      child: RdPage(
        onRefresh: canAccess ? _loadEntries : null,
        padding: EdgeInsets.fromLTRB(20, 12, 20, showAdd || _selectionMode ? 96 : 32),
        floatingActionButtonLocation: _selectionMode ? FloatingActionButtonLocation.centerFloat : null,
        floatingActionButton:
            _selectionMode
                ? _betaSelectionBar(context)
                : showAdd
                ? FloatingActionButton(
                  key: const Key('rd-files-add'),
                  tooltip: l10n.filesUpload,
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  onPressed: () => _betaAdd(context),
                  child: const Icon(Icons.add, size: 28),
                )
                : null,
        children: [
          topBar,
          const SizedBox(height: 4),
          Semantics(
            header: true,
            child: Text(
              _selectionMode ? l10n.filesSelectedCount(_selectedPaths.length) : title,
              style: RdType.largeTitle(p),
            ),
          ),
          const SizedBox(height: 20),
          ...body,
        ],
      ),
    );
  }

  /// Back link and system back: leave the selection, else one folder up,
  /// in the root back to Werke (or Ich).
  void _betaBack(BuildContext context) {
    if (_selectionMode) {
      _exitSelection();
      return;
    }
    final segments = _pathSegments;
    if (segments.isNotEmpty) {
      _navigateTo(segments.sublist(0, segments.length - 1).join('/'));
      return;
    }
    rdBack(context, RedesignRoutes.me);
  }

  Widget _betaStorage(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final max = _maxBytes;
    final used = _usedBytes ?? 0;
    final text =
        max != null
            ? l10n.filesStorageUsedOf(formatFileSize(used), formatFileSize(max))
            : l10n.filesStorageUsed(formatFileSize(used));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (max != null && max > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              key: const Key('rd-files-storage'),
              value: (used / max).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: p.track,
              color: used >= max * 0.9 ? p.absent : p.primary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text('$text$_storageStatusLabel', style: RdType.meta(p, size: 13)),
      ],
    );
  }

  Widget _betaSearch(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return TextField(
      key: const Key('rd-files-search'),
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: l10n.filesSearchPlaceholder,
        prefixIcon: Icon(Icons.search, color: p.text2),
        suffixIcon:
            _hasSearchTerm
                ? IconButton(
                  icon: Icon(Icons.close, color: p.text2),
                  tooltip: l10n.filesResetSearch,
                  onPressed: _searchController.clear,
                )
                : null,
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(p.buttonRadius), borderSide: BorderSide.none),
      ),
    );
  }

  List<Widget> _betaList(BuildContext context) {
    final l10n = context.l10n;
    if (_isLoading && _entries.isEmpty) {
      return [RdInfoCard(text: l10n.redesignTodayLoading, loading: true)];
    }
    if (_entries.isEmpty) {
      return [RdInfoCard(icon: Icons.folder_open_outlined, text: l10n.filesFolderEmpty)];
    }
    final filtered = _filteredEntries;
    if (filtered.isEmpty) {
      return [RdInfoCard(icon: Icons.search, text: l10n.filesNoHits(_searchController.text))];
    }
    return [
      RdGroupedList(
        children: [
          for (final e in filtered) _betaRow(context, e),
        ],
      ),
    ];
  }

  Widget _betaRow(BuildContext context, StorageEntry entry) {
    final p = context.rd;
    final l10n = context.l10n;
    final preview = _imagePreviewUrls[entry.path];
    final selected = _selectionMode && _selectedPaths.contains(entry.path);

    Widget leading =
        preview != null
            ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                preview,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const RdRowIcon(Icons.image_outlined),
              ),
            )
            : RdRowIcon(entry.isFolder ? Icons.folder_outlined : Icons.insert_drive_file_outlined);
    if (_selectionMode) {
      leading = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: selected ? p.primary : p.text2,
            semanticLabel: selected ? l10n.filesSelectNone : l10n.filesSelect,
          ),
          const SizedBox(width: 10),
          leading,
        ],
      );
    }

    String? subtitle;
    if (!entry.isFolder && entry.size != null) {
      subtitle = formatFileSize(entry.size);
      if (entry.updatedAt != null) {
        subtitle += ' · ${FilesSearch.formatUpdatedAt(entry.updatedAt)}';
      }
    }

    return RdListRow(
      key: ValueKey('rd-files-entry-${entry.path}'),
      leading: leading,
      title: entry.name,
      subtitle: subtitle,
      selected: selected,
      // A tap opens (folder) or opens/plays (file); the actions are behind "•••".
      showChevron: false,
      trailing:
          _selectionMode
              ? null
              : IconButton(
                key: ValueKey('rd-files-entry-more-${entry.path}'),
                icon: Icon(Icons.more_horiz, color: p.text2, semanticLabel: l10n.a11yMoreActions),
                onPressed: () => _betaEntryActions(entry),
              ),
      onTap: () {
        if (_selectionMode) {
          _toggleSelection(entry);
        } else {
          _openEntry(entry);
        }
      },
    );
  }

  /// Bottom bar while selecting: Verschieben and Löschen together.
  Widget _betaSelectionBar(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final none = _selectedPaths.isEmpty;
    return Material(
      key: const Key('rd-files-selection-bar'),
      color: p.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: none ? null : _moveSelected,
              icon: const Icon(Icons.drive_file_move_outlined),
              label: Text(l10n.filesMove),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: p.absent),
              onPressed: none ? null : _deleteSelected,
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.commonDelete),
            ),
          ],
        ),
      ),
    );
  }

  /// "+": Dateien hochladen or Ordner anlegen.
  Future<void> _betaAdd(BuildContext context) async {
    final l10n = context.l10n;
    final tenantId = ref.read(currentTenantIdProvider);
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        AppActionSheetAction(value: 'upload', label: l10n.filesUpload, icon: Icons.cloud_upload_outlined),
        AppActionSheetAction(value: 'folder', label: l10n.filesCreateFolder, icon: Icons.create_new_folder_outlined),
      ],
    );
    if (!mounted || !_stillIn(tenantId)) return;
    if (action == 'upload') _upload();
    if (action == 'folder') _createFolder();
  }

  /// "•••" of the page: everything for the whole folder.
  Future<void> _betaFolderActions(BuildContext button) async {
    final l10n = context.l10n;
    final tenantId = ref.read(currentTenantIdProvider);
    final canEdit = _canEdit;
    final segments = _pathSegments;
    final action = await showAppActionSheet<String>(
      context,
      title: segments.isEmpty ? l10n.filesTitle : segments.last,
      actions: [
        if (canEdit && _entries.isNotEmpty)
          AppActionSheetAction(value: 'select', label: l10n.filesSelectMultiple, icon: Icons.check_circle_outline),
        AppActionSheetAction(value: 'sort', label: l10n.filesSorting, subtitle: _sortLabel, icon: Icons.sort),
        AppActionSheetAction(
          value: 'share',
          label: segments.isNotEmpty ? l10n.filesFlutterShareFolderLink : l10n.filesFlutterShareRootLink,
          icon: Icons.link,
        ),
        if (canEdit && _isStorageAlmostFull)
          AppActionSheetAction(value: 'more', label: l10n.filesRequestMore, icon: Icons.add_circle_outline),
        AppActionSheetAction(value: 'help', label: l10n.a11yHelp, icon: Icons.help_outline),
      ],
    );
    // Started in a group switched away from: nothing happens.
    if (!mounted || !_stillIn(tenantId)) return;
    switch (action) {
      case 'select':
        _startSelection();
      case 'sort':
        await _betaSort();
      case 'share':
        await _shareEntry();
      case 'more':
        await _requestMoreStorage();
      case 'help':
        if (button.mounted) _showSearchHelp(button);
    }
  }

  /// Sortieren: one choice of field and direction (same orders as the
  /// old menu).
  Future<void> _betaSort() async {
    final l10n = context.l10n;
    String label(FilesSortBy by, bool asc) {
      final dir = asc ? l10n.filesAscending : l10n.filesDescending;
      return switch (by) {
        FilesSortBy.name => l10n.filesSortName(asc ? 'A-Z' : 'Z-A'),
        FilesSortBy.updatedAt => l10n.filesSortDate(dir),
        FilesSortBy.size => l10n.filesSortSize(dir),
      };
    }

    final picked = await showRdChoiceSheet<(FilesSortBy, bool)>(
      context,
      title: l10n.filesSorting,
      selected: (_sortBy, _ascending),
      options: [
        for (final by in FilesSortBy.values)
          for (final asc in [true, false]) ((by, asc), label(by, asc)),
      ],
    );
    if (picked == null || !mounted) return;
    // ignore: invalid_use_of_protected_member
    setState(() {
      _sortBy = picked.$1;
      _ascending = picked.$2;
      _entries = FilesSearch.sort(_entries, _sortBy, _ascending);
    });
  }

  /// "•••" of an entry: Öffnen first, Löschen red and last (same entries
  /// and conditions as the old popover).
  Future<void> _betaEntryActions(StorageEntry entry) async {
    final l10n = context.l10n;
    final tenantId = ref.read(currentTenantIdProvider);
    final canEdit = _canEdit;
    final isAudio = FilesSearch.isAudio(entry);
    final action = await showAppActionSheet<VoidCallback>(
      context,
      title: entry.name,
      actions: [
        AppActionSheetAction(
          value: () => _openEntry(entry),
          icon: isAudio ? Icons.play_circle_outline : Icons.open_in_new,
          label:
              entry.isFolder
                  ? l10n.filesFlutterOpenFolder
                  : isAudio
                  ? l10n.songsPlayRecording
                  : l10n.filesFlutterOpenDownload,
        ),
        if (!entry.isFolder)
          AppActionSheetAction(
            value: () => _downloadEntry(entry),
            icon: Icons.download_outlined,
            label: l10n.filesDownload,
          ),
        AppActionSheetAction(value: () => _shareEntry(entry), icon: Icons.link, label: l10n.filesShareLink),
        if (!entry.isFolder && (_telegramChatId?.isNotEmpty ?? false))
          AppActionSheetAction(
            value: () => _sendEntryPerTelegram(entry),
            icon: Icons.send_outlined,
            label: l10n.filesSendTelegram,
          ),
        if (canEdit) ...[
          AppActionSheetAction(value: () => _renameEntry(entry), icon: Icons.edit_outlined, label: l10n.filesRename),
          AppActionSheetAction(
            value: () => _moveEntry(entry),
            icon: Icons.drive_file_move_outlined,
            label: l10n.filesMove,
          ),
          AppActionSheetAction(
            value: () => _startSelection(entry),
            icon: Icons.check_circle_outline,
            label: l10n.filesSelectMultiple,
          ),
          AppActionSheetAction(
            value: () => _deleteEntry(entry),
            icon: Icons.delete_outline,
            label: l10n.commonDelete,
            destructive: true,
          ),
        ],
      ],
    );
    // An entry of a group switched away from is not acted on.
    if (!mounted || !_stillIn(tenantId)) return;
    action?.call();
  }
}
