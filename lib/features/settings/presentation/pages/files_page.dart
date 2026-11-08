import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/feedback_providers.dart';
import '../../../../core/providers/files_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/audio_player/audio_player_service.dart';
import '../../../../core/services/native/native_file_service.dart';
import '../../../../core/services/telegram_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/system_share.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/storage/storage_entry.dart';
import '../../../../data/repositories/base_repository.dart';
import '../../../../data/repositories/files_repository.dart';
import '../../../../shared/widgets/sheets/image_viewer_sheet.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/files_move_modal.dart';
import '../widgets/settings_list.dart';
import '../../../../shared/widgets/layout/ionic_md.dart' show IonMd;
import '../../../../core/utils/file_mime.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/router/route_access.dart' show canOpenSongsTab;
import '../../../../core/providers/debug_providers.dart' show effectiveRoleProvider;
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/manage/rd_settings_sheets.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../redesign/presentation/widgets/today/rd_today_common.dart' show RdInfoCard;

part 'files_page_beta.dart';

enum FilesSortBy { name, updatedAt, size }

/// Suchfilter der Dateiablage (Freitext + `typ:` + `datum:`)
class FilesSearchFilters {
  const FilesSearchFilters({this.text = '', this.type = '', this.date = ''});
  final String text;
  final String type;
  final String date;
}

/// Pure Such-/Sortierlogik (wie FilesPage in Ionic), testbar ohne Widgets.
class FilesSearch {
  FilesSearch._();

  static String normalize(String value) {
    var s = value
        .replaceAll('ß', 'ss')
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('Ä', 'ae')
        .replaceAll('Ö', 'oe')
        .replaceAll('Ü', 'ue');
    return s.toLowerCase().trim();
  }

  static String _compact(String value) => normalize(value).replaceAll(RegExp(r'[^a-z0-9]'), '');

  static FilesSearchFilters parse(String raw) {
    final parts = raw.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final textParts = <String>[];
    var type = '';
    var date = '';
    for (final part in parts) {
      final n = normalize(part);
      if (n.startsWith('typ:') || n.startsWith('type:')) {
        type = n.split(':').skip(1).join(':').trim();
        continue;
      }
      if (n.startsWith('datum:') || n.startsWith('date:')) {
        date = n.split(':').skip(1).join(':').trim();
        continue;
      }
      textParts.add(part);
    }
    return FilesSearchFilters(text: normalize(textParts.join(' ')), type: type, date: date);
  }

  static String extension(StorageEntry entry) {
    if (entry.isFolder) return '';
    final i = entry.name.lastIndexOf('.');
    return i <= 0 ? '' : entry.name.substring(i + 1);
  }

  static String formatUpdatedAt(DateTime? d) =>
      d == null ? '' : DateFormat('${dateFmt()}, HH:mm').format(d);

  static bool _matchesType(StorageEntry entry, String typeFilter) {
    if (typeFilter.isEmpty) return true;
    final t = normalize(typeFilter);
    if (['ordner', 'folder', 'dir', 'verzeichnis'].contains(t)) return entry.isFolder;
    if (['datei', 'file'].contains(t)) return !entry.isFolder;
    final ext = normalize(extension(entry));
    if (ext.isEmpty) return false;
    return ext == t || ext.contains(t);
  }

  static bool _matchesDate(StorageEntry entry, String dateFilter) {
    if (dateFilter.isEmpty) return true;
    final d = entry.updatedAt;
    if (d == null) return false;
    String two(int v) => v.toString().padLeft(2, '0');
    final candidates = [
      formatUpdatedAt(d),
      '${two(d.day)}.${two(d.month)}.${d.year}',
      '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}',
      '${d.year}-${two(d.month)}-${two(d.day)}',
      '${d.year}-${two(d.month)}',
      '${two(d.month)}.${d.year}',
      d.toIso8601String(),
    ];
    final nf = normalize(dateFilter);
    final cf = _compact(dateFilter);
    return candidates.any((c) => normalize(c).contains(nf) || _compact(c).contains(cf));
  }

