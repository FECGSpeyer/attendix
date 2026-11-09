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
const String rdSibeliusRootFolder = 'Attendix Noten';

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
  var s =
      name
          .replaceAll(RegExp(r'[/:\\]'), '-')
          .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .replaceFirst(RegExp(r'^\.+'), '')
          .trim();
  if (s.length > 80) {
    // Shortened before the extension (".sib" decides which app opens it).
    final dot = s.lastIndexOf('.');
    final ext = dot > 0 && s.length - dot <= 6 ? s.substring(dot) : '';
    s = s.substring(0, 80 - ext.length).trim() + ext;
  }
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
    this.failedAt,
    this.failCount = 0,
    this.attempts = const [],
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

  /// Modification time of a save whose upload failed, when (ms) it failed
  /// last and how often in a row: it is tried again after
  /// [rdSibeliusRetryDelay], also after a restart.
  final int? failedModified;
  final int? failedAt;
  final int failCount;

  /// Storage names of tries since the last confirmed upload: one of them may
  /// have gone through although its answer got lost.
  final List<String> attempts;

  /// Whether [file] (of [songId] in [tenantId]) is the one this copy edits.
  bool matches(int tenantId, int songId, SongFile file) =>
      this.tenantId == tenantId &&
      this.songId == songId &&
      (url == file.url ||
          ((storageName ?? '').isNotEmpty && storageName == file.storageName) ||
          // A try whose answer got lost may already be the file in Attendix.
          attempts.contains(file.storageName));

  RdSibeliusCheckout copyWith({
    String? url,
    String? storageName,
    String? fileName,
    String? hash,
    int? modified,
    int? failedModified,
    int? failedAt,
    int? failCount,
    List<String>? attempts,
    bool clearFailed = false,
  }) => RdSibeliusCheckout(
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
    failedAt: clearFailed ? null : (failedAt ?? this.failedAt),
    failCount: clearFailed ? 0 : (failCount ?? this.failCount),
    attempts: attempts ?? this.attempts,
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
    'failedAt': failedAt,
    'failCount': failCount,
    'attempts': attempts,
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
      failedAt: json['failedAt'] as int?,
      failCount: (json['failCount'] as int?) ?? 0,
      attempts: [
        for (final a in (json['attempts'] as List?) ?? const [])
          if (a is String) a,
      ],
    );
  }
}

/// Pause before a failed upload is tried again: 15 s, 30 s, then every
/// minute (a try without connection fails at once; coming back online or to
/// the app tries right away).
Duration rdSibeliusRetryDelay(int failCount) {
  if (failCount <= 0) return Duration.zero;
  return Duration(seconds: failCount == 1 ? 15 : (failCount == 2 ? 30 : 60));
}

/// Storage name of one upload try of [fileName]: unique per try, so a try
/// whose answer got lost can be recognised by it.
String rdSibeliusAttemptName(String fileName, int stamp) {
  final dot = fileName.lastIndexOf('.');
  final base = dot > 0 ? fileName.substring(0, dot) : fileName;
  final ext = dot > 0 && dot < fileName.length - 1 ? fileName.substring(dot + 1) : 'sib';
  // Same cleaning as the other storage names.
  final safe = base
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'[^\w\s-]'), '-')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '${safe}_$stamp.$ext';
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
List<String> rdNewPartPdfs(Map<String, int> entries, int since) => [
  for (final e in entries.entries)
    if (e.value > since && e.key.toLowerCase().endsWith('.pdf')) e.key,
]..sort();

/// Where the Mac app is installed when it cannot tell (TestFlight / App
/// Store install there).
const String rdAttendixAppDefaultPath = '/Applications/Attendix.app';

/// The app bundle of [executable] (`…/Attendix.app/Contents/MacOS/Attendix`);
/// [rdAttendixAppDefaultPath] when it is none or cannot stand in a plug-in
/// string.
String rdAttendixAppPath(String executable) {
  final i = executable.indexOf('.app/Contents/MacOS/');
  if (i <= 0) return rdAttendixAppDefaultPath;
  final path = executable.substring(0, i + 4);
  final unsafe = ['"', "'", '\\', '\n'].any(path.contains);
  return unsafe ? rdAttendixAppDefaultPath : path;
}

/// [rdSibeliusPluginSource] for the app at [appPath] (see [rdAttendixAppPath]).
String rdSibeliusPluginFor(String appPath) => rdSibeliusPluginSource.replaceFirst(_appPlaceholder, appPath);

const String _appPlaceholder = '{{ATTENDIX_APP}}';

/// The Sibelius plug-in (ManuScript): saves the active score, exports all
/// its parts (not the full score) as separate PDFs named after the part
/// into the folder [rdSibeliusPartsFolder] next to the score and brings
/// Attendix to the front, which then offers them (a Sibelius message box
/// cannot show the Attendix logo). Without the app it says so itself.
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
if (Sibelius.FolderExists(_App))
{
	Sibelius.LaunchApplication(_App);
	return True;
}
Sibelius.MessageBox(_msgDone1 & count & _msgDone2);
return True; }"
	_MenuName "Stimmen für Attendix exportieren"
	_Subfolder "Stimmen"
	_App "{{ATTENDIX_APP}}"
	_msgNoScore "Bitte öffne zuerst eine Partitur."
	_msgNotSaved "Bitte speichere die Partitur zuerst einmal (Datei › Speichern unter)."
	_msgNoParts "Diese Partitur hat keine Stimmen."
	_msgNoFolder "Der Ordner für die Stimmen konnte nicht angelegt werden: "
	_msgDone1 "Gespeichert und "
	_msgDone2 " Stimmen als PDF in den Ordner „Stimmen“ gelegt. Öffne Attendix, um sie zu übernehmen."
}
''';

/// [source] (see [rdSibeliusPluginFor]) as Sibelius stores plug-ins: UTF-16
/// big endian with BOM.
Uint8List rdSibeliusPluginBytes(String source) {
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
String rdSibeliusStateJson(List<RdSibeliusCheckout> checkouts, Map<String, int> partsSince) => jsonEncode({
  'checkouts': [for (final c in checkouts) c.toJson()],
  'partsSince': partsSince,
});

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
