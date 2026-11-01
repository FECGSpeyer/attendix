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
    // sha256 hex, the same digest the worker computes with crypto.subtle.
    expect(resources['index.html'],
        'b7d082ee12e91b756ea22e8513b8594eebcf5d39fab813da3cb55794dc888ad7');
  });

  test('fills the template', () {
    final template = File('tool/web/service_worker_template.js').readAsStringSync();
    final sw = buildServiceWorker(template, {'b.js': '2', 'a.js': '1'});
    expect(sw, contains('const RESOURCES = {"a.js":"1","b.js":"2"};'));
    expect(sw, isNot(contains('/*RESOURCES*/')));
    expect(sw, isNot(contains('/*VERSION*/')));
    final version = RegExp(r"const VERSION = '([0-9a-f]{16})';").firstMatch(sw);
    expect(version, isNotNull);
    // Same cache name the deploy workflow checks for.
    expect(sw, contains("'attendix-app-cache-'"));
    // A changed file gives the deploy a new cache.
    final next = buildServiceWorker(template, {'b.js': '3', 'a.js': '1'});
    expect(next, isNot(contains("const VERSION = '${version!.group(1)}';")));
    // So does a change of the worker alone (SOL #272): a failed install of
    // the new worker never shares, and deletes, the active worker's cache.
    final newWorker =
        buildServiceWorker('$template\n// changed', {'b.js': '2', 'a.js': '1'});
    expect(newWorker, isNot(contains("const VERSION = '${version.group(1)}';")));
    // The same input gives the same name.
    expect(buildServiceWorker(template, {'a.js': '1', 'b.js': '2'}),
        contains("const VERSION = '${version.group(1)}';"));
  });

  test('template keeps the update flow and the offline fallback', () {
    final template = File('tool/web/service_worker_template.js').readAsStringSync();
    expect(template, contains("request.mode === 'navigate'"));
    expect(template, contains("'cache-urls'"));
    // SOL (#272): a new deploy only takes over when asked (or the app is
    // closed), never in the middle of a running page.
    final install = RegExp(r"addEventListener\('install'[\s\S]*?\}\);")
        .firstMatch(template)!
        .group(0)!;
    expect(install, isNot(contains('skipWaiting')));
    expect(template, contains("if (data === 'skipWaiting')"));
    // Only files of this deploy are stored.
    expect(template, contains("crypto.subtle.digest('SHA-256'"));
    // Install waits for the page's file list (else the start set of this
    // browser), marks a finished cache and deletes a failed one; a file of
    // another deploy triggers an update check. Behaviour:
    // tool/web/test/sw_behavior.test.mjs.
    expect(template, contains('receiveList(data.urls)'));
    expect(template, contains('for (const key of startSet()) needed.add(key);'));
    expect(template, contains('await cache.put(COMPLETE, new Response(VERSION));'));
    expect(template, contains('if (!(await old.match(COMPLETE))) continue;'));
    expect(template, contains('await caches.delete(CACHE_NAME);'));
    // The app page is checked as well, at install and on navigation.
    expect(template, contains("matchesHash(index.clone(), 'index.html')"));
    expect(template, contains("matchesHash(response.clone(), 'index.html')"));
    expect(template, contains('self.registration.update()'));
  });

  test('index.html registers the worker outside iframes after the first frame', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains("var swUrl = 'flutter_service' + '_worker.js';"));
    expect(html, contains('navigator.serviceWorker.register(swUrl)'));
    expect(html, contains('!window.attendixInIframe'));
    expect(html, contains("type: 'cache-urls'"));
    // "Aktualisieren" lets the waiting worker take over before reloading.
    expect(html, contains("registration.waiting.postMessage('skipWaiting')"));
    expect(html, contains('registration.waiting && navigator.serviceWorker.controller'));
    // A worker that is already installing when the page starts is watched.
    expect(html, contains('watchInstalling(registration.installing);'));
    // Every tab that ran the previous deploy reloads after the switch.
    expect(html, contains('if (userRequestedUpdate || hadController)'));
    // The installing worker gets the list too.
    expect(html, contains('postUrls(registration.installing);'));
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    expect(bootstrap, isNot(contains('serviceWorkerSettings')));
    expect(bootstrap, contains('wasmAllowList'));
  });
}
