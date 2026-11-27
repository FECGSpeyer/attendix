part of 'files_page.dart';

extension _FilesPageActions on _FilesPageState {
  // ---------------------------------------------------------------------------
  // Aktionen
  // ---------------------------------------------------------------------------

  Future<void> _openEntry(StorageEntry entry) async {
    if (entry.isFolder) {
      await _navigateTo(entry.path);
      return;
    }
    if (FilesSearch.isImage(entry)) {
      await _openImagePreview(entry);
      return;
    }
    if (FilesSearch.isAudio(entry)) {
      await _playAudio(entry);
      return;
    }
    await _downloadEntry(entry);
  }

  Future<void> _openImagePreview(StorageEntry entry) async {
    final repo = _repo;
    final tenantId = ref.read(currentTenantIdProvider);
    var url = _imagePreviewUrls[entry.path];
    if (url == null) {
      try {
        url = await repo.getSignedFileUrl(entry.path, expiresInSeconds: 3600);
        // A late URL of a group switched away from is neither cached nor shown.
        if (!mounted || !_stillIn(tenantId)) return;
        _imagePreviewUrls[entry.path] = url;
      } catch (e) {
        if (mounted && _stillIn(tenantId)) ToastHelper.showError(context, context.l10n.filesPreviewFailed(_errorText(e)));
        return;
      }
    }
    if (!mounted || !_stillIn(tenantId)) return;
    await showImageViewerSheet(context, url: url, fileName: entry.name);
  }

