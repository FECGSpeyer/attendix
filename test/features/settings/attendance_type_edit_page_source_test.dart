import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source code verification tests for AttendanceTypeEditPage
///
/// Ensures that the _save() method sends correct data types to Supabase:
/// - default_status: must use .value (int), not .name (string)
/// - available_statuses: must use .value (int[]), not .name (string[])
void main() {
  late String pageSource;

  setUpAll(() {
    final file = File(
      'lib/features/settings/presentation/pages/attendance_type_edit_page.dart',
    );
    pageSource = file.readAsStringSync();
  });

  group('AttendanceTypeEditPage - _save() method', () {
    test('default_status uses .value (integer), not .name (string)', () {
      // The update/insert payload is built by _buildTypeData()
      final saveMethod = _extractMethodBody(pageSource, '_buildTypeData');
      expect(saveMethod, isNotNull, reason: '_buildTypeData method should exist');

      // Should use .value for integer
      expect(
        saveMethod,
        contains('_defaultStatus.value'),
        reason: 'default_status must use .value (int), not .name (string)',
      );

      // Should NOT use .name which gives string
      expect(
        saveMethod,
        isNot(contains("'default_status': _defaultStatus.name")),
        reason: 'default_status must NOT use .name which sends string',
      );
    });

    test('available_statuses uses .value (integer array), not .name (string array)', () {
      final saveMethod = _extractMethodBody(pageSource, '_buildTypeData');
      expect(saveMethod, isNotNull, reason: '_buildTypeData method should exist');

      // Should use .value for integer array
      expect(
        saveMethod,
        contains('.map((s) => s.value)'),
        reason: 'available_statuses must use .value (int), not .name (string)',
      );

      // Should NOT use .name which gives string array
      expect(
        saveMethod,
        isNot(contains('.map((s) => s.name)')),
        reason: 'available_statuses must NOT use .name which sends strings',
      );
    });
  });
}

/// Extract method body from source code
String? _extractMethodBody(String source, String methodName) {
  final methodStart = RegExp(
    '(Future<[^>]*(?:<[^>]*>)?[^>]*>|void|Map<String, dynamic>)\\s+$methodName\\s*\\(',
  ).firstMatch(source);

  if (methodStart == null) return null;

  final startIndex = methodStart.start;
  int braceIndex = startIndex;
  int parenCount = 0;
  bool foundMethodBrace = false;

  for (int i = startIndex; i < source.length && !foundMethodBrace; i++) {
    final char = source[i];
    if (char == '(' || char == '{' && parenCount > 0) {
      parenCount++;
    } else if (char == ')' || char == '}' && parenCount > 1) {
      parenCount--;
    } else if (char == '{' && parenCount == 0) {
      braceIndex = i;
      foundMethodBrace = true;
    }
  }

  if (!foundMethodBrace) return null;

  int braceCount = 0;
  int endIndex = braceIndex;

  for (int i = braceIndex; i < source.length; i++) {
    if (source[i] == '{') {
      braceCount++;
    } else if (source[i] == '}') {
      braceCount--;
      if (braceCount == 0) {
        endIndex = i + 1;
        break;
      }
    }
  }

  return source.substring(startIndex, endIndex);
}
