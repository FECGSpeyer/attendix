import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/storage/storage_entry.dart';
import 'base_repository.dart';
import '../../l10n/l10n.dart';

/// Provider for FilesRepository (ohne Tenant – nutze filesRepositoryWithTenantProvider)
final filesRepositoryProvider = Provider<FilesRepository>((ref) {
  return FilesRepository(ref);
});

/// Repository für die Dateiablage (Supabase Storage Bucket `files`).
///
/// Multi-Tenant: Jeder Objekt-Key beginnt mit `<tenantId>/`. Der Präfix wird
/// IMMER aus [currentTenantId] gebildet (nie vom Aufrufer übergeben), sodass
/// kein Zugriff auf fremde Instanzen möglich ist. Zusätzlich prüfen die
/// Storage-RLS-Policies (files_bucket_policies.sql) die Rolle in der Instanz.
class FilesRepository extends BaseRepository with TenantAwareRepository {
  FilesRepository(super.ref);

  static const String bucket = 'files';

  StorageFileApi get _storage => supabase.storage.from(bucket);

  // ---------------------------------------------------------------------------
  // Pfad-Helfer (pure, testbar)
  // ---------------------------------------------------------------------------

  /// Backslashes → `/`, doppelte Slashes entfernen, führende/abschließende Slashes trimmen.
  static String normalizeRelativePath(String? path) {
    return (path ?? '')
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+'), '/')
        .replaceAll(RegExp(r'^/+|/+$'), '')
        .trim();
  }

  /// Verhindert Pfad-Traversal (`..`) in relativen Pfaden.
  static String _safeRelativePath(String? path) {
    final normalized = normalizeRelativePath(path);
    final parts = normalized
        .split('/')
        .where((p) => p.isNotEmpty && p != '.' && p != '..')
        .toList();
    return parts.join('/');
  }

  static String toRelativePath(String base, String name) {
    final normalizedBase = normalizeRelativePath(base);
    return normalizedBase.isNotEmpty ? '$normalizedBase/$name' : name;
  }

  static String nameFromPath(String path) {
    final parts = normalizeRelativePath(path).split('/').where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? '' : parts.last;
  }

