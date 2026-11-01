import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/services/song_file_service.dart';
import 'rd_import_logic.dart';
import 'rd_import_source.dart';

/// REDESIGN: "Noten importieren" from a shared Google Drive folder. The app
/// walks the folder through the `werke-import` Edge Function (the Google API
/// key stays on the server) and has the chosen files copied straight into
/// the song folders, so nothing large passes through the phone.

/// A file or folder in Google Drive. Files shared by link before 2021 also
/// need their resource key.
class RdDriveRef {
  const RdDriveRef(this.id, [this.resourceKey]);

  final String id;
  final String? resourceKey;

  Map<String, dynamic> toJson() => {'id': id, if (resourceKey != null) 'resourceKey': resourceKey};

  @override
  bool operator ==(Object other) => other is RdDriveRef && other.id == id && other.resourceKey == resourceKey;

  @override
  int get hashCode => Object.hash(id, resourceKey);
}

final _driveId = RegExp(r'^[A-Za-z0-9_-]{10,100}$');
final _resourceKey = RegExp(r'^[A-Za-z0-9_-]{1,100}$');

Uri? _uri(String text) {
  var t = text.trim();
  if (t.isEmpty || t.contains(RegExp(r'\s'))) return null;
  if (!t.contains('://')) t = 'https://$t';
  final uri = Uri.tryParse(t);
  return uri == null || uri.host.isEmpty ? null : uri;
}

/// The folder of a Google Drive link (`https://drive.google.com/drive/
/// folders/ID?usp=sharing`, `…/drive/u/0/folders/ID`, `open?id=ID`); null
/// when [text] is no Drive folder link.
RdDriveRef? rdParseDriveLink(String text) {
  final uri = _uri(text);
  if (uri == null || !(uri.host == 'drive.google.com' || uri.host.endsWith('.drive.google.com'))) return null;
  final segments = uri.pathSegments;
  final at = segments.indexOf('folders');
  String? id;
  if (at >= 0 && at + 1 < segments.length) {
    id = segments[at + 1];
  } else if (segments.isNotEmpty && segments.last == 'open') {
    id = uri.queryParameters['id'];
  }
  if (id == null || !_driveId.hasMatch(id)) return null;
  final key = uri.queryParameters['resourcekey'];
  return RdDriveRef(id, key != null && _resourceKey.hasMatch(key) ? key : null);
}

/// Whether [text] is a Google Drive link to something else than a folder
/// (a single file, a document).
bool rdIsDriveLink(String text) {
  final host = _uri(text)?.host ?? '';
  return host == 'drive.google.com' || host == 'docs.google.com' || host.endsWith('.drive.google.com');
}

/// Whether [text] is a Dropbox link.
bool rdIsDropboxLink(String text) {
  final host = _uri(text)?.host ?? '';
  return host == 'dropbox.com' || host.endsWith('.dropbox.com') || host == 'db.tt';
}

/// The folder in Google Drive, to open it after the import (stop sharing).
Uri rdDriveFolderUrl(RdDriveRef folder) => Uri.https(
      'drive.google.com',
      '/drive/folders/${folder.id}',
      folder.resourceKey == null ? null : {'resourcekey': folder.resourceKey},
    );

/// One entry of a Drive folder.
class RdDriveItem {
  const RdDriveItem({
    required this.id,
    required this.name,
    required this.mimeType,
    this.resourceKey,
    this.size = 0,
    this.modified,
    this.md5,
  });

  factory RdDriveItem.fromJson(Map<String, dynamic> json) => RdDriveItem(
        id: json['id'] as String,
        resourceKey: json['resourceKey'] as String?,
        name: (json['name'] as String?) ?? '',
        mimeType: (json['mimeType'] as String?) ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        modified: DateTime.tryParse((json['modifiedTime'] as String?) ?? '')?.toLocal(),
        md5: json['md5'] as String?,
      );

  final String id;
  final String? resourceKey;
  final String name;
  final String mimeType;
  final int size;
  final DateTime? modified;
  final String? md5;

  RdDriveRef get ref => RdDriveRef(id, resourceKey);
  bool get isFolder => mimeType == 'application/vnd.google-apps.folder';
  bool get isShortcut => mimeType == 'application/vnd.google-apps.shortcut';

  /// Google Docs, Sheets …: no file to copy.
  bool get isGoogleFile => mimeType.startsWith('application/vnd.google-apps.') && !isFolder;
}

/// What went wrong with the Drive folder.
enum RdDriveError {
  /// The function or its Google key is missing.
  notSetUp,

  /// Not found or not shared with "Anyone with the link".
  notFound,

  /// The link points to a file, not a folder.
  notFolder,

  /// The day's budget is used up.
  limit,