  static bool matches(StorageEntry entry, FilesSearchFilters filters) {
    final kindLabel = entry.isFolder ? 'ordner folder verzeichnis dir' : 'datei file';
    final searchable = normalize([
      entry.name,
      extension(entry),
      kindLabel,
      formatUpdatedAt(entry.updatedAt),
      entry.updatedAt?.toIso8601String() ?? '',
    ].where((s) => s.isNotEmpty).join(' '));
    final textOk = filters.text.isEmpty || searchable.contains(filters.text);
    return textOk && _matchesType(entry, filters.type) && _matchesDate(entry, filters.date);
  }

  static List<StorageEntry> sort(List<StorageEntry> entries, FilesSortBy by, bool ascending) {
    final factor = ascending ? 1 : -1;
    final list = [...entries];
    list.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      var cmp = 0;
      switch (by) {
        case FilesSortBy.updatedAt:
          cmp = (a.updatedAt?.millisecondsSinceEpoch ?? 0).compareTo(b.updatedAt?.millisecondsSinceEpoch ?? 0);
        case FilesSortBy.size:
          cmp = (a.size ?? 0).compareTo(b.size ?? 0);
        case FilesSortBy.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (cmp == 0) cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return cmp * factor;
    });
    return list;
  }

  static bool isImage(StorageEntry e) =>
      !e.isFolder && RegExp(r'\.(png|jpe?g|gif|webp|bmp|svg|heic|heif|avif)$').hasMatch(e.name.toLowerCase());

  static bool isAudio(StorageEntry e) => !e.isFolder && AudioPlayerService.isAudioFile(e.name);
}

/// Dateiablage (Ionic: settings/files)
class FilesPage extends ConsumerStatefulWidget {
  const FilesPage({super.key, this.initialPath, this.openFileName});

  /// Ordner aus Direktlink (?path=)
  final String? initialPath;

  /// Datei aus Direktlink, die direkt geöffnet wird (?open=)
  final String? openFileName;

