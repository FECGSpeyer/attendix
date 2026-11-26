/// German holiday regions.
const holidayRegions = [
  ('', 'Keine Feiertage'),
  ('BW', 'Baden-Württemberg'),
  ('BY', 'Bayern'),
  ('BE', 'Berlin'),
  ('BB', 'Brandenburg'),
  ('HB', 'Bremen'),
  ('HH', 'Hamburg'),
  ('HE', 'Hessen'),
  ('MV', 'Mecklenburg-Vorpommern'),
  ('NI', 'Niedersachsen'),
  ('NW', 'Nordrhein-Westfalen'),
  ('RP', 'Rheinland-Pfalz'),
  ('SL', 'Saarland'),
  ('SN', 'Sachsen'),
  ('ST', 'Sachsen-Anhalt'),
  ('SH', 'Schleswig-Holstein'),
  ('TH', 'Thüringen'),
];

/// Returns the stored registration fields, or only the required ones.
List<String> initialRegistrationFields(List<String>? stored) =>
    List<String>.from((stored?.isNotEmpty ?? false)
        ? stored!
        : const ['firstName', 'lastName', 'group']);

/// Filters out blank reasons; an empty result is stored as `null`.
List<String>? normalizeReasons(List<String> reasons) {
  final filtered = reasons.where((r) => r.trim().isNotEmpty).toList();
  return filtered.isEmpty ? null : filtered;
}

/// `show_all_attendances_info_text` is `null` when disabled, otherwise the
/// trimmed text or [defaultText].
String? normalizeShowAllInfoText({
  required bool enabled,
  required String text,
  required String defaultText,
}) {
  if (!enabled) return null;
  final trimmed = text.trim();
  return trimmed.isNotEmpty ? trimmed : defaultText;
}
