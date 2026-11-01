// PWA_SW: writes Attendix's own service worker into a `flutter build web`
// output (Flutter 3.47 only ships a self-unregistering worker).
//
//   dart run tool/web/write_service_worker.dart build/web
//
// Replaces build/web/flutter_service_worker.js with
// tool/web/service_worker_template.js and fills its RESOURCES map with the
// md5 of every built file. Dotfiles (assets/.env.app) are included on
// purpose: Flutter's old worker skipped them, which broke the offline start.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _placeholder = '/*RESOURCES*/{}';

/// Files that are never requested by the app.
bool isSkipped(String path) =>
    path == 'flutter_service_worker.js' ||
    path == '_headers' ||
    path == '.last_build_id' ||
    path.endsWith('.symbols') ||
    path == 'assets/NOTICES';

String buildServiceWorker(String template, Map<String, String> resources) {
  if (!template.contains(_placeholder)) {
    throw StateError('Template has no $_placeholder');
  }
  final sorted = Map.fromEntries(
      resources.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  return template.replaceFirst(_placeholder, jsonEncode(sorted));
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
    result[path] = md5.convert(entity.readAsBytesSync()).toString();
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