  @override
  ConsumerState<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends ConsumerState<FilesPage> {
  final _searchController = TextEditingController();

  List<StorageEntry> _entries = [];
  final Map<String, String> _imagePreviewUrls = {};
  String _currentPath = '';
  bool _isLoading = false;
  FilesSortBy _sortBy = FilesSortBy.name;
  bool _ascending = true;
  int? _usedBytes;

  // Ionic 4.19.1: multi-select
  bool _selectionMode = false;
  Set<String> _selectedPaths = {};
  String _selectionFolder = '';

  @override
  void initState() {
    super.initState();
    _currentPath = FilesRepository.normalizeRelativePath(widget.initialPath);
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  FilesRepository get _repo => ref.read(filesRepositoryWithTenantProvider);

  /// The new design (Beta switch): same logic, Beta look and sheets.
  bool get _beta => ref.read(redesignEnabledProvider);

  /// Whether [tenantId] (read when an action started) is still the current
  /// group; an action that started in another group writes nothing.
  bool _stillIn(int? tenantId) => mounted && tenantId != null && ref.read(currentTenantIdProvider) == tenantId;

  /// After a group switch the page starts over in the root of the new
  /// group: nothing of the old group (entries, previews, usage, selection,
  /// path) stays visible or selectable.
  void _onTenantChanged() {
    setState(() {
      _entries = [];
      _isLoading = false;
      _imagePreviewUrls.clear();
      _usedBytes = null;
      _currentPath = '';
      _selectionMode = false;
      _selectedPaths = {};
      _searchController.clear();
    });
    // After the switch has reached the repository provider (the listener
    // runs while the tenant is still being updated).
    Future.microtask(() {
      if (mounted) _loadEntries();
    });
  }

  /// Text input: the Beta text sheet or the old dialog.
  Future<String?> _askText({required String title, String initial = '', String? hint, String? confirmText}) {
    if (_beta) {
      return showRdTextSheet(context, title: title, initial: initial, hint: hint, capitalization: TextCapitalization.none);
    }
    return DialogHelper.showTextInput(
      context,
      title: title,
      initialValue: initial.isEmpty ? null : initial,
      hint: hint,
      confirmText: confirmText,
    );
  }

  /// Confirmation: the Beta confirm or the old dialog.
  Future<bool> _confirm({required String title, required String message, required String confirmText}) {
    if (_beta) {
      return showAppConfirm(context, title: title, message: message, confirmText: confirmText, destructive: true);
    }
    return DialogHelper.showConfirmation(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      isDestructive: true,
    );
  }
  bool get _canEdit => ref.read(canEditFilesProvider);
  int? get _maxBytes => ref.read(currentTenantProvider)?.filesMaxBytes;

  Future<void> _init() async {
    await _loadEntries();
    final openName = widget.openFileName;
    if (openName == null || openName.isEmpty || !mounted) return;
    final entry = _entries.where((e) => !e.isFolder && e.name == openName).firstOrNull;
    if (entry == null) {
      ToastHelper.showWarning(context, context.l10n.filesLinkedNotFound);
      return;
    }
    await _openEntry(entry);
  }

  static String _errorText(Object e) {
    if (e is RepositoryException) {
      final original = e.originalError;
      if (original is RepositoryException) return original.message;
      if (original != null) {
        try {
          return (original as dynamic).message as String;
        } catch (_) {}
      }
      return friendlyErrorMessage(e);
    }
    return friendlyErrorMessage(e);
  }

  List<String> get _pathSegments => _currentPath.split('/').where((s) => s.isNotEmpty).toList();

  bool get _hasSearchTerm => _searchController.text.trim().isNotEmpty;

  List<StorageEntry> get _filteredEntries {
    if (!_hasSearchTerm) return _entries;
    final filters = FilesSearch.parse(_searchController.text);
    return _entries.where((e) => FilesSearch.matches(e, filters)).toList();
  }

  bool get _isStorageAlmostFull {
    final max = _maxBytes;
    return max != null && _usedBytes != null && _usedBytes! >= max * 0.8;
  }

  String get _storageStatusLabel {
    if (!_isStorageAlmostFull) return '';
    return (_usedBytes ?? 0) >= (_maxBytes ?? 0) ? context.l10n.filesFull : context.l10n.filesAlmostFull;
  }

  String get _sortLabel {
    final l10n = context.l10n;
    final dir = _ascending ? l10n.filesAscending : l10n.filesDescending;
    switch (_sortBy) {
      case FilesSortBy.updatedAt:
        return l10n.filesSortDate(dir);
      case FilesSortBy.size:
        return l10n.filesSortSize(dir);
      case FilesSortBy.name:
        return l10n.filesSortName(_ascending ? 'A-Z' : 'Z-A');
    }
  }

  Future<void> _loadEntries() async {
    final repo = _repo;
    if (!repo.hasTenantId) return;
    final tenantId = ref.read(currentTenantIdProvider);
    // Only a repository of the current group lists (never a stale one).
    if (repo.currentTenantId != tenantId) return;
    final path = _currentPath;
    setState(() => _isLoading = true);
    try {
      final loaded = await repo.listEntries(path);
      // A result of another group or folder (switched meanwhile) is dropped.
      if (!mounted || !_stillIn(tenantId) || path != _currentPath) return;
      setState(() {
        _entries = FilesSearch.sort(loaded, _sortBy, _ascending);
        _syncSelection();
      });
      await _loadImagePreviews();
      if (_canEdit && _stillIn(tenantId)) await _loadUsage();
    } catch (e) {
      if (mounted && _stillIn(tenantId)) ToastHelper.showError(context, context.l10n.filesLoadFailed(_errorText(e)));
    } finally {
      // Only the current load ends the spinner (a dropped one of another
      // group or folder does not).
      if (mounted && _stillIn(tenantId) && path == _currentPath) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUsage() async {
    final tenantId = ref.read(currentTenantIdProvider);
    try {
      final used = await _repo.getUsedBytes();
      if (_stillIn(tenantId)) setState(() => _usedBytes = used);
    } catch (_) {
      if (_stillIn(tenantId)) setState(() => _usedBytes = null);
    }
  }

  Future<void> _loadImagePreviews() async {
    final repo = _repo; // UI_TENANT_HOIST: bind before the first await
    final tenantId = ref.read(currentTenantIdProvider);
    _imagePreviewUrls.clear();
    final images = _entries.where(FilesSearch.isImage).toList();
    if (images.isEmpty) return;
    final results = await Future.wait(images.map((e) async {
      try {
        return MapEntry(e.path, await repo.getSignedFileUrl(e.path, expiresInSeconds: 3600));
      } catch (_) {
        return MapEntry(e.path, '');
      }
    }));
    if (!mounted || !_stillIn(tenantId)) return;
    setState(() {
      for (final r in results) {
        if (r.value.isNotEmpty) _imagePreviewUrls[r.key] = r.value;
      }
    });
  }

  Future<void> _navigateTo(String path) async {
    setState(() {
      _currentPath = path;
      _searchController.clear();
    });
    await _loadEntries();
  }

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

  /// Ionic `Utils.getLoadingElement()`: blocking spinner until [work] is done.
  Future<void> _withLoading(Future<void> Function() work) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: Center(child: AppSpinner())),
    );
    try {
      await work();
    } finally {
      navigator.pop();
    }
  }

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
    setState(() {
      _selectionMode = true;
      _selectionFolder = _currentPath;
      _selectedPaths = {if (entry != null) entry.path};
    });
  }