  /// Google is busy (rate limits).
  busy,

  /// More files than one import can take.
  tooMany,

  /// A file of the song already has this storage name.
  exists,

  /// No permission to edit this group.
  forbidden,
  failed,
}

class RdDriveException implements Exception {
  const RdDriveException(this.error);

  final RdDriveError error;

  @override
  String toString() => 'RdDriveException(${error.name})';
}

/// Calls of the `werke-import` Edge Function.
class RdDriveApi {
  RdDriveApi(this._invoke);

  /// Calls the function on [client].
  factory RdDriveApi.supabase(SupabaseClient client) => RdDriveApi((body) async {
        final response = await client.functions.invoke(function, body: body).timeout(const Duration(seconds: 90));
        return response.data;
      });

  static const function = 'werke-import';

  final Future<dynamic> Function(Map<String, dynamic> body) _invoke;

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    try {
      final data = await _invoke(body);
      if (data is Map<String, dynamic>) return data;
      if (data is String) return jsonDecode(data) as Map<String, dynamic>;
      throw const RdDriveException(RdDriveError.failed);
    } on RdDriveException {
      rethrow;
    } on FunctionException catch (e) {
      throw RdDriveException(errorOf(e.status, e.details));
    } on TimeoutException {
      throw const RdDriveException(RdDriveError.failed);
    }
  }

  /// The error behind a refused call: the function's code, or "not set up"
  /// when the function itself is missing.
  static RdDriveError errorOf(int status, Object? details) {
    final code = details is Map ? details['error'] : null;
    return switch (code) {
      'not_found' => RdDriveError.notFound,
      'not_folder' => RdDriveError.notFolder,
      'not_configured' => RdDriveError.notSetUp,
      'limit' => RdDriveError.limit,
      'drive_busy' => RdDriveError.busy,
      'exists' => RdDriveError.exists,
      'forbidden' => RdDriveError.forbidden,
      'too_many' => RdDriveError.tooMany,
      _ when status == 404 => RdDriveError.notSetUp,
      _ => RdDriveError.failed,
    };
  }

  /// Name of [folder].
  Future<String> folderName(int tenantId, RdDriveRef folder) async {
    final data = await _call({'action': 'folder', 'tenantId': tenantId, 'folder': folder.toJson()});
    return (data['name'] as String?) ?? '';
  }

  /// Children of each of [folders] (at most [maxFolders] at once).
  Future<Map<String, List<RdDriveItem>>> list(int tenantId, List<RdDriveRef> folders) async {
    final data = await _call({
      'action': 'list',
      'tenantId': tenantId,
      'folders': [for (final f in folders) f.toJson()],
    });
    final children = (data['children'] as Map?) ?? const {};
    return {
      for (final f in folders)
        f.id: [
          for (final item in (children[f.id] as List?) ?? const [])
            if (item is Map && item['id'] is String) RdDriveItem.fromJson(Map<String, dynamic>.from(item)),
        ],
    };
  }

  static const maxFolders = 25;

  /// The first and last 256 KB of [file] (the whole file when smaller).
  Future<Uint8List> head(int tenantId, RdDriveRef file) async {
    final data = await _call({'action': 'head', 'tenantId': tenantId, 'file': file.toJson()});
    return base64Decode((data['data'] as String?) ?? '');
  }

  /// Copies [file] to `songs/<tenantId>/<songId>/<storageName>`; returns the
  /// storage path.
  Future<String> copy(
    int tenantId,
    RdDriveRef file, {
    required int songId,
    required String storageName,
    required String contentType,
  }) async {
    final data = await _call({
      'action': 'copy',
      'tenantId': tenantId,
      'file': file.toJson(),
      'songId': songId,
      'storageName': storageName,
      'contentType': contentType,
    });
    return (data['path'] as String?) ?? '';
  }
}

final rdDriveApiProvider = Provider<RdDriveApi>((ref) => RdDriveApi.supabase(ref.watch(supabaseClientProvider)));

/// The files of a shared Drive folder, as an import source.
class RdDriveSource implements RdImportFiles {
  RdDriveSource._(this._api, this._tenantId, this.folder, this.name, this.entries, this.junk, this._files);

  /// More files than this: choose a sub-folder.
  static const maxFiles = 10000;
  static const maxFolders = 3000;

