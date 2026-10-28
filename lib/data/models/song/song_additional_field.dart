/// Tenant-defined additional field for songs (`tenants.song_additional_fields`).
///
/// Mirrors Ionic's `ExtraField` (with `displayMode`). Kept as a plain class
/// (no codegen) because it is only read from the tenant row.
class SongAdditionalField {
  const SongAdditionalField({
    required this.id,
    required this.name,
    required this.type,
    this.defaultValue,
    this.options = const [],
    this.displayMode,
  });

  final String id;
  final String name;

  /// One of: text, textarea, number, date, boolean, select
  final String type;
  final dynamic defaultValue;
  final List<String> options;

  /// 'chip' (badge at the end of the row, default) or 'underneath'
  final String? displayMode;

  bool get isBoolean => type == 'boolean';
  bool get isSelect => type == 'select';
  bool get isNumber => type == 'number';
  bool get showUnderneath => displayMode == 'underneath';

  factory SongAdditionalField.fromJson(Map<String, dynamic> json) {
    return SongAdditionalField(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      defaultValue: json['defaultValue'],
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      displayMode: json['displayMode'] as String?,
    );
  }

  /// Default value like Ionic `Utils.getFieldTypeDefaultValue`.
  dynamic get effectiveDefault {
    if (defaultValue != null) return defaultValue;
    switch (type) {
      case 'boolean':
        return true;
      case 'date':
        return DateTime.now().toIso8601String();
      case 'number':
        return 0;
      case 'select':
        return options.isNotEmpty ? options.first : '';
      default:
        return '';
    }
  }

  static List<SongAdditionalField> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => SongAdditionalField.fromJson(Map<String, dynamic>.from(e)))
        .where((f) => f.id.isNotEmpty)
        .toList();
  }
}

/// Whether a song additional field value should be displayed in the list
/// (Ionic: not undefined, not '', not false, not null).
bool isDisplayableSongFieldValue(dynamic value) =>
    value != null && value != '' && value != false;