  /// INTEGRATION: plays all audio files of the folder as a queue, starting at
  /// the tapped one (Ionic playAudioEntry / AudioPlayerService.playQueue).
  Future<void> _playAudio(StorageEntry entry) async {
    final repo = _repo; // the queue resolves its URLs in the group it started in
    final audioEntries = _filteredEntries.where(FilesSearch.isAudio).toList();
    final list = audioEntries.isEmpty ? [entry] : audioEntries;
    final startIndex = list.indexWhere((e) => e.path == entry.path).clamp(0, list.length - 1);
    final queue = [
      for (final e in list)
        AudioQueueItem(
          fileName: e.name,
          title: e.name,
          resolveUrl: () => repo.getSignedFileUrl(e.path, expiresInSeconds: 3600),
        ),
    ];
    try {
      await ref.read(audioPlayerServiceProvider.notifier).playQueue(queue, startIndex);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.filesPlayFailed(_errorText(e)));
    }
  }

  String? get _telegramChatId =>
      ref.read(currentTenantUserProvider).valueOrNull?.telegramChatId;

  /// INTEGRATION: sends the file to the user's Telegram chat
  /// (Ionic sendEntryPerTelegram, Edge Function `send-document`).
  Future<void> _sendEntryPerTelegram(StorageEntry entry) async {
    if (entry.isFolder) return;
    final repo = _repo;
    final chatId = _telegramChatId;
    if (chatId == null || chatId.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.filesConnectTelegram);
      return;
    }
    ToastHelper.showInfo(context, context.l10n.filesSendingTelegram);
    try {
      final url = await repo.getSignedFileUrl(entry.path, expiresInSeconds: 600);
      await ref.read(telegramServiceProvider).sendDocumentPerTelegram(url: url, chatId: chatId);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.svcMessageSent);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.filesTelegramFailed(_errorText(e)));
    }
  }

  Future<void> _downloadEntry(StorageEntry entry) async {
    if (entry.isFolder) return;
    final openFailed = context.l10n.filesFlutterOpenLinkFailed;
    final repo = _repo;
    try {
      final url = await repo.getSignedFileUrl(entry.path, downloadName: entry.name);
      // NATIVE_MISC: native app → cache dir + system viewer (Ionic downloadFileNative)
      final ok = await NativeFileService.openUrl(url, fileName: entry.name);
      if (!ok) throw Exception(openFailed);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.filesDownloadFailed(_errorText(e)));
    }
  }

  String _shareLink(String path, bool isFolder) {
    final tenantId = ref.read(currentTenantIdProvider);
    final params = <String, String>{
      'tenantId': '$tenantId',
      'path': FilesRepository.normalizeRelativePath(path),
      if (isFolder) 'folder': '1',
    };
    return Uri.https('attendix.de', '/open-file', params).toString();
  }

  /// Ionic shareEntry: the system share sheet first (`navigator.share`,
  /// where available), cancelling it does nothing; otherwise the link is
  /// copied, and if that fails too it is shown in a toast.
  Future<void> _shareEntry([StorageEntry? entry]) async {
    final url = _shareLink(entry?.path ?? _currentPath, entry?.isFolder ?? true);
    final segments = _currentPath.split('/').where((s) => s.isNotEmpty).toList();
    final title = entry?.name ??
        (segments.isNotEmpty ? segments.last : context.l10n.filesTitle);
    if (canUseSystemShareSheet()) {
      try {
        final box = context.findRenderObject() as RenderBox?;
        // iPad: the share popover needs an origin.
        final origin = box == null || !box.hasSize
            ? null
            : box.localToGlobal(Offset.zero) & box.size;
        await Share.share(url, subject: title, sharePositionOrigin: origin);
        return; // shared or cancelled (Ionic AbortError)
      } catch (_) {
        // no share sheet after all: copy instead
      }
    }
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) ToastHelper.showSuccess(context, context.l10n.filesLinkCopied);
    } catch (_) {
      if (mounted) ToastHelper.showInfo(context, context.l10n.filesLinkToast(url));
    }
  }

  Future<void> _createFolder() async {
    final repo = _repo; // UI_TENANT_HOIST: bind before the first await
    if (!_canEdit) {
      ToastHelper.showWarning(context, context.l10n.filesNoEditRights);
      return;
    }
    final tenantId = ref.read(currentTenantIdProvider);
    final path = _currentPath;
    final name = await _askText(
      title: context.l10n.filesCreateFolder,
      hint: context.l10n.filesFolderName,
      confirmText: context.l10n.filesCreate,
    );
    if (name == null || name.trim().isEmpty || !mounted || !_stillIn(tenantId)) return;
    try {
      await repo.createFolder(path, name);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.filesFolderCreated);
      await _loadEntries();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.filesFolderFailed(_errorText(e)));
    }
  }

  Future<void> _renameEntry(StorageEntry entry) async {
    final repo = _repo; // UI_TENANT_HOIST: bind before the first await
    final tenantId = ref.read(currentTenantIdProvider);
    final name = await _askText(
      title: entry.isFolder ? context.l10n.filesRenameFolder : context.l10n.filesRenameFile,
      initial: entry.name,
      hint: context.l10n.filesNewName,
      confirmText: context.l10n.commonSave,
    );
    if (name == null || name.trim().isEmpty || !mounted || !_stillIn(tenantId)) return;
    try {
      await repo.renameEntry(entry.path, name, isFolder: entry.isFolder);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.filesRenamed);
      await _loadEntries();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.filesRenameFailed(_errorText(e)));
    }
  }

  Future<void> _moveEntry(StorageEntry entry) => _moveEntries([entry]);

  /// Ionic `Utils.getLoadingElement()`: the `ion-loading` box until [work]
  /// is done (WER-19).
  Future<void> _withLoading(Future<void> Function() work, {String? message}) =>
      withIonLoading<void>(context, work, message: message);

  // ---- Ionic 4.19.1: Mehrfachauswahl ----

  List<StorageEntry> get _selectedEntries =>
      _entries.where((e) => _selectedPaths.contains(e.path)).toList();

  bool get _allVisibleSelected {
    final visible = _filteredEntries;
    return visible.isNotEmpty && visible.every((e) => _selectedPaths.contains(e.path));
  }

  void _startSelection([StorageEntry? entry]) {
    if (!_canEdit) {
      ToastHelper.showWarning(context, context.l10n.filesNoEditRights);
      return;
    }
    _update(() {
      _selectionMode = true;
      _selectionFolder = _currentPath;
      _selectedPaths = {if (entry != null) entry.path};
    });
  }

  void _exitSelection() => _update(() {
        _selectionMode = false;
        _selectedPaths = {};
      });

  void _toggleSelection(StorageEntry entry) => _update(() {
        _selectedPaths = {..._selectedPaths};
        if (!_selectedPaths.remove(entry.path)) _selectedPaths.add(entry.path);
      });

  void _toggleSelectAll() {
    final visible = _filteredEntries.map((e) => e.path);
    _update(() {
      _selectedPaths = _allVisibleSelected
          ? (_selectedPaths.difference(visible.toSet()))
          : {..._selectedPaths, ...visible};
    });
  }

  /// The selection only holds in the folder it started in; entries that no
  /// longer exist drop out.
  void _syncSelection() {
    if (!_selectionMode) return;
    if (_currentPath != _selectionFolder) {
      _selectionMode = false;
      _selectedPaths = {};
      return;
    }
    final existing = {for (final e in _entries) e.path};
    _selectedPaths = _selectedPaths.where(existing.contains).toSet();
  }

  Future<void> _moveSelected() async {
    final entries = _selectedEntries;
    if (entries.isEmpty) return;
    if (await _moveEntries(entries) && mounted) _exitSelection();
  }

  Future<void> _deleteSelected() async {
    final repo = _repo; // UI_TENANT_HOIST: bind before the first await
    final entries = _selectedEntries;
    if (entries.isEmpty || !_canEdit) return;
    final l10n = context.l10n;
    final tenantId = ref.read(currentTenantIdProvider);
    final confirmed = await _confirm(
      title: l10n.filesDeleteSelectedHeader(entries.length),
      message: l10n.filesDeleteSelectedMessage(entries.length),
      confirmText: l10n.commonDelete,
    );
    if (!confirmed || !mounted || !_stillIn(tenantId)) return;
    var failed = 0;
    await _withLoading(() async {
      for (final entry in entries) {
        // Group switched meanwhile: nothing more is deleted.
        if (!mounted || !_stillIn(tenantId)) {
          failed++;
          continue;
        }
        try {
          await repo.deleteEntry(entry.path, isFolder: entry.isFolder);
        } catch (_) {
          failed++;
        }
      }
    });
    if (!mounted) return;
    final ok = entries.length - failed;
    if (failed > 0) {
      ToastHelper.showWarning(context, l10n.filesDeleteSummary(ok, failed));
    } else {
      ToastHelper.showSuccess(context, l10n.filesDeletedMany(ok));
    }
    _exitSelection();
    await _loadEntries();
  }

  /// Ionic `moveEntries`: picks the target in the folder tree and moves the
  /// entries; entries whose name already exists in the target are skipped
  /// instead of overwritten. True when something was moved.
  Future<bool> _moveEntries(List<StorageEntry> entries) async {
    final repo = _repo; // UI_TENANT_HOIST: bind before the first await
    if (!_canEdit) {
      ToastHelper.showWarning(context, context.l10n.filesNoEditRights);
      return false;
    }
    final tenantId = ref.read(currentTenantIdProvider);
    final target = await showFilesMoveModal(
      context,
      repo: repo,
      items: entries,
      currentPath: _currentPath,
    );
    if (target == null || !mounted || !_stillIn(tenantId)) return false;
    final l10n = context.l10n;

    var ok = 0;
    var skipped = 0;
    var failed = 0;
    var lastError = '';
    try {
      await _withLoading(() async {
        final existingNames = {for (final e in await repo.listEntries(target)) e.name};
        for (final entry in entries) {
          // Group switched meanwhile: nothing more is moved.
          if (!mounted || !_stillIn(tenantId)) {
            skipped++;
            continue;
          }
          if (existingNames.contains(entry.name)) {
            skipped++;
            continue;
          }
          try {
            await repo.moveEntry(entry.path, target, isFolder: entry.isFolder);
            ok++;
          } catch (e) {
            failed++;
            lastError = _errorText(e);
          }
        }
      });
    } catch (e) {
      if (mounted) ToastHelper.showError(context, l10n.filesMoveFailed(_errorText(e)));
      return false;
    }
    if (!mounted) return ok > 0;

    if (entries.length == 1 && failed > 0) {
      ToastHelper.showError(context, l10n.filesMoveFailed(lastError));
    } else if (entries.length == 1 && skipped > 0) {
      ToastHelper.showWarning(context, l10n.filesMoveExists(entries.first.name));
    } else if (skipped > 0 || failed > 0) {
      ToastHelper.showWarning(context, l10n.filesMoveSummary(ok, skipped, failed));
    } else {
      ToastHelper.showSuccess(context, l10n.filesMovedMany(ok));
    }
    await _loadEntries();
    return ok > 0;
  }

  Future<void> _deleteEntry(StorageEntry entry) async {
    final repo = _repo; // UI_TENANT_HOIST: bind before the first await
    final tenantId = ref.read(currentTenantIdProvider);
    final confirmed = await _confirm(
      title: entry.isFolder ? context.l10n.filesDeleteFolder : context.l10n.filesDeleteFile,
      message: context.l10n.filesDeleteMessage(entry.name),
      confirmText: context.l10n.commonDelete,
    );
    if (!confirmed || !mounted || !_stillIn(tenantId)) return;
    try {
      await repo.deleteEntry(entry.path, isFolder: entry.isFolder);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.filesDeleted);
      await _loadEntries();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.filesDeleteFailed(_errorText(e)));
    }
  }

  Future<void> _requestMoreStorage() async {
    // The request names the group (and usage) it was started in.
    final tenantId = ref.read(currentTenantIdProvider);
    final tenant = ref.read(currentTenantProvider);
    final max = _maxBytes;
    final usedBytes = _usedBytes;
    final controller = TextEditingController();
    final note = await showAppDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.filesRequestMore),
        // Ionic alert: message + `type: 'textarea'` input (files.page.ts).
        content: AppAlertInputGroup(
          message: Text(context.l10n.filesRequestHint),
          children: [
            const AppAlertBetaGap(AppDimensions.paddingS),
            AppAlertInput(
              controller: controller,
              maxLines: 3,
              textarea: true,
              placeholder: ctx.l10n.filesHowMuch,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.commonCancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(context.l10n.filesSend)),
        ],
      ),
    );
    controller.dispose();
    if (note == null || !mounted || !_stillIn(tenantId)) return;

    final usage = max != null
        ? '${formatFileSize(usedBytes ?? 0)} von ${formatFileSize(max)}'
        : formatFileSize(usedBytes ?? 0);
    final message = [
      'Anfrage: Mehr Speicher für die Dateiablage',
      'Instanz: ${tenant?.longName} (ID ${tenant?.id})',
      'Belegt: $usage',
      if (note.trim().isNotEmpty) 'Nachricht: ${note.trim()}',
    ].join('\n');

    final ok = await ref.read(feedbackNotifierProvider.notifier).sendQuestion(message: message);
    if (!mounted) return;
    if (ok) {
      ToastHelper.showSuccess(context, context.l10n.filesRequestSent);
    } else {
      final error = ref.read(feedbackNotifierProvider).error;
      ToastHelper.showError(context, context.l10n.filesRequestFailed(error ?? ''));
    }
  }

  /// Fragt bei Duplikaten nach: 'overwrite' | 'skip' | null (Abbrechen)
  Future<String?> _askDuplicateHandling(List<String> names) {
    final preview = names.take(5).join(', ');
    final suffix = names.length > 5 ? context.l10n.filesAndMore(names.length - 5) : '';
    return showAppDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.filesExists),
        content: Text(ctx.l10n.filesExistsMessage('$preview$suffix')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, 'skip'), child: Text(context.l10n.filesSkip)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, 'overwrite'), child: Text(context.l10n.filesOverwrite)),
        ],
      ),
    );
  }

  /// Speicherlimit vorab prüfen (Storage-Policy blockt erst bei erreichtem Limit).
  Future<bool> _hasEnoughSpace(List<PlatformFile> files, Map<PlatformFile, String> names,
      Set<String> duplicates, bool overwrite) async {
    final max = _maxBytes;
    if (max == null) return true;
    await _loadUsage();
    final sizeByName = {for (final e in _entries.where((e) => !e.isFolder)) e.name: e.size ?? 0};
    var needed = 0;
    for (final f in files) {
      final name = names[f] ?? '';
      if (duplicates.contains(name)) {
        if (!overwrite) continue;
        final diff = f.size - (sizeByName[name] ?? 0);
        needed += diff > 0 ? diff : 0;
      } else {
        needed += f.size;
      }
    }
    final free = (max - (_usedBytes ?? 0)).clamp(0, max);
    if (needed <= free) return true;
    if (!mounted) return false;

    final request = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.filesStorageFull),
        content: Text(
          ctx.l10n.filesStorageFullMessage(formatFileSize(needed), formatFileSize(free), formatFileSize(max)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonOk)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.filesRequestMore)),
        ],
      ),
    );
    if (request == true && mounted) await _requestMoreStorage();
    return false;
  }

  ({void Function(String) update, VoidCallback close}) _showUploadProgress(String initial) {
    final progress = ValueNotifier<String>(initial);
    final navigator = Navigator.of(context, rootNavigator: true);
    showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AppAlertDialog(
        content: Row(
          children: [
            const AppSpinner(),
            const SizedBox(width: AppDimensions.paddingM),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (_, value, __) => Text(value),
              ),
            ),
          ],
        ),
      ),
    );
    return (
      update: (m) => progress.value = m,
      close: () {
        if (mounted) navigator.pop();
        progress.dispose();
      },
    );
  }

  Future<void> _upload() async {
    if (!_canEdit) {
      ToastHelper.showWarning(context, context.l10n.filesNoEditRights);
      return;
    }
    // SOL_FIX3: bind the (per-tenant) repository once for the whole upload
    // job, so a tenant switch mid-upload never uploads into another tenant.
    final repo = _repo;
    final tenantId = ref.read(currentTenantIdProvider);
    final path = _currentPath;
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result == null || result.files.isEmpty || !mounted || !_stillIn(tenantId) || path != _currentPath) return;
    final files = result.files.where((f) => f.bytes != null).toList();
    if (files.isEmpty) return;

    final existing = _entries.where((e) => !e.isFolder).map((e) => e.name).toSet();
    final names = {for (final f in files) f: FilesRepository.sanitizeFileName(f.name)};
    final duplicates = names.values.where(existing.contains).toSet();

    var overwrite = false;
    if (duplicates.isNotEmpty) {
      final handling = await _askDuplicateHandling(duplicates.toList());
      if (handling == null || !mounted || !_stillIn(tenantId)) return;
      overwrite = handling == 'overwrite';
    }
    if (!await _hasEnoughSpace(files, names, duplicates, overwrite) || !mounted || !_stillIn(tenantId)) return;

    final loading = _showUploadProgress(context.l10n.filesUploadProgress(0, files.length, 0));

    var success = 0, failed = 0, skipped = 0, processed = 0;
    String progressText(String? name) {
      final percent = files.isEmpty ? 0 : ((processed / files.length) * 100).round();
      final base = context.l10n.filesUploadProgress(processed, files.length, percent);
      return name != null ? '$base\n$name' : base;
    }

    for (final f in files) {
      final name = names[f]!;
      final isDuplicate = duplicates.contains(name);
      loading.update(progressText(name));
      // Group switched meanwhile: the rest is skipped (nothing more is
      // uploaded into the old group).
      if ((isDuplicate && !overwrite) || !mounted || !_stillIn(tenantId)) {
        skipped++;
        processed++;
        continue;
      }
      try {
        await repo.uploadFile(path, f.name, f.bytes!, overwrite: isDuplicate && overwrite);
        ref.read(trackingServiceProvider).track(TrackingEvent.fileUploaded, properties: {'size': f.size, 'mime': songFileMimeType(f.extension ?? '')});
        success++;
      } catch (_) {
        failed++;
      }
      processed++;
      loading.update(progressText(null));
    }

    loading.close();
    if (!mounted) return;

    if (success > 0 && failed == 0 && skipped == 0) {
      ToastHelper.showSuccess(
          context, success == 1 ? context.l10n.filesUploadedOne : context.l10n.filesUploadedMany(success));
    } else if (success > 0 || failed > 0 || skipped > 0) {
      ToastHelper.showWarning(context, context.l10n.filesUploadSummary(success, skipped, failed));
    } else {
      ToastHelper.showInfo(context, context.l10n.filesNoneUploaded);
    }
    await _loadEntries();
  }

  /// Ionic files search help: an `ion-popover` at the help button – "Suche"
  /// with the free-text hint, then the filter examples (HTML, bold).
  void _showSearchHelp(BuildContext button) {
    showAppPopover<void>(
      context: button,
      builder: (context) {
        final heading = AppPopoverText.heading(context);
        final p = AppPopoverText.paragraph(context);
        Widget item(List<Widget> children) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            item([
              Text(context.l10n.filesSearch, style: heading),
              const SizedBox(height: 2),
              Text(context.l10n.filesSearchHelp, style: p),
            ]),
            item([
              for (final html in [
                context.l10n.filesSearchType,
                context.l10n.filesSearchDate,
                context.l10n.filesSearchCombine,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text.rich(TextSpan(style: p, children: _strongSpans(html))),
                ),
            ]),
          ],
        );
      },
    );
  }

}

/// The search help keys are HTML with `<strong>` and escaped `<`/`>`.
List<TextSpan> _strongSpans(String html) {
  String decode(String s) => s
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
  final spans = <TextSpan>[];
  final strong = RegExp(r'<strong>(.*?)</strong>');
  var last = 0;
  for (final m in strong.allMatches(html)) {
    if (m.start > last) spans.add(TextSpan(text: decode(html.substring(last, m.start))));
    spans.add(TextSpan(
      text: decode(m.group(1)!),
      style: const TextStyle(fontWeight: FontWeight.bold),
    ));
    last = m.end;
  }
  if (last < html.length) spans.add(TextSpan(text: decode(html.substring(last))));
  return spans;
}
