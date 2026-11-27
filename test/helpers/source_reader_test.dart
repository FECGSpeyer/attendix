import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_reader.dart';

void main() {
  group('readDartLibrary', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('source_reader_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('returns plain file contents when there are no part directives', () {
      final mainFile = File('${tempDir.path}/solo.dart')
        ..writeAsStringSync('void hello() {}\n');

      expect(readDartLibrary(mainFile.path), 'void hello() {}\n');
    });

    test('appends non-generated part files and ignores part-of and generated parts', () {
      File('${tempDir.path}/lib_a.dart').writeAsStringSync(
        "part of 'root.dart';\nconst fromA = 'alpha';\n",
      );
      File('${tempDir.path}/lib_b.dart').writeAsStringSync(
        "part of 'root.dart';\nconst fromB = 'beta';\n",
      );
      File('${tempDir.path}/root.g.dart').writeAsStringSync(
        "part of 'root.dart';\nconst generatedMarker = 'gen';\n",
      );
      File('${tempDir.path}/root.freezed.dart').writeAsStringSync(
        "part of 'root.dart';\nconst freezedMarker = 'frz';\n",
      );
      final rootFile = File('${tempDir.path}/root.dart')
        ..writeAsStringSync(
          "part 'root.g.dart';\n"
          "part 'root.freezed.dart';\n"
          "part 'lib_a.dart';\n"
          "part \"lib_b.dart\";\n"
          "const fromRoot = 'root';\n",
        );

      final combined = readDartLibrary(rootFile.path);
      expect(combined, contains("const fromRoot = 'root';"));
      expect(combined, contains("const fromA = 'alpha';"));
      expect(combined, contains("const fromB = 'beta';"));
      expect(combined, isNot(contains('generatedMarker')));
      expect(combined, isNot(contains('freezedMarker')));

      final withGenerated = readDartLibrary(
        rootFile.path,
        includeGeneratedParts: true,
      );
      expect(withGenerated, contains('generatedMarker'));
      expect(withGenerated, contains('freezedMarker'));
    });

    test('includes all parts of an actual modularized library in lib/', () {
      final combined = readDartLibrary(
        'lib/features/planning/presentation/pages/planning_page.dart',
      );
      expect(combined, contains('planning_page_beta.dart'));
      expect(combined, contains('planning_page_beta_timeline.dart'));
      expect(combined, contains('planning_page_beta_actions.dart'));
    });
  });
}
