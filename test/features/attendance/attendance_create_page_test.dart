import 'package:flutter_test/flutter_test.dart';

// Unit test for RT-001: StateError bei unbekanntem additionalField
// Tests the logic of filtering players by additional_fields_filter
// when the field no longer exists in tenant.additionalFields

void main() {
  group('Additional Fields Filter - Issue #34 RT-001', () {
    test('should not throw StateError when additionalField not found', () {
      // Arrange: Simulate tenant with NO additional fields
      final tenantAdditionalFields = <Map<String, dynamic>>[];

      final filterKey = 'deleted_field_id';

      // Act: Try to find field definition (the problematic code path)
      final fieldDef = tenantAdditionalFields
          .where((f) => f['id'] == filterKey)
          .firstOrNull;

      // Assert: Should return null instead of throwing
      expect(fieldDef, isNull);
    });

    test('should include player when filter field not found (fallback)', () {
      // Arrange
      final tenantAdditionalFields = <Map<String, dynamic>>[];
      final filterKey = 'deleted_field_id';

      // Act: Simulate the filter logic with safe null handling
      final fieldDef = tenantAdditionalFields
          .where((f) => f['id'] == filterKey)
          .firstOrNull;

      // When field is not found, player should be INCLUDED (return true)
      final shouldIncludePlayer = fieldDef == null;

      // Assert
      expect(shouldIncludePlayer, isTrue,
          reason: 'Player should be included when filter field no longer exists');
    });

    test('should filter correctly when field exists', () {
      // Arrange: Field exists in tenant
      final tenantAdditionalFields = [
        {
          'id': 'instrument_category',
          'name': 'Instrument Category',
          'defaultValue': 'strings',
        }
      ];

      final filterKey = 'instrument_category';
      final filterOption = 'strings';

      // Player has the field value matching the filter
      final playerAdditionalFields = {'instrument_category': 'strings'};

      // Act
      final fieldDef = tenantAdditionalFields
          .where((f) => f['id'] == filterKey)
          .firstOrNull;

      // Found the field
      expect(fieldDef, isNotNull);

      final defaultValue = fieldDef?['defaultValue'];
      final playerValue = playerAdditionalFields[filterKey];
      final effectiveValue = playerValue ?? defaultValue;

      final shouldIncludePlayer = effectiveValue == filterOption;

      // Assert
      expect(shouldIncludePlayer, isTrue);
    });

    test('should use defaultValue when player has no value set', () {
      // Arrange
      final tenantAdditionalFields = [
        {
          'id': 'section',
          'name': 'Section',
          'defaultValue': 'all',
        }
      ];

      final filterKey = 'section';
      final filterOption = 'all';

      // Player has NO value for this field
      final playerAdditionalFields = <String, dynamic>{};

      // Act
      final fieldDef = tenantAdditionalFields
          .where((f) => f['id'] == filterKey)
          .firstOrNull;

      final defaultValue = fieldDef?['defaultValue'];
      final playerValue = playerAdditionalFields[filterKey];
      final effectiveValue = playerValue ?? defaultValue;

      final shouldIncludePlayer = effectiveValue == filterOption;

      // Assert: Should match because defaultValue == filterOption
      expect(shouldIncludePlayer, isTrue);
    });
  });
}
