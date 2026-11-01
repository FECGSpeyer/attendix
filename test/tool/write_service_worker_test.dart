// PWA_SW: Attendix's own service worker replaces Flutter 3.47's
// self-unregistering one (tool/web/write_service_worker.dart).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/web/write_service_worker.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('sw_test');
    File('${dir.path}/index.html').writeAsStringSync('<html>');
    File('${dir.path}/main.dart.wasm').writeAsStringSync('wasm');
    File('${dir.path}/flutter_service_worker.js').writeAsStringSync('old');
    File('${dir.path}/_headers').writeAsStringSync('/*');
    Directory('${dir.path}/assets').createSync();
    File('${dir.path}/assets/.env.app').writeAsStringSync('SUPABASE_URL=x');
    File('${dir.path}/assets/NOTICES').writeAsStringSync('licences');
    Directory('${dir.path}/canvaskit').createSync();
    File('${dir.path}/canvaskit/skwasm.js.symbols').writeAsStringSync('s');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('includes dotfiles, skips the worker, headers and symbols', () {
    final resources = collectResources(dir);
    expect(resources.keys, containsAll(['index.html', 'main.dart.wasm', 'assets/.env.app']));
    expect(resources.keys, isNot(contains('flutter_service_worker.js')));
    expect(resources.keys, isNot(contains('_headers')));
    expect(resources.keys, isNot(contains('canvaskit/skwasm.js.symbols')));
    expect(resources.keys, isNot(contains('assets/NOTICES')));
    expect(resources['index.html'], hasLength(32));
  });

  test('fills the template', () {
    final template = File('tool/web/service_worker_template.js').readAsStringSync();
    final sw = buildServiceWorker(template, {'b.js': '2', 'a.js': '1'});
    expect(sw, contains('const RESOURCES = {"a.js":"1","b.js":"2"};'));
    expect(sw, isNot(contains('/*RESOURCES*/')));
    // Same cache name the deploy workflow checks for.
    expect(sw, contains("'attendix-app-cache'"));
  });

  test('template keeps the update flow and the offline fallback', () {
    final template = File('tool/web/service_worker_template.js').readAsStringSync();
    expect(template, contains('self.skipWaiting()'));
    expect(template, contains("request.mode === 'navigate'"));
    expect(template, contains("'cache-urls'"));
  });

  test('index.html registers the worker outside iframes after the first frame', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains("var swUrl = 'flutter_service' + '_worker.js';"));
    expect(html, contains('navigator.serviceWorker.register(swUrl)'));
    expect(html, contains('!window.attendixInIframe'));
    expect(html, contains("type: 'cache-urls'"));
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(bootstrap, isNot(contains('serviceWorkerSettings')));
    expect(bootstrap, contains('wasmAllowList'));
  });
}
