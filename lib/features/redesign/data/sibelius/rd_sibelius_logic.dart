import 'dart:convert';
import 'dart:typed_data';

import '../../../../data/models/song/song.dart';

/// REDESIGN (Mac app): "In Sibelius bearbeiten". A Sibelius score of a Werk
/// is copied into a work folder (Downloads › Attendix › Gruppe › Werk) and
/// opened in Sibelius; every save there replaces the file in Attendix. The
/// Attendix plug-in for Sibelius ([rdSibeliusPluginSource]) saves the score
/// and exports all parts as PDFs into the folder [rdSibeliusPartsFolder]
/// next to it; Attendix then offers them as the new Stimmen of the Werk.
///
/// Pure helpers (no I/O) of that flow.

/// Folder next to the score the plug-in exports the parts into.
const String rdSibeliusPartsFolder = 'Stimmen';

/// Folder (in Downloads) that holds the work folders.
const String rdSibeliusRootFolder = 'Attendix';

/// Category folder and file name of the installed plug-in (Sibelius shows
/// the category as "Plug-ins › Attendix").
const String rdSibeliusPluginCategory = 'Attendix';
const String rdSibeliusPluginFileName = 'AttendixStimmen.plg';

/// Whether [file] is a Sibelius score (.sib).
bool rdIsSibeliusFile(SongFile file) {
  for (final name in [file.fileName, file.storageName ?? '']) {
    if (name.toLowerCase().endsWith('.sib')) return true;
  }
  return Uri.tryParse(file.url)?.path.toLowerCase().endsWith('.sib') ?? false;
}

/// [name] as one segment of a macOS path: no "/" or ":" (Finder shows ":" as
/// "/"), no control characters, no leading dots, at most 80 characters.
String rdSafePathSegment(String name, {String fallback = 'Werk'}) {
  var s = name
      .replaceAll(RegExp(r'[/:\\]'), '-')
      .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceFirst(RegExp(r'^\.+'), '')
      .trim();
  if (s.length > 80) s = s.substring(0, 80).trim();
  return s.isEmpty ? fallback : s;
}

/// Work folder of a Werk: "Nr Titel", as in the Werke list.
String rdSibeliusWorkFolder({int? number, required String name}) =>
    rdSafePathSegment(number == null ? name : '$number $name');

/// File name of the copy that is kept next to the replaced one when the file
/// changed in Attendix while it was being edited in Sibelius
/// ("Lied.sib" → "Lied (aus Sibelius).sib").
String rdSibeliusCopyName(String fileName, String suffix) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0) return '$fileName $suffix';
  return '${fileName.substring(0, dot)} $suffix${fileName.substring(dot)}';
}

/// The home folder of the user from a path inside it (the sandboxed Mac app
/// sees its container as home: `/Users/x/Library/Containers/<id>/Data`).
String rdRealHome(String path) {
  final i = path.indexOf('/Library/Containers/');
  if (i > 0) return path.substring(0, i);
  final parts = path.split('/');
  // /Users/<name>/…
  if (parts.length >= 3 && parts[1] == 'Users') return '/${parts[1]}/${parts[2]}';
  return path;
}

/// Folder of the user's Sibelius plug-ins (Sibelius loads them from its
/// subfolders, one per category).
String rdSibeliusPluginsFolder(String home) => '$home/Library/Application Support/Avid/Sibelius/Plugins';

/// A score being edited in Sibelius: where its copy lies and which Attendix
/// file it replaces.
class RdSibeliusCheckout {
  const RdSibeliusCheckout({
    required this.path,
    required this.tenantId,
    required this.songId,
    required this.userId,
    required this.url,
    required this.storageName,
    required this.fileName,
    required this.hash,
    required this.modified,
    this.instrumentId,
    this.note,
    this.mainGroupId,
    this.failedModified,
  });

  /// Real path of the copy (its key).
  final String path;