  void _exitSelection() => setState(() {
        _selectionMode = false;
        _selectedPaths = {};
      });

  void _toggleSelection(StorageEntry entry) => setState(() {
        _selectedPaths = {..._selectedPaths};
        if (!_selectedPaths.remove(entry.path)) _selectedPaths.add(entry.path);
      });

  void _toggleSelectAll() {
    final visible = _filteredEntries.map((e) => e.path);
    setState(() {
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.filesRequestHint),
            const SizedBox(height: AppDimensions.paddingS),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(hintText: ctx.l10n.filesHowMuch),
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

    final progress = ValueNotifier<String>(context.l10n.filesUploadProgress(0, files.length, 0));
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

    var success = 0, failed = 0, skipped = 0, processed = 0;
    String progressText(String? name) {
      final percent = files.isEmpty ? 0 : ((processed / files.length) * 100).round();
      final base = context.l10n.filesUploadProgress(processed, files.length, percent);
      return name != null ? '$base\n$name' : base;
    }

    for (final f in files) {
      final name = names[f]!;
      final isDuplicate = duplicates.contains(name);
      progress.value = progressText(name);
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
      progress.value = progressText(null);
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
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

  /// The search help keys are HTML with `<strong>` and escaped `<`/`>`.
  static List<TextSpan> _strongSpans(String html) {
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

  /// Ionic `ion-popover` at the ⋯ button of an entry (same entries,
  /// order and conditions; a tap outside closes it).
  Future<void> _showEntryActions(BuildContext button, StorageEntry entry) async {
    final tenantId = ref.read(currentTenantIdProvider);
    final canEdit = _canEdit;
    final isAudio = FilesSearch.isAudio(entry);
    final action = await showAppPopoverMenu<VoidCallback>(
      context: button,
      items: [
        AppPopoverMenuItem(
          value: () => _openEntry(entry),
          icon: isAudio ? Icons.play_circle_outline : Icons.open_in_new,
          label: entry.isFolder
              ? context.l10n.filesFlutterOpenFolder
              : isAudio
                  ? context.l10n.songsPlayRecording
                  : context.l10n.filesFlutterOpenDownload,
        ),
        if (!entry.isFolder)
          AppPopoverMenuItem(
            value: () => _downloadEntry(entry),
            icon: Icons.download_outlined,
            label: context.l10n.filesDownload,
          ),
        AppPopoverMenuItem(
          value: () => _shareEntry(entry),
          icon: Icons.link,
          label: context.l10n.filesShareLink,
        ),
        // INTEGRATION: Ionic files "Per Telegram senden"
        if (!entry.isFolder && (_telegramChatId?.isNotEmpty ?? false))
          AppPopoverMenuItem(
            value: () => _sendEntryPerTelegram(entry),
            icon: Icons.send_outlined,
            label: context.l10n.filesSendTelegram,
          ),
        if (canEdit) ...[
          AppPopoverMenuItem(
            value: () => _renameEntry(entry),
            icon: Icons.edit_outlined,
            label: context.l10n.filesRename,
          ),
          AppPopoverMenuItem(
            value: () => _moveEntry(entry),
            icon: Icons.swap_horiz,
            label: context.l10n.filesMove,
          ),
          // Ionic 4.19.1: "Mehrere auswählen" (starts with this entry)
          AppPopoverMenuItem(
            value: () => _startSelection(entry),
            icon: Icons.check_circle_outline,
            label: context.l10n.filesSelectMultiple,
          ),
          // Ionic: plain item (not red) like the others
          AppPopoverMenuItem(
            value: () => _deleteEntry(entry),
            icon: Icons.delete_outline,
            label: context.l10n.commonDelete,
          ),
        ],
      ],
    );
    // An entry of a group switched away from is not acted on.
    if (!mounted || !_stillIn(tenantId)) return;
    action?.call();
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'upload':
        _upload();
      case 'folder':
        _createFolder();
      case 'select':
        _startSelection();
      case 'share':
        _shareEntry();
      case 'sort_name':
        setState(() {
          _sortBy = FilesSortBy.name;
          _entries = FilesSearch.sort(_entries, _sortBy, _ascending);
        });
      case 'sort_date':
        setState(() {
          _sortBy = FilesSortBy.updatedAt;
          _entries = FilesSearch.sort(_entries, _sortBy, _ascending);
        });
      case 'sort_size':
        setState(() {
          _sortBy = FilesSortBy.size;
          _entries = FilesSearch.sort(_entries, _sortBy, _ascending);
        });
      case 'sort_dir':
        setState(() {
          _ascending = !_ascending;
          _entries = FilesSearch.sort(_entries, _sortBy, _ascending);
        });
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final canAccess = ref.watch(canAccessFilesProvider);
    final isRoleLoading = ref.watch(isRoleLoadingProvider);
    final canEdit = ref.watch(canEditFilesProvider);
    ref.listen<int?>(currentTenantIdProvider, (prev, next) {
      if (prev != next) _onTenantChanged();
    });
    if (ref.watch(redesignEnabledProvider)) {
      return _buildBeta(context, canAccess: canAccess, isRoleLoading: isRoleLoading, canEdit: canEdit);
    }

    return Scaffold(
      // Ionic 4.19.1: selection toolbar (✕, "n ausgewählt", Alle/Keine)
      appBar: _selectionMode
          ? AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.filesSelectionDone,
                onPressed: _exitSelection,
              ),
              title: Text(context.l10n.filesSelectedCount(_selectedPaths.length)),
              actions: [
                TextButton(
                  onPressed: _toggleSelectAll,
                  child: IonButtonLabel(_allVisibleSelected
                      ? context.l10n.filesSelectNone
                      : context.l10n.filesSelectAll),
                ),
              ],
            )
          : AppBar(
        title: Text(context.l10n.filesTitle),
        // UX_SETTINGS (WAVE 8): files.page.html — arrow-back button.
        // IOS_FORMS2: iOS → start/end ion-buttons in Liquid Glass circles
        leading: ionIsIos(context)
            ? Center(
                child: Semantics(
                  button: true,
                  label: MaterialLocalizations.of(context).backButtonTooltip,
                  child: GestureDetector(
                    onTap: () => context.canPop() ? context.pop() : context.go('/settings'),
                    // PARITY_R7: Ionic `ion-buttons` glass around a clear
                    // icon-only `ion-button` (28px ionicon, 25px radius) is
                    // larger than the 44pt back circle.
                    child: const IosCircleIcon(icon: Icons.arrow_back, size: 48, iconSize: 24),
                  ),
                ),
              )
            : IconButton(
                icon: Icon(Icons.arrow_back, semanticLabel: context.l10n.commonBack),
                onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
              ),
        leadingWidth: ionIsIos(context) ? 72 : null, // PARITY_R7: 12 + 48 + 12
        actions: [
          if (canAccess)
            ToolbarButtonGroup(children: [
            // Ionic 4.19.1: "Auswählen" (checkmark-circle-outline)
            if (canEdit && _entries.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: context.l10n.filesSelect,
                onPressed: () => _startSelection(),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: _onMenuSelected,
              itemBuilder: (_) => [
                if (canEdit) ...[
                  PopupMenuItem(
                    value: 'upload',
                    child: ListTile(leading: const Icon(Icons.cloud_upload_outlined), title: Text(context.l10n.filesUpload), contentPadding: EdgeInsets.zero),
                  ),
                  PopupMenuItem(
                    value: 'folder',
                    child: ListTile(leading: const Icon(Icons.create_new_folder_outlined), title: Text(context.l10n.filesCreateFolder), contentPadding: EdgeInsets.zero),
                  ),
                  // Ionic 4.19.1: "Mehrere auswählen"
                  if (_entries.isNotEmpty)
                    PopupMenuItem(
                      value: 'select',
                      child: ListTile(leading: const Icon(Icons.check_circle_outline), title: Text(context.l10n.filesSelectMultiple), contentPadding: EdgeInsets.zero),
                    ),
                ],
                PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: const Icon(Icons.share_outlined),
                    title: Text(_currentPath.isNotEmpty ? context.l10n.filesFlutterShareFolderLink : context.l10n.filesFlutterShareRootLink),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  enabled: false,
                  child: ListTile(title: Text(context.l10n.filesSorting), subtitle: Text(_sortLabel), contentPadding: EdgeInsets.zero),
                ),
                PopupMenuItem(
                  value: 'sort_name',
                  child: ListTile(leading: const Icon(Icons.text_fields), title: Text(context.l10n.filesName), contentPadding: EdgeInsets.zero),
                ),
                PopupMenuItem(
                  value: 'sort_date',
                  child: ListTile(leading: const Icon(Icons.calendar_today_outlined), title: Text(context.l10n.filesModified), contentPadding: EdgeInsets.zero),
                ),
                PopupMenuItem(
                  value: 'sort_size',
                  child: ListTile(leading: const Icon(Icons.straighten), title: Text(context.l10n.filesSize), contentPadding: EdgeInsets.zero),
                ),
                PopupMenuItem(
                  value: 'sort_dir',
                  child: ListTile(
                    leading: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
                    title: Text(_ascending ? context.l10n.filesFlutterAscending : context.l10n.filesFlutterDescending),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            ]),
        ],
      ),
      // Ionic 4.19.1: footer of the selection – move / delete together.
      bottomNavigationBar: _selectionMode
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TextButton.icon(
                      onPressed: _selectedPaths.isEmpty ? null : _moveSelected,
                      icon: const Icon(Icons.swap_horiz),
                      label: IonButtonLabel(context.l10n.filesMove),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: _selectedPaths.isEmpty ? null : _deleteSelected,
                      icon: const Icon(Icons.delete_outline),
                      label: IonButtonLabel(context.l10n.commonDelete),
                    ),
                  ],
                ),
              ),
            )
          : null,
      // IOS_PAGES3: Ionic has no FAB in either mode – upload lives in the
      // toolbar menu (⋮ → Hochladen).
      body: isRoleLoading
          ? const Center(child: AppSpinner())
          : !canAccess
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingL),
                    child: Text(context.l10n.filesNoAccess, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator.adaptive(
                  onRefresh: _loadEntries,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: 16, fabRoom: 64)),
                    children: [
                      _buildBreadcrumbs(),
                      if (canEdit && _usedBytes != null) _buildStorageUsage(),
                      _buildSearch(),
                      ..._buildList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBreadcrumbs() {
    final segments = _pathSegments;
    // IOS_PAGES3: same breadcrumbs in md mode (files.page.scss is mode-free).
    // Ionic .breadcrumbs-container: medium crumbs (0.88rem/500), the
    // active (last) one in primary, chevron separators.
    Widget crumb(String label, String path, bool active) => GestureDetector(
          onTap: () => _navigateTo(path),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: active ? AppColors.primary : AppColors.medium,
              ),
            ),
          ),
        );
    final crumbs = <Widget>[crumb(context.l10n.filesRoot, '', segments.isEmpty)];
    for (var i = 0; i < segments.length; i++) {
      crumbs.add(Icon(
          ionIsIos(context) ? CupertinoIcons.chevron_forward : Icons.chevron_right,
          size: ionIsIos(context) ? 14 : 18,
          color: AppColors.medium));
      crumbs.add(crumb(
        segments[i],
        segments.sublist(0, i + 1).join('/'),
        i == segments.length - 1,
      ));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Row(children: crumbs),
    );
  }

