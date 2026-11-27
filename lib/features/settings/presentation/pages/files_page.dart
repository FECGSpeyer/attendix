import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../../../core/utils/file_mime.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/adaptive/ion_loading.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/router/route_access.dart' show canOpenSongsTab;
import '../../../../core/providers/debug_providers.dart' show effectiveRoleProvider;
import '../../../../core/theme/design_theme.dart';
import '../widgets/manage/settings_sheets.dart';
import '../../../../shared/widgets/components/components.dart';
import '../../../today/presentation/widgets/today_common.dart' show RdInfoCard;

part 'files_page_view.dart';
part 'files_page_actions.dart';

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
  void _update(VoidCallback fn) => setState(fn);

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

  Future<String?> _askText({required String title, String initial = '', String? hint, String? confirmText}) =>
      showRdTextSheet(context, title: title, initial: initial, hint: hint, capitalization: TextCapitalization.none);

  Future<bool> _confirm({required String title, required String message, required String confirmText}) =>
      showAppConfirm(context, title: title, message: message, confirmText: confirmText, destructive: true);
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
    return _buildView(context, canAccess: canAccess, isRoleLoading: isRoleLoading, canEdit: canEdit);
  }
}

String _errorText(Object e) {
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
