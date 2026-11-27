import 'dart:io';

/// Pattern matching top-level `part '...';` or `part "...";` directives
/// (ignoring `part of ...` directives).
final _partDirectivePattern = RegExp(
  r'''^\s*part\s+['"]([^'"]+)['"]\s*;''',
  multiLine: true,
);

/// Reads a Dart library file together with all of its non-generated `part`
/// files, concatenated in declaration order.
///
/// Use this in source-scanning security and parity tests so modularizing a
/// library into `part` files never causes checks to miss code moved into a
/// sibling part file. Generated files (`*.g.dart`, `*.freezed.dart`) are
/// skipped by default because they contain boilerplate rather than hand-written
/// logic.
String readDartLibrary(
  String path, {
  bool includeGeneratedParts = false,
}) {
  final root = File(path);
  final rootSource = root.readAsStringSync();
  if (!path.endsWith('.dart')) return rootSource;
  final partMatches = _partDirectivePattern.allMatches(rootSource).toList();
  if (partMatches.isEmpty) return rootSource;

  final dir = root.parent.path;
  final buffer = StringBuffer(rootSource);
  final seen = <String>{root.uri.normalizePath().toFilePath()};

  for (final match in partMatches) {
    final relativePart = match.group(1)!;
    if (!includeGeneratedParts &&
        (relativePart.endsWith('.g.dart') ||
            relativePart.endsWith('.freezed.dart'))) {
      continue;
    }
    final partFile = File(dir.isEmpty ? relativePart : '$dir/$relativePart');
    final normalized = partFile.uri.normalizePath().toFilePath();
    if (!seen.add(normalized) || !partFile.existsSync()) continue;
    buffer
      ..writeln()
      ..writeln('// --- part: $relativePart ---')
      ..write(partFile.readAsStringSync());
  }

  return buffer.toString();
}