  static String parentPath(String path) {
    final parts = normalizeRelativePath(path).split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isNotEmpty) parts.removeLast();
    return parts.join('/');
  }

  /// Objekt-Key inkl. Tenant-Präfix. Tenant kommt immer aus [currentTenantId].
  String tenantPrefix([String relativePath = '']) {
    final normalized = _safeRelativePath(relativePath);
    return normalized.isNotEmpty ? '$currentTenantId/$normalized' : '$currentTenantId';
  }

  static const Map<String, String> _cyrillicMap = {
    'А': 'A', 'а': 'a', 'Б': 'B', 'б': 'b', 'В': 'V', 'в': 'v', 'Г': 'G', 'г': 'g', 'Д': 'D', 'д': 'd',
    'Е': 'E', 'е': 'e', 'Ё': 'Yo', 'ё': 'yo', 'Ж': 'Zh', 'ж': 'zh', 'З': 'Z', 'з': 'z', 'И': 'I', 'и': 'i',
    'Й': 'Y', 'й': 'y', 'К': 'K', 'к': 'k', 'Л': 'L', 'л': 'l', 'М': 'M', 'м': 'm', 'Н': 'N', 'н': 'n',
    'О': 'O', 'о': 'o', 'П': 'P', 'п': 'p', 'Р': 'R', 'р': 'r', 'С': 'S', 'с': 's', 'Т': 'T', 'т': 't',
    'У': 'U', 'у': 'u', 'Ф': 'F', 'ф': 'f', 'Х': 'Kh', 'х': 'kh', 'Ц': 'Ts', 'ц': 'ts', 'Ч': 'Ch', 'ч': 'ch',
    'Ш': 'Sh', 'ш': 'sh', 'Щ': 'Sch', 'щ': 'sch', 'Ъ': '', 'ъ': '', 'Ы': 'Y', 'ы': 'y', 'Ь': '', 'ь': '',
    'Э': 'E', 'э': 'e', 'Ю': 'Yu', 'ю': 'yu', 'Я': 'Ya', 'я': 'ya',
    'І': 'I', 'і': 'i', 'Ї': 'Yi', 'ї': 'yi', 'Є': 'Ye', 'є': 'ye', 'Ґ': 'G', 'ґ': 'g',
  };

  static const Map<String, String> _diacritics = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'å': 'a', 'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Å': 'A',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'Ù': 'U', 'Ú': 'U', 'Û': 'U',
    'ç': 'c', 'Ç': 'C', 'ñ': 'n', 'Ñ': 'N', 'ý': 'y', 'ÿ': 'y', 'Ý': 'Y',
    'š': 's', 'Š': 'S', 'ž': 'z', 'Ž': 'Z', 'č': 'c', 'Č': 'C', 'ř': 'r', 'Ř': 'R',
  };

  static String _transliterate(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_cyrillicMap[char] ?? _diacritics[char] ?? char);
    }
    return buffer.toString();
  }

  static String _replaceGermanChars(String value) {
    return value
        .replaceAll('Ä', 'Ae')
        .replaceAll('Ö', 'Oe')
        .replaceAll('Ü', 'Ue')
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');
  }

  static String _avoidWindowsReservedName(String value) {
    if (value.isEmpty) return value;
    if (RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$', caseSensitive: false).hasMatch(value)) {
      return '$value-file';
    }
    return value;
  }

  static String _sanitizeExtension(String ext) {
    return _transliterate(_replaceGermanChars(ext))
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '')
        .toLowerCase();
  }

  /// Bereinigt einen Ordner-/Dateinamen-Teil (wie FilesService.sanitizeSegment in Ionic).
  static String sanitizeSegment(String name) {
    var s = _transliterate(_replaceGermanChars(name));
    s = s
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '')
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
        .replaceAll('&', ' und ')
        .replaceAll('@', ' at ')
        .replaceAll(RegExp('[’‘`´]'), "'")
        .replaceAll(RegExp(r'[_\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*-\s*'), '-')
        .replaceAll(RegExp(r'\.{2,}'), '.')
        .replaceAll(RegExp(r"[^a-zA-Z0-9 ._'()-]"), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .replaceAll(RegExp(r'^[.\s-]+|[.\s-]+$'), '')
        .trim();
    return _avoidWindowsReservedName(s);
  }

  /// Bereinigt einen Dateinamen inkl. Endung.
  static String sanitizeFileName(String name) {
    final normalizedName = name.replaceAll(RegExp(r'[\\/]+'), ' ').trim();
    final lastDot = normalizedName.lastIndexOf('.');
    final hasExtension = lastDot > 0;
    final rawBase = hasExtension ? normalizedName.substring(0, lastDot) : normalizedName;
    final rawExt = hasExtension ? normalizedName.substring(lastDot + 1) : '';

    final ext = _sanitizeExtension(rawExt);
    final base = sanitizeSegment(rawBase);

    if (base.isEmpty) return ext.isNotEmpty ? 'file.$ext' : 'file';
    return ext.isNotEmpty ? '$base.$ext' : base;
  }

  // ---------------------------------------------------------------------------
  // Storage-Operationen
  // ---------------------------------------------------------------------------

  /// Page size of a storage listing (Ionic `listRaw`: limit 1000).
  static const int storageListPageSize = 1000;

  /// SOL_FIX16: every entry of one folder level, page by page (offset /
  /// limit, sorted by name like Ionic) until a page is shorter than
  /// [pageSize]. Ionic stops after the first 1000 entries, so recursive
  /// delete / move / rename of a large folder handled only part of it and
  /// still reported success. A failing page throws – callers list
  /// everything before they change anything, so a failed listing never
  /// leaves a half-done operation behind that looks complete.
  @visibleForTesting
  static Future<List<FileObject>> listAllPages(
    Future<List<FileObject>> Function(SearchOptions options) listPage, {
    int pageSize = storageListPageSize,
  }) async {
    assert(pageSize > 0);
    final all = <FileObject>[];
    String? previousFirst;
    for (var offset = 0;; offset += pageSize) {
      final page = await listPage(SearchOptions(
        limit: pageSize,
        offset: offset,
        sortBy: const SortBy(column: 'name', order: 'asc'),
      ));
      // A server that ignores the offset would return the same page
      // forever: fail instead of looping or listing duplicates.
      if (offset > 0 && page.isNotEmpty && page.first.name == previousFirst) {
        throw StateError('Storage listing ignores the offset');
      }
      previousFirst = page.isEmpty ? null : page.first.name;
      all.addAll(page);
      if (page.length < pageSize) break;
    }
    return all;
  }

  Future<List<FileObject>> _listRaw(String prefix) {
    _assertOwnPrefix(prefix);
    return listAllPages(
      (options) => _storage.list(path: prefix, searchOptions: options),
    );
  }

  static bool _isFolder(FileObject item) => item.metadata == null;

  /// Alle Objekt-Keys unterhalb eines Präfixes (rekursiv). Präfix muss mit
  /// `<currentTenantId>` beginnen.
  Future<List<String>> _collectFileKeysRecursive(String prefix) async {
    _assertOwnPrefix(prefix);
    final items = await _listRaw(prefix);
    final keys = <String>[];
    for (final item in items) {
      if (item.name == '.keep') {
        keys.add('$prefix/.keep');
        continue;
      }
      if (_isFolder(item)) {
        keys.addAll(await _collectFileKeysRecursive('$prefix/${item.name}'));
      } else {
        keys.add('$prefix/${item.name}');
      }
    }
    return keys;
  }

  void _assertOwnPrefix(String key) {
    final tenantRoot = '$currentTenantId';
    if (key != tenantRoot && !key.startsWith('$tenantRoot/')) {
      throw RepositoryException(
        message: l10nWithoutContext.coreFlutterRepoForeignTenantDenied,
        operation: 'assertOwnPrefix',
      );
    }
  }

  Future<void> _removeKeys(List<String> keys) async {
    for (var i = 0; i < keys.length; i += 100) {
      final chunk = keys.sublist(i, i + 100 > keys.length ? keys.length : i + 100);
      for (final key in chunk) {
        _assertOwnPrefix(key);
      }
      await _storage.remove(chunk);
    }
  }

  Future<void> _moveKey(String oldKey, String newKey) async {
    _assertOwnPrefix(oldKey);
    _assertOwnPrefix(newKey);
    await _storage.move(oldKey, newKey);
  }

  Future<void> _moveFolder(String sourceRelativePath, String targetRelativePath) async {
    final sourcePrefix = tenantPrefix(sourceRelativePath);
    final targetPrefix = tenantPrefix(targetRelativePath);
    final keys = await _collectFileKeysRecursive(sourcePrefix);
    for (final oldKey in keys) {
      final suffix = oldKey.substring(sourcePrefix.length + 1);
      await _moveKey(oldKey, '$targetPrefix/$suffix');
    }
  }

  /// Einträge eines Ordners (Ordner zuerst, dann alphabetisch). `.keep` wird ausgeblendet.
  Future<List<StorageEntry>> listEntries([String relativePath = '']) async {
    try {
      final safePath = _safeRelativePath(relativePath);
      final items = await _listRaw(tenantPrefix(safePath));
      final entries = items.where((i) => i.name != '.keep').map((item) {
        final isFolder = _isFolder(item);
        final rawSize = item.metadata?['size'];
        final updated = item.updatedAt ?? item.createdAt;
        return StorageEntry(
          name: item.name,
          path: toRelativePath(safePath, item.name),
          isFolder: isFolder,
          size: rawSize is num ? rawSize.toInt() : int.tryParse('${rawSize ?? ''}'),
          updatedAt: updated != null ? DateTime.tryParse(updated)?.toLocal() : null,
        );
      }).toList();
      entries.sort((a, b) {
        if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return entries;
    } catch (e, stack) {
      handleError(e, stack, 'listEntries');
      rethrow;
    }
  }

  /// Legt einen Ordner an (Platzhalter-Datei `.keep`).
  Future<void> createFolder(String currentRelativePath, String folderName) async {
    try {
      final sanitized = sanitizeSegment(folderName);
      if (sanitized.isEmpty) {
        throw RepositoryException(message: l10nWithoutContext.svcInvalidFolderName, operation: 'createFolder');
      }
      final key = '${tenantPrefix(toRelativePath(_safeRelativePath(currentRelativePath), sanitized))}/.keep';
      await _storage.uploadBinary(
        key,
        Uint8List(0),
        fileOptions: const FileOptions(upsert: false, contentType: 'text/plain'),
      );
    } catch (e, stack) {
      handleError(e, stack, 'createFolder');
      rethrow;
    }
  }

  /// Belegung der Dateiablage der aktuellen Instanz in Bytes (RPC files_used_bytes).
  Future<int> getUsedBytes() async {
    try {
      final result = await supabase.rpc('files_used_bytes', params: {'p_tenant_id': currentTenantId});
      if (result is num) return result.toInt();
      return int.tryParse('${result ?? 0}') ?? 0;
    } catch (e, stack) {
      handleError(e, stack, 'getUsedBytes');
      rethrow;
    }
  }

  /// Lädt eine Datei hoch. Gibt den bereinigten Dateinamen zurück.
  Future<String> uploadFile(
    String currentRelativePath,
    String originalName,
    Uint8List bytes, {
    bool overwrite = false,
    String? contentType,
  }) async {
    try {
      final fileName = sanitizeFileName(originalName);
      final key = '${tenantPrefix(_safeRelativePath(currentRelativePath))}/$fileName';
      await _storage.uploadBinary(
        key,
        bytes,
        fileOptions: FileOptions(upsert: overwrite, contentType: contentType),
      );
      return fileName;
    } catch (e, stack) {
      handleError(e, stack, 'uploadFile');
      rethrow;
    }
  }

  /// Signierte URL für eine Datei. Mit [downloadName] wird ein Download erzwungen.
  Future<String> getSignedFileUrl(String relativePath, {int expiresInSeconds = 600, String? downloadName}) async {
    try {
      final key = tenantPrefix(relativePath);
      final url = await _storage.createSignedUrl(key, expiresInSeconds);
      if (downloadName == null) return url;
      final separator = url.contains('?') ? '&' : '?';
      return '$url${separator}download=${Uri.encodeQueryComponent(downloadName)}';
    } catch (e, stack) {
      handleError(e, stack, 'getSignedFileUrl');
      rethrow;
    }
  }

  /// Datei-Inhalt herunterladen.
  Future<Uint8List> downloadFile(String relativePath) async {
    try {
      return await _storage.download(tenantPrefix(relativePath));
    } catch (e, stack) {
      handleError(e, stack, 'downloadFile');
      rethrow;
    }
  }

  /// Löscht Datei oder Ordner (rekursiv).
  Future<void> deleteEntry(String relativePath, {required bool isFolder}) async {
    try {
      if (_safeRelativePath(relativePath).isEmpty) {
        throw RepositoryException(message: l10nWithoutContext.coreFlutterRepoRootNotDeletable, operation: 'deleteEntry');
      }
      if (isFolder) {
        final keys = await _collectFileKeysRecursive(tenantPrefix(relativePath));
        await _removeKeys(keys);
        return;
      }
      await _removeKeys([tenantPrefix(relativePath)]);
    } catch (e, stack) {
      handleError(e, stack, 'deleteEntry');
      rethrow;
    }
  }

  /// Benennt Datei oder Ordner um.
  Future<void> renameEntry(String relativePath, String newName, {required bool isFolder}) async {
    try {
      final parent = parentPath(relativePath);
      final sanitized = isFolder ? sanitizeSegment(newName) : sanitizeFileName(newName);
      if (sanitized.isEmpty) {
        throw RepositoryException(message: l10nWithoutContext.svcInvalidName, operation: 'renameEntry');
      }
      final target = toRelativePath(parent, sanitized);
      if (normalizeRelativePath(target) == normalizeRelativePath(relativePath)) return;

      if (isFolder) {
        await _moveFolder(relativePath, target);
        return;
      }
      await _moveKey(tenantPrefix(relativePath), tenantPrefix(target));
    } catch (e, stack) {
      handleError(e, stack, 'renameEntry');
      rethrow;
    }
  }

  /// Verschiebt Datei oder Ordner in [targetFolder] (relativ zum Tenant-Root, leer = Root).
  Future<void> moveEntry(String relativePath, String targetFolder, {required bool isFolder}) async {
    try {
      final normalizedTarget = _safeRelativePath(targetFolder);
      final sourceName = nameFromPath(relativePath);
      final target = normalizedTarget.isNotEmpty ? '$normalizedTarget/$sourceName' : sourceName;
      if (normalizeRelativePath(relativePath) == normalizeRelativePath(target)) return;

      if (isFolder) {
        final sourceNormalized = normalizeRelativePath(relativePath);
        if (normalizedTarget == sourceNormalized || normalizedTarget.startsWith('$sourceNormalized/')) {
          throw RepositoryException(
            message: l10nWithoutContext.svcFolderIntoItself,
            operation: 'moveEntry',
          );
        }
        await _moveFolder(relativePath, target);
        return;
      }
      await _moveKey(tenantPrefix(relativePath), tenantPrefix(target));
    } catch (e, stack) {
      handleError(e, stack, 'moveEntry');
      rethrow;
    }
  }
}
