// PWA_SW: writes Attendix's own service worker into a `flutter build web`
// output (Flutter 3.47 only ships a self-unregistering worker).
//
//   dart run tool/web/write_service_worker.dart build/web
//
// Replaces build/web/flutter_service_worker.js with
// tool/web/service_worker_template.js and fills its RESOURCES map with the
// sha256 of every built file (the worker checks downloads against it) and
// VERSION, the name of this deploy's cache. Dotfiles (assets/.env.app) are
// included on purpose: Flutter's old worker skipped them, which broke the
// offline start.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _placeholder = '/*RESOURCES*/{}';
const _versionPlaceholder = "/*VERSION*/''";

/// Files that are never requested by the app.
bool isSkipped(String path) =>
    path == 'flutter_service_worker.js' ||
    path == '_headers' ||
    path == '.last_build_id' ||
    path.endsWith('.symbols') ||
    path == 'assets/NOTICES';

String buildServiceWorker(String template, Map<String, String> resources) {
  if (!template.contains(_placeholder) ||
      !template.contains(_versionPlaceholder)) {
    throw StateError('Template has no $_placeholder or $_versionPlaceholder');
  }
  final sorted = Map.fromEntries(
      resources.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  final json = jsonEncode(sorted);
  // Changes with every changed file, so each deploy gets its own cache.
  final version = sha256.convert(utf8.encode(json)).toString().substring(0, 16);
  return template
      .replaceFirst(_placeholder, json)
      .replaceFirst(_versionPlaceholder, "'$version'");
}

Map<String, String> collectResources(Directory buildDir) {
  final result = <String, String>{};
  final root = buildDir.absolute.path;
  for (final entity in buildDir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final path = entity.absolute.path
        .substring(root.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    if (isSkipped(path)) continue;
    result[path] = sha256.convert(entity.readAsBytesSync()).toString();
  }
  return result;
}

void main(List<String> args) {
  final buildDir = Directory(args.isEmpty ? 'build/web' : args.first);
  if (!buildDir.existsSync()) {
    stderr.writeln('No build output at ${buildDir.path}');
    exit(1);
  }
  // Run from the repository root (CI: after `flutter build web`).
  final templateFile = File('tool/web/service_worker_template.js');
  final resources = collectResources(buildDir);
  if (!resources.containsKey('index.html') ||
      !resources.containsKey('assets/.env.app')) {
    stderr.writeln('index.html or assets/.env.app missing in ${buildDir.path}');
    exit(1);
  }
  File('${buildDir.path}/flutter_service_worker.js').writeAsStringSync(
      buildServiceWorker(templateFile.readAsStringSync(), resources));
  stdout.writeln('flutter_service_worker.js: ${resources.length} files');
}