  /// Tenant whose songs hold the file (the song source tenant).
  final int tenantId;
  final int songId;

  /// User who opened it; others never upload it.
  final String userId;

  /// The Attendix file the copy replaces (changes with every upload).
  final String url;
  final String? storageName;
  final String fileName;
  final int? instrumentId;
  final String? note;
  final int? mainGroupId;

  /// SHA-256 of the content Attendix has, and the modification time (ms) of
  /// the copy when it was last compared.
  final String hash;
  final int modified;

  /// Modification time of a save whose upload failed: not retried until the
  /// file changes again or the app comes back.
  final int? failedModified;

  /// Whether [file] (of [songId] in [tenantId]) is the one this copy edits.
  bool matches(int tenantId, int songId, SongFile file) =>
      this.tenantId == tenantId &&
      this.songId == songId &&
      (url == file.url || ((storageName ?? '').isNotEmpty && storageName == file.storageName));

  RdSibeliusCheckout copyWith({
    String? url,
    String? storageName,
    String? fileName,
    String? hash,
    int? modified,
    int? failedModified,
    bool clearFailed = false,
  }) =>
      RdSibeliusCheckout(
        path: path,
        tenantId: tenantId,
        songId: songId,
        userId: userId,
        url: url ?? this.url,
        storageName: storageName ?? this.storageName,
        fileName: fileName ?? this.fileName,
        instrumentId: instrumentId,
        note: note,
        mainGroupId: mainGroupId,
        hash: hash ?? this.hash,
        modified: modified ?? this.modified,
        failedModified: clearFailed ? null : (failedModified ?? this.failedModified),
      );

  Map<String, dynamic> toJson() => {
    'path': path,
    'tenantId': tenantId,
    'songId': songId,
    'userId': userId,
    'url': url,
    'storageName': storageName,
    'fileName': fileName,
    'instrumentId': instrumentId,
    'note': note,
    'mainGroupId': mainGroupId,
    'hash': hash,
    'modified': modified,
    'failedModified': failedModified,
  };

  static RdSibeliusCheckout? fromJson(Object? json) {
    if (json is! Map) return null;
    final path = json['path'];
    final tenantId = json['tenantId'];
    final songId = json['songId'];
    final userId = json['userId'];
    final url = json['url'];
    final fileName = json['fileName'];
    final hash = json['hash'];
    final modified = json['modified'];
    if (path is! String ||
        tenantId is! int ||
        songId is! int ||
        userId is! String ||
        url is! String ||
        fileName is! String ||
        hash is! String ||
        modified is! int) {
      return null;
    }
    return RdSibeliusCheckout(
      path: path,
      tenantId: tenantId,
      songId: songId,
      userId: userId,
      url: url,
      storageName: json['storageName'] as String?,
      fileName: fileName,
      instrumentId: json['instrumentId'] as int?,
      note: json['note'] as String?,
      mainGroupId: json['mainGroupId'] as int?,
      hash: hash,
      modified: modified,
      failedModified: json['failedModified'] as int?,
    );
  }
}

/// Exported parts waiting to be taken over: the PDFs in a work folder's
/// [rdSibeliusPartsFolder] that are newer than what was taken last.
class RdSibeliusParts {
  const RdSibeliusParts({required this.folder, required this.tenantId, required this.songId, required this.paths});

  /// The parts folder (key).
  final String folder;
  final int tenantId;
  final int songId;
  final List<String> paths;
}

/// The PDFs of a parts folder ([entries]: path, modification time in ms)
/// that are newer than [since], sorted by name.
List<String> rdNewPartPdfs(Map<String, int> entries, int since) =>
    [
      for (final e in entries.entries)
        if (e.value > since && e.key.toLowerCase().endsWith('.pdf')) e.key,
    ]..sort();

