import '../../data/models/instrument/instrument.dart';
import '../../data/models/song/song.dart';
import '../../data/models/tenant/tenant.dart' show ExtraField;

/// Helpers for copying a Werk found by the organisation-wide search into
/// another instance (port of Ionic `utilities/song-copy.ts`, 4.17.13).

/// Reserved file "groups": 1 = Aufnahme, 2 = Liedtext. They exist in every
/// instance.
const List<int> reservedFileGroupIds = [1, 2];

String _norm(String? value) => (value ?? '').trim().toLowerCase();

List<String> _splitSynonyms(String? synonyms) =>
    (synonyms ?? '').split(',').map(_norm).where((s) => s.isNotEmpty).toList();

/// Finds the group in the target instance that matches a source group by
/// name, falling back to synonyms on either side. Reserved ids (Aufnahme,
/// Liedtext) stay as they are.
int? mapGroupByName(int? sourceGroupId, String? sourceGroupName, String? sourceSynonyms, List<Group> targetGroups) {
  if (sourceGroupId == null || sourceGroupId == 0) return null;
  if (reservedFileGroupIds.contains(sourceGroupId)) return sourceGroupId;
  final name = _norm(sourceGroupName);
  if (name.isEmpty) return null;

  for (final g in targetGroups) {
    if (_norm(g.name) == name) return g.id;
  }

  final synonyms = _splitSynonyms(sourceSynonyms);
  for (final g in targetGroups) {
    final targetName = _norm(g.name);
    final targetSynonyms = _splitSynonyms(g.synonyms);
    if (synonyms.contains(targetName) || targetSynonyms.contains(name) || targetSynonyms.any(synonyms.contains)) {
      return g.id;
    }
  }
  return null;
}

String _normName(String? name) => _norm(name).replaceAll(RegExp(r'\s+'), ' ');

/// Songs in the target library whose name matches (case- and
/// whitespace-insensitive).
List<Song> findSongsWithSameName(String name, List<Song> songs) {
  final wanted = _normName(name);
  return songs.where((s) => _normName(s.name) == wanted).toList();
}

/// True if a song in the library already uses this prefix + number.
bool isSongNumberTaken(int? number, String? prefix, List<Song> songs) {
  if (number == null) return false;
  return songs.any((s) => s.number == number && _norm(s.prefix) == _norm(prefix));
}

/// Smallest number above the current maximum for this prefix.
int nextFreeSongNumber(String? prefix, List<Song> songs) {
  final numbers = songs.where((s) => _norm(s.prefix) == _norm(prefix)).map((s) => s.number ?? 0);
  return (numbers.isEmpty ? 0 : numbers.reduce((a, b) => a > b ? a : b)) + 1;
}

/// A source extra field value paired with the target field it goes to.
class MappedExtraField {
  const MappedExtraField({required this.sourceField, required this.targetField, required this.value});

  final ExtraField sourceField;
  final ExtraField targetField;
  final dynamic value;
}

/// Pairs the source Werk's extra field values with fields of the target
/// instance that have the same name and type. Empty values are skipped, as
/// are select values the target field does not offer.
List<MappedExtraField> mapExtraFields(
  Map<String, dynamic>? values,
  List<ExtraField>? sourceFields,
  List<ExtraField>? targetFields,
) {
  final result = <MappedExtraField>[];
  for (final sourceField in sourceFields ?? const <ExtraField>[]) {
    final value = values?[sourceField.id];
    if (value == null || value == '') continue;
    final targetField =
        (targetFields ?? const <ExtraField>[])
            .where((f) => _norm(f.name) == _norm(sourceField.name) && f.type == sourceField.type)
            .firstOrNull;
    if (targetField == null) continue;
    final options = targetField.options;
    if (options != null && options.isNotEmpty && value is String && !options.contains(value)) {
      continue;
    }
    result.add(MappedExtraField(sourceField: sourceField, targetField: targetField, value: value));
  }
  return result;
}

/// `instrument_ids` of a song as derived from its files (without null, the
/// reserved ids and the main group), de-duplicated in first-seen order.
List<int> instrumentIdsFromCopiedFiles(Iterable<int?> fileGroupIds, {int? mainGroupId}) =>
    fileGroupIds
        .whereType<int>()
        .where((id) => !reservedFileGroupIds.contains(id) && id != mainGroupId)
        .toSet()
        .toList();

/// Ionic `songLabel`: `prefix + number + ' ' + name` (number only when set).
String orgSongLabel(String? prefix, int? number, String name) {
  final n = number != null && number != 0 ? '${prefix ?? ''}$number ' : '';
  return '$n$name';
}
