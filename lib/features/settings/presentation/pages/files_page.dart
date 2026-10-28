import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/feedback_providers.dart';
import '../../../../core/providers/files_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/audio_player/audio_player_service.dart';
import '../../../../core/services/telegram_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/storage/storage_entry.dart';
import '../../../../data/repositories/base_repository.dart';
import '../../../../data/repositories/files_repository.dart';
import '../../../../shared/widgets/sheets/image_viewer_sheet.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';

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
      d == null ? '' : DateFormat('dd.MM.yyyy, HH:mm').format(d);

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
  bool get _canEdit => ref.read(canEditFilesProvider);
  int? get _maxBytes => ref.read(currentTenantProvider)?.filesMaxBytes;

  Future<void> _init() async {
    await _loadEntries();
    final openName = widget.openFileName;
    if (openName == null || openName.isEmpty || !mounted) return;
    final entry = _entries.where((e) => !e.isFolder && e.name == openName).firstOrNull;
    if (entry == null) {
      ToastHelper.showWarning(context, 'Die verlinkte Datei wurde nicht gefunden.');
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
      return e.message;
    }
    return '$e';
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
    return (_usedBytes ?? 0) >= (_maxBytes ?? 0) ? ' · voll' : ' · fast voll';
  }

  String get _sortLabel {
    final dir = _ascending ? 'aufsteigend' : 'absteigend';
    switch (_sortBy) {
      case FilesSortBy.updatedAt:
        return 'Datum ($dir)';
      case FilesSortBy.size:
        return 'Größe ($dir)';
      case FilesSortBy.name:
        return 'Name (${_ascending ? 'A-Z' : 'Z-A'})';
    }
  }

  Future<void> _loadEntries() async {
    final repo = _repo;
    if (!repo.hasTenantId) return;
    setState(() => _isLoading = true);
    try {
      final loaded = await repo.listEntries(_currentPath);
      if (!mounted) return;
      setState(() => _entries = FilesSearch.sort(loaded, _sortBy, _ascending));
      await _loadImagePreviews();
      if (_canEdit) await _loadUsage();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Fehler beim Laden der Dateien: ${_errorText(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUsage() async {
    try {
      final used = await _repo.getUsedBytes();
      if (mounted) setState(() => _usedBytes = used);
    } catch (_) {
      if (mounted) setState(() => _usedBytes = null);
    }
  }

  Future<void> _loadImagePreviews() async {
    _imagePreviewUrls.clear();
    final images = _entries.where(FilesSearch.isImage).toList();
    if (images.isEmpty) return;
    final results = await Future.wait(images.map((e) async {
      try {
        return MapEntry(e.path, await _repo.getSignedFileUrl(e.path, expiresInSeconds: 3600));
      } catch (_) {
        return MapEntry(e.path, '');
      }
    }));
    if (!mounted) return;
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
    var url = _imagePreviewUrls[entry.path];
    if (url == null) {
      try {
        url = await _repo.getSignedFileUrl(entry.path, expiresInSeconds: 3600);
        _imagePreviewUrls[entry.path] = url;
      } catch (e) {
        if (mounted) ToastHelper.showError(context, 'Bildvorschau fehlgeschlagen: ${_errorText(e)}');
        return;
      }
    }
    if (!mounted) return;
    await showImageViewerSheet(context, url: url, fileName: entry.name);
  }

  /// INTEGRATION: plays all audio files of the folder as a queue, starting at
  /// the tapped one (Ionic playAudioEntry / AudioPlayerService.playQueue).
  Future<void> _playAudio(StorageEntry entry) async {
    final audioEntries = _filteredEntries.where(FilesSearch.isAudio).toList();
    final list = audioEntries.isEmpty ? [entry] : audioEntries;
    final startIndex = list.indexWhere((e) => e.path == entry.path).clamp(0, list.length - 1);
    final queue = [
      for (final e in list)
        AudioQueueItem(
          fileName: e.name,
          title: e.name,
          resolveUrl: () => _repo.getSignedFileUrl(e.path, expiresInSeconds: 3600),
        ),
    ];
    try {
      await ref.read(audioPlayerServiceProvider.notifier).playQueue(queue, startIndex);
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Fehler beim Abspielen: ${_errorText(e)}');
    }
  }

  String? get _telegramChatId =>
      ref.read(currentTenantUserProvider).valueOrNull?.telegramChatId;

  /// INTEGRATION: sends the file to the user's Telegram chat
  /// (Ionic sendEntryPerTelegram, Edge Function `send-document`).
  Future<void> _sendEntryPerTelegram(StorageEntry entry) async {
    if (entry.isFolder) return;
    final chatId = _telegramChatId;
    if (chatId == null || chatId.isEmpty) {
      ToastHelper.showWarning(context, 'Bitte verbinde zuerst Telegram in den Benachrichtigungen.');
      return;
    }
    ToastHelper.showInfo(context, 'Datei wird per Telegram gesendet...');
    try {
      final url = await _repo.getSignedFileUrl(entry.path, expiresInSeconds: 600);
      await ref.read(telegramServiceProvider).sendDocumentPerTelegram(url: url, chatId: chatId);
      if (mounted) ToastHelper.showSuccess(context, 'Nachricht wurde erfolgreich gesendet!');
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Telegram-Versand fehlgeschlagen: ${_errorText(e)}');
    }
  }

  Future<void> _downloadEntry(StorageEntry entry) async {
    if (entry.isFolder) return;
    try {
      final url = await _repo.getSignedFileUrl(entry.path, downloadName: entry.name);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('Link konnte nicht geöffnet werden');
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Download fehlgeschlagen: ${_errorText(e)}');
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

  Future<void> _shareEntry([StorageEntry? entry]) async {
    final url = _shareLink(entry?.path ?? _currentPath, entry?.isFolder ?? true);
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) ToastHelper.showSuccess(context, 'Link in Zwischenablage kopiert');
    } catch (_) {
      try {
        await Share.share(url);
      } catch (_) {
        if (mounted) ToastHelper.showInfo(context, 'Link: $url');
      }
    }
  }

  Future<void> _createFolder() async {
    if (!_canEdit) {
      ToastHelper.showWarning(context, 'Du darfst Dateien nicht bearbeiten.');
      return;
    }
    final name = await DialogHelper.showTextInput(
      context,
      title: 'Ordner erstellen',
      hint: 'Ordnername',
      confirmText: 'Erstellen',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      await _repo.createFolder(_currentPath, name);
      if (mounted) ToastHelper.showSuccess(context, 'Ordner wurde erstellt.');
      await _loadEntries();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Ordner konnte nicht erstellt werden: ${_errorText(e)}');
    }
  }

  Future<void> _renameEntry(StorageEntry entry) async {
    final name = await DialogHelper.showTextInput(
      context,
      title: entry.isFolder ? 'Ordner umbenennen' : 'Datei umbenennen',
      initialValue: entry.name,
      hint: 'Neuer Name',
      confirmText: 'Speichern',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      await _repo.renameEntry(entry.path, name, isFolder: entry.isFolder);
      if (mounted) ToastHelper.showSuccess(context, 'Eintrag wurde umbenannt.');
      await _loadEntries();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Umbenennen fehlgeschlagen: ${_errorText(e)}');
    }
  }

  Future<void> _moveEntry(StorageEntry entry) async {
    final controller = TextEditingController();
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verschieben'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Zielordner relativ zum Tenant-Root. Leer lassen für Root.'),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'z. B. Dokumente/2026'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Verschieben')),
        ],
      ),
    );
    controller.dispose();
    if (target == null || !mounted) return;
    try {
      await _repo.moveEntry(entry.path, target, isFolder: entry.isFolder);
      if (mounted) ToastHelper.showSuccess(context, 'Eintrag wurde verschoben.');
      await _loadEntries();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Verschieben fehlgeschlagen: ${_errorText(e)}');
    }
  }

  Future<void> _deleteEntry(StorageEntry entry) async {
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: entry.isFolder ? 'Ordner löschen?' : 'Datei löschen?',
      message: 'Möchtest du ${entry.name} wirklich löschen?',
      confirmText: 'Löschen',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _repo.deleteEntry(entry.path, isFolder: entry.isFolder);
      if (mounted) ToastHelper.showSuccess(context, 'Eintrag wurde gelöscht.');
      await _loadEntries();
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Löschen fehlgeschlagen: ${_errorText(e)}');
    }
  }

  Future<void> _requestMoreStorage() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mehr Speicher anfragen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Die Anfrage geht an den Attendix-Admin. Er meldet sich bei dir.'),
            const SizedBox(height: AppDimensions.paddingS),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Wie viel Speicher braucht ihr ungefähr? (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Senden')),
        ],
      ),
    );
    controller.dispose();
    if (note == null || !mounted) return;

    final tenant = ref.read(currentTenantProvider);
    final max = _maxBytes;
    final usage = max != null
        ? '${formatFileSize(_usedBytes ?? 0)} von ${formatFileSize(max)}'
        : formatFileSize(_usedBytes ?? 0);
    final message = [
      'Anfrage: Mehr Speicher für die Dateiablage',
      'Instanz: ${tenant?.longName} (ID ${tenant?.id})',
      'Belegt: $usage',
      if (note.trim().isNotEmpty) 'Nachricht: ${note.trim()}',
    ].join('\n');

    final ok = await ref.read(feedbackNotifierProvider.notifier).sendQuestion(message: message);
    if (!mounted) return;
    if (ok) {
      ToastHelper.showSuccess(context, 'Deine Anfrage wurde gesendet. Wir melden uns so schnell wie möglich.');
    } else {
      final error = ref.read(feedbackNotifierProvider).error;
      ToastHelper.showError(context, 'Fehler beim Senden der Anfrage: ${error ?? ''}');
    }
  }

  /// Fragt bei Duplikaten nach: 'overwrite' | 'skip' | null (Abbrechen)
  Future<String?> _askDuplicateHandling(List<String> names) {
    final preview = names.take(5).join(', ');
    final suffix = names.length > 5 ? ' und ${names.length - 5} weitere' : '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datei existiert bereits'),
        content: Text('Folgende Datei(en) existieren bereits: $preview$suffix. Möchtest du diese überschreiben?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'skip'), child: const Text('Überspringen')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, 'overwrite'), child: const Text('Überschreiben')),
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

    final request = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Speicher voll'),
        content: Text(
          'Für diesen Upload werden ${formatFileSize(needed)} benötigt, frei sind noch '
          '${formatFileSize(free)} von ${formatFileSize(max)}. Lösche nicht mehr benötigte '
          'Dateien oder frage mehr Speicher an.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('OK')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mehr Speicher anfragen')),
        ],
      ),
    );
    if (request == true && mounted) await _requestMoreStorage();
    return false;
  }

  Future<void> _upload() async {
    if (!_canEdit) {
      ToastHelper.showWarning(context, 'Du darfst Dateien nicht bearbeiten.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result == null || result.files.isEmpty || !mounted) return;
    final files = result.files.where((f) => f.bytes != null).toList();
    if (files.isEmpty) return;

    final existing = _entries.where((e) => !e.isFolder).map((e) => e.name).toSet();
    final names = {for (final f in files) f: FilesRepository.sanitizeFileName(f.name)};
    final duplicates = names.values.where(existing.contains).toSet();

    var overwrite = false;
    if (duplicates.isNotEmpty) {
      final handling = await _askDuplicateHandling(duplicates.toList());
      if (handling == null) return;
      overwrite = handling == 'overwrite';
    }
    if (!await _hasEnoughSpace(files, names, duplicates, overwrite) || !mounted) return;

    final progress = ValueNotifier<String>('Upload 0/${files.length} (0%)');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
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
      final base = 'Upload $processed/${files.length} ($percent%)';
      return name != null ? '$base\n$name' : base;
    }

    for (final f in files) {
      final name = names[f]!;
      final isDuplicate = duplicates.contains(name);
      progress.value = progressText(name);
      if (isDuplicate && !overwrite) {
        skipped++;
        processed++;
        continue;
      }
      try {
        await _repo.uploadFile(_currentPath, f.name, f.bytes!, overwrite: isDuplicate && overwrite);
        ref.read(trackingServiceProvider).track(TrackingEvent.fileUploaded, properties: {'size': f.size, 'mime': null});
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
      ToastHelper.showSuccess(context, success == 1 ? 'Datei wurde hochgeladen.' : '$success Dateien wurden hochgeladen.');
    } else if (success > 0 || failed > 0 || skipped > 0) {
      ToastHelper.showWarning(context, '$success hochgeladen, $skipped übersprungen, $failed fehlgeschlagen.');
    } else {
      ToastHelper.showInfo(context, 'Keine Datei hochgeladen.');
    }
    await _loadEntries();
  }

  void _showSearchHelp() {
    DialogHelper.showAlert(
      context,
      title: 'Suche',
      message: 'Freitext durchsucht den Dateinamen/Ordnernamen.\n\n'
          'typ:<wert> · Filtert nach Dateityp oder Art (z. B. typ:pdf, typ:ordner, typ:datei).\n\n'
          'datum:<wert> · Filtert nach Änderungsdatum (z. B. datum:2026, datum:03.2026, datum:03.03.2026).\n\n'
          'Filter sind kombinierbar, z. B. protokoll typ:pdf datum:2026.',
    );
  }

  void _showEntryActions(StorageEntry entry) {
    final canEdit = _canEdit;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(FilesSearch.isAudio(entry) ? Icons.play_circle_outline : Icons.open_in_new),
              title: Text(entry.isFolder
                  ? 'Ordner öffnen'
                  : FilesSearch.isAudio(entry)
                      ? 'Aufnahme abspielen'
                      : 'Datei öffnen/downloaden'),
              onTap: () {
                Navigator.pop(ctx);
                _openEntry(entry);
              },
            ),
            if (!entry.isFolder)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Datei herunterladen'),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadEntry(entry);
                },
              ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Link teilen'),
              onTap: () {
                Navigator.pop(ctx);
                _shareEntry(entry);
              },
            ),
            // INTEGRATION: Ionic files "Per Telegram senden"
            if (!entry.isFolder && (_telegramChatId?.isNotEmpty ?? false))
              ListTile(
                leading: const Icon(Icons.send_outlined),
                title: const Text('Per Telegram senden'),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendEntryPerTelegram(entry);
                },
              ),
            if (canEdit) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Umbenennen'),
                onTap: () {
                  Navigator.pop(ctx);
                  _renameEntry(entry);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Verschieben'),
                onTap: () {
                  Navigator.pop(ctx);
                  _moveEntry(entry);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Löschen', style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteEntry(entry);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'upload':
        _upload();
      case 'folder':
        _createFolder();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dateien'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
        ),
        actions: [
          if (canAccess)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: _onMenuSelected,
              itemBuilder: (_) => [
                if (canEdit) ...[
                  const PopupMenuItem(
                    value: 'upload',
                    child: ListTile(leading: Icon(Icons.cloud_upload_outlined), title: Text('Dateien hochladen'), contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem(
                    value: 'folder',
                    child: ListTile(leading: Icon(Icons.create_new_folder_outlined), title: Text('Ordner erstellen'), contentPadding: EdgeInsets.zero),
                  ),
                ],
                PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: const Icon(Icons.share_outlined),
                    title: Text(_currentPath.isNotEmpty ? 'Link zu diesem Ordner teilen' : 'Link zur Dateiablage teilen'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  enabled: false,
                  child: ListTile(title: const Text('Sortierung'), subtitle: Text(_sortLabel), contentPadding: EdgeInsets.zero),
                ),
                const PopupMenuItem(
                  value: 'sort_name',
                  child: ListTile(leading: Icon(Icons.text_fields), title: Text('Name'), contentPadding: EdgeInsets.zero),
                ),
                const PopupMenuItem(
                  value: 'sort_date',
                  child: ListTile(leading: Icon(Icons.calendar_today_outlined), title: Text('Änderungsdatum'), contentPadding: EdgeInsets.zero),
                ),
                const PopupMenuItem(
                  value: 'sort_size',
                  child: ListTile(leading: Icon(Icons.straighten), title: Text('Dateigröße'), contentPadding: EdgeInsets.zero),
                ),
                PopupMenuItem(
                  value: 'sort_dir',
                  child: ListTile(
                    leading: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
                    title: Text(_ascending ? 'Aufsteigend' : 'Absteigend'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: canAccess && canEdit
          ? FloatingActionButton(
              onPressed: _upload,
              tooltip: 'Dateien hochladen',
              child: const Icon(Icons.cloud_upload_outlined),
            )
          : null,
      body: isRoleLoading
          ? const Center(child: CircularProgressIndicator())
          : !canAccess
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.paddingL),
                    child: Text('Du hast keinen Zugriff auf Dateien.', textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadEntries,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 80),
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
    final chips = <Widget>[
      TextButton(onPressed: () => _navigateTo(''), child: const Text('Root')),
    ];
    for (var i = 0; i < segments.length; i++) {
      chips.add(const Icon(Icons.chevron_right, size: 18, color: AppColors.medium));
      chips.add(TextButton(
        onPressed: () => _navigateTo(segments.sublist(0, i + 1).join('/')),
        child: Text(segments[i]),
      ));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS),
      child: Row(children: chips),
    );
  }

  Widget _buildStorageUsage() {
    final max = _maxBytes;
    final used = _usedBytes ?? 0;
    final text = max != null
        ? 'Speicher: ${formatFileSize(used)} von ${formatFileSize(max)} belegt'
        : 'Speicher: ${formatFileSize(used)} belegt';
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
              label: const Text('Mehr Speicher anfragen'),
            ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Dateien & Ordner suchen...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _hasSearchTerm
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: _searchController.clear)
                        : null,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.help_outline, color: AppColors.medium),
                onPressed: _showSearchHelp,
              ),
            ],
          ),
          if (_hasSearchTerm)
            TextButton(onPressed: _searchController.clear, child: const Text('Suche zurücksetzen')),
        ],
      ),
    );
  }

  List<Widget> _buildList() {
    if (_isLoading && _entries.isEmpty) {
      return const [Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))];
    }
    if (_entries.isEmpty) {
      return const [_EmptyCard(icon: Icons.folder_open_outlined, text: 'Dieser Ordner ist leer.')];
    }
    final filtered = _filteredEntries;
    if (filtered.isEmpty) {
      return [_EmptyCard(icon: Icons.search, text: 'Keine Treffer für „${_searchController.text}“.')];
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
    Widget leading;
    if (preview != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          preview,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined),
        ),
      );
    } else {
      leading = Icon(
        entry.isFolder
            ? Icons.folder_outlined
            : FilesSearch.isAudio(entry)
                ? Icons.audiotrack_outlined
                : Icons.description_outlined,
        color: entry.isFolder ? AppColors.primary : null,
      );
    }

    String? subtitle;
    if (!entry.isFolder && entry.size != null) {
      subtitle = formatFileSize(entry.size);
      if (entry.updatedAt != null) {
        subtitle += ' · Geändert: ${FilesSearch.formatUpdatedAt(entry.updatedAt)}';
      }
    }

    return ListTile(
      leading: SizedBox(width: 40, height: 40, child: Center(child: leading)),
      title: Text(entry.name),
      subtitle: subtitle != null ? Text(subtitle) : null,
      onTap: () => _openEntry(entry),
      trailing: IconButton(
        icon: const Icon(Icons.more_horiz, color: AppColors.medium),
        onPressed: () => _showEntryActions(entry),
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
    return Card(
      margin: const EdgeInsets.all(AppDimensions.paddingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.medium),
            const SizedBox(height: AppDimensions.paddingS),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