  /// Reads [folder] (named [name]) level by level. [onProgress] gets the
  /// files found so far; [cancelled] stops between two requests.
  static Future<RdDriveSource> load(
    RdDriveApi api,
    int tenantId,
    RdDriveRef folder,
    String name, {
    void Function(int files)? onProgress,
    bool Function()? cancelled,
  }) async {
    final root = _safe(name.trim().isEmpty ? 'Google Drive' : name.trim());
    final entries = <RdImportEntry>[];
    final files = <String, RdDriveItem>{};
    var junk = 0;
    var folders = 0;
    var level = <(RdDriveRef, String)>[(folder, root)];
    final seen = <String>{folder.id};
    while (level.isNotEmpty) {
      final next = <(RdDriveRef, String)>[];
      for (var i = 0; i < level.length; i += RdDriveApi.maxFolders) {
        if (cancelled?.call() ?? false) throw const RdDriveException(RdDriveError.failed);
        final batch = level.sublist(i, i + RdDriveApi.maxFolders > level.length ? level.length : i + RdDriveApi.maxFolders);
        final children = await api.list(tenantId, [for (final (ref, _) in batch) ref]);
        for (final (ref, path) in batch) {
          final names = <String>{};
          final items = [...?children[ref.id]]..sort((a, b) => a.name.compareTo(b.name));
          for (final item in items) {
            if (item.isShortcut) {
              junk++;
              continue;
            }
            final itemName = _unique(_safe(item.name), names, keepExtension: !item.isFolder);
            final itemPath = '$path/$itemName';
            if (item.isFolder) {
              if (!seen.add(item.id)) continue;
              if (++folders > maxFolders) throw const RdDriveException(RdDriveError.tooMany);
              next.add((item.ref, itemPath));
              continue;
            }
            // Google Docs have no file to copy: shown with Drive's own
            // ending, so the review lists them as "format not supported".
            final filePath = item.isGoogleFile ? '$itemPath.${_googleExtension(item.mimeType)}' : itemPath;
            if (rdImportIsJunk(filePath)) {
              junk++;
              continue;
            }
            if (entries.length >= maxFiles) throw const RdDriveException(RdDriveError.tooMany);
            files[filePath] = item;
            entries.add(RdImportEntry(path: filePath, size: item.size, modified: item.modified));
          }
        }
        onProgress?.call(entries.length);
      }
      level = next;
    }
    return RdDriveSource._(api, tenantId, folder, root, entries, junk, files);
  }

  final RdDriveApi _api;
  final int _tenantId;

  /// The shared folder (to open it again after the import).
  final RdDriveRef folder;
  @override
  final String name;
  @override
  final List<RdImportEntry> entries;
  @override
  final int junk;
  final Map<String, RdDriveItem> _files;

  RdDriveItem _item(String path) {
    final item = _files[path];
    if (item == null) throw StateError('not in import: $path');
    return item;
  }

  @override
  Future<({String? hash, DateTime? date})> inspect(String path, {required bool hash, required bool date}) async {
    final item = _item(path);
    DateTime? found;
    if (date && path.toLowerCase().endsWith('.pdf') && !item.isGoogleFile) {
      found = rdPdfDate(await _api.head(_tenantId, item.ref));
    }
    // Drive knows the MD5 of every file; without one there is no check.
    return (hash: hash && item.md5 != null ? 'md5:${item.md5}' : null, date: found);
  }

  @override
  Future<void> upload(
    SongFileService service, {
    required int songId,
    required String path,
    required String fileName,
    int? instrumentId,
    String? note,
    int? mainGroupId,
  }) async {
    final item = _item(path);
    await service.uploadFileVia(
      songId: songId,
      fileName: fileName,
      store: (tenantId, storageName, contentType) {
        // The service and the import target the same group.
        if (tenantId != _tenantId) throw const RdDriveException(RdDriveError.forbidden);
        return _api.copy(tenantId, item.ref, songId: songId, storageName: storageName, contentType: contentType);
      },
      instrumentId: instrumentId,
      note: note,
      mainGroupId: mainGroupId,
      keepBesetzung: true,
    );
  }

  @override
  Future<void> close() async {}

  /// A name usable as one path segment.
  static String _safe(String name) {
    final s = name.replaceAll(RegExp(r'[/\\]'), '-').trim();
    return s.isEmpty ? '_' : s;
  }

  /// [name], or "name (2).pdf" when the folder has it twice.
  static String _unique(String name, Set<String> taken, {required bool keepExtension}) {
    if (taken.add(name.toLowerCase())) return name;
    final dot = keepExtension ? name.lastIndexOf('.') : -1;
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    for (var n = 2;; n++) {
      final candidate = '$stem ($n)$ext';
      if (taken.add(candidate.toLowerCase())) return candidate;
    }
  }

  static String _googleExtension(String mimeType) => switch (mimeType) {
        'application/vnd.google-apps.document' => 'gdoc',
        'application/vnd.google-apps.spreadsheet' => 'gsheet',
        'application/vnd.google-apps.presentation' => 'gslides',
        _ => 'gfile',
      };
}