/// The Sibelius plug-in (ManuScript): saves the active score and exports all
/// its parts (not the full score) as separate PDFs named after the part
/// into the folder [rdSibeliusPartsFolder] next to the score.
///
/// Inside a method body strings use single quotes (the body itself is a
/// double-quoted string), as in the plug-ins shipped with Sibelius.
const String rdSibeliusPluginSource = r'''
{
	Initialize "() {
AddToPluginsMenu(_MenuName,'Run'); }"
	Run "() {
if (Sibelius.ScoreCount = 0)
{
	Sibelius.MessageBox(_msgNoScore);
	return False;
}
score = Sibelius.ActiveScore;
if (score.FileName = '')
{
	Sibelius.MessageBox(_msgNotSaved);
	return False;
}
count = -1;
for each part in score.DynamicParts
{
	count = count + 1;
}
if (count < 1)
{
	Sibelius.MessageBox(_msgNoParts);
	return False;
}
score.Save(score.FileName);
file = Sibelius.GetFile(score.FileName);
folder = file.Path;
if (CharAt(folder, Length(folder) - 1) != Sibelius.PathSeparator)
{
	folder = folder & Sibelius.PathSeparator;
}
folder = folder & _Subfolder;
if (Sibelius.FolderExists(folder) = False)
{
	created = Sibelius.CreateFolder(folder);
	if ((created = null) or (IsObject(created) = False))
	{
		Sibelius.MessageBox(_msgNoFolder & folder);
		return False;
	}
}
score.ExportPartsAsPDF(folder & Sibelius.PathSeparator & '%p.pdf', False, 0, False);
Sibelius.MessageBox(_msgDone1 & count & _msgDone2);
return True; }"
	_MenuName "Stimmen für Attendix exportieren"
	_Subfolder "Stimmen"
	_msgNoScore "Bitte öffne zuerst eine Partitur."
	_msgNotSaved "Bitte speichere die Partitur zuerst einmal (Datei › Speichern unter)."
	_msgNoParts "Diese Partitur hat keine Stimmen."
	_msgNoFolder "Der Ordner für die Stimmen konnte nicht angelegt werden: "
	_msgDone1 "Gespeichert und "
	_msgDone2 " Stimmen als PDF in den Ordner „Stimmen“ gelegt. Attendix zeigt dir gleich, welche Stimmen es ersetzt."
}
''';

/// [source] as Sibelius stores plug-ins: UTF-16 big endian with BOM.
Uint8List rdSibeliusPluginBytes([String source = rdSibeliusPluginSource]) {
  final units = source.codeUnits;
  final bytes = Uint8List(2 + units.length * 2);
  bytes[0] = 0xFE;
  bytes[1] = 0xFF;
  for (var i = 0; i < units.length; i++) {
    bytes[2 + i * 2] = units[i] >> 8;
    bytes[3 + i * 2] = units[i] & 0xFF;
  }
  return bytes;
}

/// JSON of the stored state: the open copies and, per parts folder, the
/// modification time (ms) up to which parts were taken.
String rdSibeliusStateJson(List<RdSibeliusCheckout> checkouts, Map<String, int> partsSince) =>
    jsonEncode({'checkouts': [for (final c in checkouts) c.toJson()], 'partsSince': partsSince});

({List<RdSibeliusCheckout> checkouts, Map<String, int> partsSince}) rdSibeliusStateFromJson(String? raw) {
  if (raw == null || raw.isEmpty) return (checkouts: const [], partsSince: const {});
  try {
    final json = jsonDecode(raw);
    if (json is! Map) return (checkouts: const [], partsSince: const {});
    final list = json['checkouts'];
    final since = json['partsSince'];
    return (
      checkouts: [
        if (list is List)
          for (final c in list)
            if (RdSibeliusCheckout.fromJson(c) case final checkout?) checkout,
      ],
      partsSince: {
        if (since is Map)
          for (final e in since.entries)
            if (e.key is String && e.value is int) e.key as String: e.value as int,
      },
    );
  } catch (_) {
    return (checkouts: const [], partsSince: const {});
  }
}
