import 'package:intl/intl.dart';

import '../../data/models/tenant/tenant.dart';

/// Extra field (tenant.additional_fields) types — Ionic `FieldType`.
abstract final class ExtraFieldType {
  static const text = 'text';
  static const textarea = 'textarea';
  static const number = 'number';
  static const date = 'date';
  static const boolean = 'boolean';
  static const select = 'select';
  static const bfecgChurch = 'bfecg_church';
}

/// Default value for an extra field. Port of Ionic
/// `Utils.getFieldTypeDefaultValue`.
dynamic extraFieldDefaultValue(
  ExtraField field, {
  List<String> churchIds = const [],
}) {
  if (field.defaultValue != null) return field.defaultValue;
  if (field.type == ExtraFieldType.bfecgChurch && churchIds.isNotEmpty) {
    return churchIds.first;
  }
  if (field.type == ExtraFieldType.select) {
    final options = field.options;
    return options != null && options.isNotEmpty ? options.first : '';
  }
  switch (field.type) {
    case ExtraFieldType.number:
      return 0;
    case ExtraFieldType.date:
      return DateTime.now().toIso8601String();
    case ExtraFieldType.boolean:
      return true;
    default:
      return '';
  }
}

/// Raw value of an extra field for a person, falling back to the field's
/// default value when the person has additional_fields but not this key
/// (Ionic `Utils.getModifiedPlayersForList`).
dynamic extraFieldRawValue(
  Map<String, dynamic>? additionalFields,
  ExtraField field, {
  List<String> churchIds = const [],
}) {
  if (additionalFields == null) return null;
  final value = additionalFields[field.id];
  if (value != null) return value;
  return extraFieldDefaultValue(field, churchIds: churchIds);
}

/// Human readable value of an extra field (Ionic export.page.ts
/// `formatAdditionalFieldValue`).
String formatExtraFieldValue(
  Map<String, dynamic>? additionalFields,
  ExtraField field, {
  Map<String, String> churchNames = const {},
}) {
  final value = extraFieldRawValue(
    additionalFields,
    field,
    churchIds: churchNames.keys.toList(),
  );
  if (value == null) return '';
  switch (field.type) {
    case ExtraFieldType.boolean:
      final b = value == true || value == 'true';
      return b ? 'Ja' : 'Nein';
    case ExtraFieldType.date:
      final d = DateTime.tryParse(value.toString());
      if (d == null) return value.toString();
      return DateFormat('dd.MM.yyyy').format(d.toLocal());
    case ExtraFieldType.bfecgChurch:
      return churchNames[value.toString()] ?? value.toString();
    default:
      return value.toString();
  }
}