  Widget _buildStorageUsage() {
    final max = _maxBytes;
    final used = _usedBytes ?? 0;
    final text = max != null
        ? context.l10n.filesStorageUsedOf(formatFileSize(used), formatFileSize(max))
        : context.l10n.filesStorageUsed(formatFileSize(used));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$text$_storageStatusLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.medium)),
          if (max != null && max > 0) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: (used / max).clamp(0.0, 1.0),
              color: used >= max * 0.9 ? AppColors.danger : AppColors.primary,
            ),
          ],
          if (_isStorageAlmostFull)
            TextButton.icon(
              onPressed: _requestMoreStorage,
              icon: const Icon(Icons.add_circle_outline),
              label: IonButtonLabel(context.l10n.filesRequestMore),
            ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    // PARITY_R9: Ionic `.search-row` – the searchbar (host padding 8 on
    // both platforms: iOS ios27 glass, md white with shadow) next to the
    // help button; "Suche zurücksetzen" below while a term is entered.
    final ios = ionIsIos(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: IonSearchbar(
                controller: _searchController,
                hint: context.l10n.filesSearchPlaceholder,
                onChanged: (_) {},
                padding: ios ? const EdgeInsets.all(8) : IonMd.searchbarPadding,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: ios ? 8 : 4),
              child: Builder(
                builder: (button) => IconButton(
                  icon: Icon(ios ? CupertinoIcons.question_circle : Icons.help_outline,
                      color: AppColors.medium, semanticLabel: context.l10n.a11yHelp),
                  onPressed: () => _showSearchHelp(button),
                ),
              ),
            ),
          ],
        ),
        if (_hasSearchTerm)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton(onPressed: _searchController.clear, child: IonButtonLabel(context.l10n.filesResetSearch)),
          ),
      ],
    );
  }

  List<Widget> _buildList() {
    if (_isLoading && _entries.isEmpty) {
      return const [Padding(padding: EdgeInsets.all(32), child: Center(child: AppSpinner()))];
    }
    if (_entries.isEmpty) {
      return [_EmptyCard(icon: Icons.folder_open_outlined, text: context.l10n.filesFolderEmpty)];
    }
    final filtered = _filteredEntries;
    if (filtered.isEmpty) {
      return [_EmptyCard(icon: Icons.search, text: context.l10n.filesNoHits(_searchController.text))];
    }
    if (ionIsIos(context)) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: IonInsetGroup(
            dividerIndent: IonIos.iconDividerIndent,
            children: [for (final e in filtered) _buildEntryTile(e)],
          ),
        ),
      ];
    }
    return [
      Card(
        margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
        child: Column(
          children: [
            for (var i = 0; i < filtered.length; i++) ...[
              _buildEntryTile(filtered[i]),
              if (i < filtered.length - 1) const Divider(height: 1, indent: 72),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _buildEntryTile(StorageEntry entry) {
    final preview = _imagePreviewUrls[entry.path];
    final ios = ionIsIos(context);
    Widget leading;
    if (preview != null) {
      // ion-thumbnail.file-thumb: 38px, radius 6
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(ios ? 6 : 4),
        child: Image.network(
          preview,
          width: ios ? 38 : 40,
          height: ios ? 38 : 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined),
        ),
      );
    } else {
      // IOS_PAGES3: Ionic folder-outline / document-outline for every
      // entry; md start icons in the 54 % text colour, no primary tint.
      leading = Icon(
        entry.isFolder ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
        color: ios
            ? null
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
      );
    }

    String? subtitle;
    if (!entry.isFolder && entry.size != null) {
      subtitle = formatFileSize(entry.size);
      if (entry.updatedAt != null) {
        subtitle += ' ${context.l10n.filesChangedAt(FilesSearch.formatUpdatedAt(entry.updatedAt))}';
      }
    }

    final Widget leadingBox = ios
        ? (preview != null ? leading : SizedBox(width: IonIos.itemIconSize, child: Center(child: leading)))
        : SizedBox(width: 40, height: 40, child: Center(child: leading));
    final selected = _selectionMode && _selectedPaths.contains(entry.path);

    return ListTile(
      // Ionic 4.19.1: checkbox in front while selecting, row tinted.
      leading: _selectionMode
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              ExcludeSemantics(
                child: IgnorePointer(
                  child: Checkbox(value: selected, onChanged: (_) {}),
                ),
              ),
              const SizedBox(width: 4),
              leadingBox,
            ])
          : leadingBox,
      title: Text(entry.name),
      subtitle: subtitle != null ? Text(subtitle) : null,
      tileColor: selected ? AppColors.primary.withValues(alpha: 0.1) : null,
      onTap: () => _selectionMode ? _toggleSelection(entry) : _openEntry(entry),
      trailing: _selectionMode
          ? null
          : Builder(
              builder: (button) => IconButton(
                icon: Icon(Icons.more_horiz, color: AppColors.medium, semanticLabel: context.l10n.a11yMoreActions),
                onPressed: () => _showEntryActions(button, entry),
              ),
            ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    if (ios) {
      // IOS_FORMS2: Ionic iOS ion-card here renders flat (no shadow) with
      // the message in the text colour at 17pt.
      // PARITY_R9: ios27 `ion-card-content` – padding 16 20, 1rem (17pt)
      // text with line-height 1.29 (`p { font-size: inherit }`).
      return Container(
        key: const ValueKey('files-empty-card'),
        width: double.infinity,
        margin: const EdgeInsets.all(AppDimensions.paddingM),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: IonIos.itemBackground(context),
          borderRadius: BorderRadius.circular(IonIos.groupRadius),
        ),
        child: Column(
          children: [
            // PARITY_R7: Ionic `folder-open-outline` at 48px draws a ≈36pt
            // outline folder; the Material glyph fills more of its box.
            Icon(
              icon == Icons.folder_open_outlined ? CupertinoIcons.folder_open : icon,
              size: 44,
              color: IonIos.text(context).withValues(alpha: 0.6),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17, height: 1.29, color: IonIos.text(context)),
            ),
          ],
        ),
      );
    }
    return IonCardBox(
      margin: const EdgeInsets.all(AppDimensions.paddingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: ios
                  ? IonIos.text(context).withValues(alpha: 0.6)
                  : AppColors.medium,
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
