import '../../../data/models/instrument/instrument.dart';
import 'instrument_catalog.dart';
import 'instrument_presets.dart';

export 'instrument_catalog.dart' show normalizeCatalogName;

/// A selection before any local group is created.
class CatalogGroupDraft {
  const CatalogGroupDraft({
    required this.key,
    required this.instrumentId,
    required this.name,
    this.categoryName,
    this.synonyms = const [],
    this.tuning,
    this.clefs,
  });

  final String key;
  final String instrumentId;
  final String name;
  final String? categoryName;
  final List<String> synonyms;
  final String? tuning;
  final List<String>? clefs;

  /// A deliberately renamed part must not retain aliases for the old part.
  CatalogGroupDraft copyWith({String? name}) {
    if (name == null) return this;
    final trimmedName = name.trim();
    final unchanged =
        normalizeCatalogName(trimmedName) == normalizeCatalogName(this.name);
    return CatalogGroupDraft(
      key: key,
      instrumentId: instrumentId,
      name: trimmedName,
      categoryName: categoryName,
      synonyms: unchanged ? synonyms : const [],
      tuning: tuning,
      clefs: clefs,
    );
  }
}

CatalogGroupDraft draftFromInstrument(
  CatalogInstrument instrument, {
  required String languageCode,
  String? name,
}) {
  final outputName = instrument.label(languageCode);
  final draft = CatalogGroupDraft(
    key: instrument.id,
    instrumentId: instrument.id,
    name: outputName,
    categoryName:
        instrument.family == InstrumentFamily.voices
            ? null
            : instrument.family.label(languageCode),
    synonyms: _preciseSynonyms(outputName, [
      instrument.nameDe,
      instrument.nameEn,
      ...instrument.aliases,
    ]),
    tuning: instrument.tuning,
    clefs: instrument.clefs,
  );
  return name == null ? draft : draft.copyWith(name: name);
}

CatalogGroupDraft draftFromPresetEntry(
  CatalogPresetEntry entry, {
  required String languageCode,
}) {
  final instrument = instrumentCatalog.singleWhere(
    (instrument) => instrument.id == entry.instrumentId,
  );
  final outputName = entry.label(languageCode);
  return CatalogGroupDraft(
    key: entry.key,
    instrumentId: entry.instrumentId,
    name: outputName,
    categoryName:
        instrument.family == InstrumentFamily.voices
            ? null
            : instrument.family.label(languageCode),
    // A preset has its own part-specific aliases, especially Violin I / II.
    synonyms: _preciseSynonyms(outputName, [
      entry.nameDe,
      entry.nameEn,
      ...entry.synonyms,
    ]),
    tuning: instrument.tuning,
    clefs: instrument.clefs,
  );
}

/// Adds missing drafts without changing existing names, metadata or order.
/// Keys preserve deliberate overrides; only complete names and curated aliases
/// identify equivalents, so numbered parts and related types stay separate.
List<CatalogGroupDraft> mergeCatalogDrafts(
  List<CatalogGroupDraft> current,
  List<CatalogGroupDraft> additions,
) {
  final merged = [...current];
  final keys = current.map((draft) => draft.key).toSet();
  final names = current.expand(_draftNames).toSet();
  for (final draft in additions) {
    final draftNames = _draftNames(draft);
    if (keys.contains(draft.key) || draftNames.any(names.contains)) continue;
    merged.add(draft);
    keys.add(draft.key);
    names.addAll(draftNames);
  }
  return List.unmodifiable(merged);
}

/// Matches complete names or explicit aliases; leaders are not instruments.
bool draftMatchesGroup(CatalogGroupDraft draft, Group group) {
  if (group.maingroup == true) return false;
  final draftNames = _draftNames(draft);
  final groupNames = [
    group.name,
    ...(group.synonyms ?? '').split(','),
  ].map(normalizeCatalogName).where((name) => name.isNotEmpty);
  return groupNames.any(draftNames.contains);
}

Set<String> _draftNames(CatalogGroupDraft draft) =>
    [
      draft.name,
      ...draft.synonyms,
    ].map(normalizeCatalogName).where((name) => name.isNotEmpty).toSet();

List<String> _preciseSynonyms(String name, Iterable<String> aliases) {
  final seen = {normalizeCatalogName(name)};
  return List.unmodifiable([
    for (final alias in aliases)
      if (alias.trim().isNotEmpty && seen.add(normalizeCatalogName(alias)))
        alias.trim(),
  ]);
}
