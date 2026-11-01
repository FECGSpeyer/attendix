'use strict';
// PWA_SW: Attendix service worker (offline start like the Ionic PWA).
//
// Flutter 3.47 ships a service worker that only unregisters itself, so the
// installed PWA would lose its offline start. tool/web/write_service_worker.dart
// writes this file to build/web/flutter_service_worker.js after
// `flutter build web` (same URL as before, so existing installs update in
// place) and fills in VERSION and RESOURCES (path -> sha256 of every built
// file).
//
// SOL (#272): no mixing of two deploys.
// - Every deploy has its own cache (CACHE_PREFIX + VERSION).
// - A file is only stored when its sha256 matches RESOURCES, so a request
//   that reaches a newer deploy never lands in this deploy's cache.
// - Install only succeeds with a complete cache: the app page plus every
//   file the open page needs to start (web/index.html posts its list,
//   including the engine files of this browser's variant) and every file of
//   the previous complete Attendix cache. Without either (e.g. only a tab of
//   the Flutter 3.29 deploy is open, which posts no list), it installs the
//   start set: every file except the engine files, plus the engine files of
//   this browser's variant (same checks as web/index.html). Unchanged files
//   are copied, changed ones downloaded and checked. Anything missing fails
//   the install; its cache is deleted, and the old worker with its complete
//   cache stays.
// - A cache counts as complete only with the marker that a finished install
//   writes last, so a cache left by an interrupted install never stands in
//   for a complete one.
// - No skipWaiting on install: the new worker takes over when the app is
//   closed, or when it starts again as its only window (a reload; the page
//   asks with 'activate-if-alone' before the app starts), or when the user
//   taps "Update installieren"; then every open tab reloads (activate navigates them;
//   web/index.html also reloads on controllerchange), so no page keeps
//   running old code under the new worker. PWA_UPDATE: never while the app
//   is in use.
// - A cache miss that the network answers with another deploy's file still
//   reaches the page (no other copy exists), but triggers an update check,
//   so the page offers "Aktualisieren".
//
// - The app page (index.html) is checked like every other file: it picks
//   the engine variant (e.g. WebAssembly in Safari 26.2+), so a page of
//   another deploy could ask for files this cache does not hold.
//
// Requests:
// - Navigations (index.html): network first, cache as fallback (offline).
//   A page of another deploy is not stored and not shown; the page of this
//   version is, and the new worker is looked for ("Aktualisieren").
// - Other files of the build: cache first, filled on first use.

const VERSION = /*VERSION*/'';
const RESOURCES = /*RESOURCES*/{};
const CACHE_PREFIX = 'attendix-app-cache-';
const CACHE_NAME = CACHE_PREFIX + VERSION;
const INDEX = './';
// Written last by a finished install (not a build file, never served).
const COMPLETE = './attendix-cache-complete';
// How long an install waits for the page's file list.
const LIST_WAIT_WITH_PREVIOUS_MS = 5000;
const LIST_WAIT_FIRST_MS = 60000;

let installing = false;
let receiveList = null;
const pageList = new Promise((resolve) => { receiveList = resolve; });

self.addEventListener('install', (event) => {
  installing = true;
  event.waitUntil(fillCache().finally(() => { installing = false; }));
});

/** Builds this deploy's complete cache; rejects when that is not possible. */
async function fillCache() {
  try {
    await fill();
  } catch (e) {
    // SOL (#272): no half-filled cache stays behind.
    await caches.delete(CACHE_NAME);
    throw e;
  }
}

async function fill() {
  const cache = await caches.open(CACHE_NAME);
  const origin = self.location.origin;
  const index = await fetch(new Request(INDEX, { cache: 'reload' }));
  if (!index.ok || !(await matchesHash(index.clone(), 'index.html'))) {
    throw new Error('[SW] index.html is not this deploy\'s version');
  }
  await cache.put(INDEX, index);
  // Files the device used with the previous deploy(s): only complete caches.
  const previous = new Set();
  for (const name of await caches.keys()) {
    if (!name.startsWith(CACHE_PREFIX) || name === CACHE_NAME) continue;
    const old = await caches.open(name);
    if (!(await old.match(COMPLETE))) continue;
    for (const request of await old.keys()) {
      const key = keyFor(request.url, origin);
      if (key == null || key === '/' || !RESOURCES[key]) continue;
      previous.add(key);
      if (await cache.match(key)) continue;
      const response = await old.match(request);
      if (response && (await matchesHash(response.clone(), key))) {
        await cache.put(key, response);
      }
    }
  }
  // Files the open page needs (posted by web/index.html).
  const urls = await Promise.race([
    pageList,
    new Promise((resolve) => setTimeout(() => resolve(null),
      previous.size ? LIST_WAIT_WITH_PREVIOUS_MS : LIST_WAIT_FIRST_MS)),
  ]);
  const needed = new Set(previous);
  for (const url of urls || []) {
    const key = keyFor(String(url), origin);
    if (key != null && key !== '/' && RESOURCES[key]) needed.add(key);
  }
  if (!urls && !previous.size) {
    for (const key of startSet()) needed.add(key);
  }
  for (const key of needed) {
    if (await cache.match(key)) continue;
    // Throws, and fails the install, when the file is unreachable or
    // already from a newer deploy.
    await fetchVerified(cache, key, true, 'no-cache');
  }
  await cache.put(COMPLETE, new Response(VERSION));
}

/** Files only one engine variant loads (app code, CanvasKit, skwasm). */
function isEngineFile(key) {
  return key.startsWith('canvaskit/') || key.startsWith('main.dart.');
}

/**
 * Every file needed to start offline without a list from the page: all
 * files except the engine files, plus those of the variant Flutter's loader
 * picks in this browser.
 */
function startSet() {
  const keys = Object.keys(RESOURCES).filter((key) => key !== '/' &&
    key !== 'index.html' && !isEngineFile(key));
  for (const key of engineFiles()) {
    if (RESOURCES[key]) keys.push(key);
  }
  return keys;
}

/**
 * The engine files of this browser's variant. SOL (#272): keep in sync with
 * PWA_WASM in web/index.html (tool/web/test/sw_behavior.test.mjs compares
 * both). A worker has no navigator.vendor and no ImageDecoder, so the engine
 * comes from the user agent, and Blink (Chrome 94+) counts as having
 * ImageDecoder, as it does in the page.
 */
function engineFiles() {
  const ua = (self.navigator && self.navigator.userAgent) || '';
  const engine = /Chrome\/|Edg\//.test(ua) ? 'blink'
    : /AppleWebKit\//.test(ua) ? 'webkit' : 'other';
  let safariWasm = false;
  if (engine === 'webkit') {
    const m = /Version\/(\d+)\.(\d+)/.exec(ua);
    safariWasm = !!m && (+m[1] > 26 || (+m[1] === 26 && +m[2] >= 2));
  }
  let wasmGC = false;
  try {
    wasmGC = WebAssembly.validate(new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0, 1, 5, 1, 95, 1, 120, 0]));
  } catch (e) {}
  const codecs = engine === 'blink';
  const breakIterators = typeof Intl.v8BreakIterator !== 'undefined' &&
    typeof Intl.Segmenter !== 'undefined';
  if (wasmGC && (engine === 'blink' || safariWasm)) {
    const skwasm = codecs && breakIterators ? 'canvaskit/skwasm' : 'canvaskit/skwasm_heavy';
    return ['main.dart.wasm', 'main.dart.mjs', skwasm + '.js', skwasm + '.wasm'];
  }
  const canvaskit = codecs && breakIterators ? 'canvaskit/chromium/canvaskit' : 'canvaskit/canvaskit';
  return ['main.dart.js', canvaskit + '.js', canvaskit + '.wasm'];
}

self.addEventListener('activate', (event) => {
  event.waitUntil(activate());
});

async function activate() {
  // An older Attendix deploy or Flutter's old worker was here before: this
  // is an update, not the first visit.
  let update = false;
  for (const name of await caches.keys()) {
    const ours = name.startsWith(CACHE_PREFIX) || name === 'attendix-app-cache' ||
      name === 'attendix-app-manifest';
    const flutter = name === 'flutter-app-cache' || name === 'flutter-temp-cache' ||
      name === 'flutter-app-manifest';
    if ((ours && name !== CACHE_NAME) || flutter) {
      update = true;
      await caches.delete(name);
    }
  }
  await self.clients.claim();
  if (!update) return;
  // SOL (#272): every open tab still runs the previous deploy's code; reload
  // it into this one. Pages of this index.html reload on controllerchange as
  // well, but tabs of the Flutter 3.29 deploy only reload on their own
  // "Aktualisieren", so the worker does it for all of them.
  for (const client of await self.clients.matchAll({ type: 'window' })) {
    if (client.navigate) client.navigate(client.url).catch(() => {});
  }
}

/** Build-relative path of a same-origin URL ('/' for the app page). */
function keyFor(url, origin) {
  if (!url.startsWith(origin)) return null;
  let key = url.substring(origin.length + 1).split('#')[0].split('?')[0];
  if (key === '' || key === 'index.html') key = '/';
  return key;
}

async function sha256(response) {
  const digest = await crypto.subtle.digest('SHA-256', await response.arrayBuffer());
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

async function matchesHash(response, key) {
  try {
    return (await sha256(response)) === RESOURCES[key];
  } catch (e) {
    return false;
  }
}

/**
 * Fetches [key] and stores it only if it is this deploy's version.
 * [mode] 'default' takes the browser's HTTP cache copy of a file the page
 * just loaded (no second download); a wrong version is rejected by the hash.
 */
async function fetchVerified(cache, key, required, mode) {
  const response = await fetch(new Request(key, { cache: mode }));
  if (response && response.ok && (await matchesHash(response.clone(), key))) {
    await cache.put(key, response);
    return;
  }
  if (required) throw new Error('[SW] ' + key + ' is not this deploy\'s version');
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const origin = self.location.origin;
  if (request.mode === 'navigate') {
    // Hash routing: every app navigation is index.html (any query, e.g. ?mode=ios).
    if (keyFor(request.url, origin) !== '/') return;
    event.respondWith(onlineFirst(event));
    return;
  }
  const key = keyFor(request.url, origin);
  if (key == null || key === '/' || !RESOURCES[key]) return;
  event.respondWith(cacheFirst(event, key));
});

async function onlineFirst(event) {
  const cache = await caches.open(CACHE_NAME);
  let response;
  try {
    response = await fetch(event.request);
  } catch (e) {
    const cached = await cache.match(INDEX);
    if (cached) return cached;
    throw e;
  }
  if (!response || !response.ok) return response;
  if (await matchesHash(response.clone(), 'index.html')) {
    event.waitUntil(cache.put(INDEX, response.clone()).catch(() => {}));
    return response;
  }
  // SOL (#272): another deploy's page is online. This version's page goes
  // with this cache's files; the new worker is looked for and offered.
  event.waitUntil(self.registration.update().catch(() => {}));
  return (await cache.match(INDEX)) || response;
}

async function cacheFirst(event, key) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(key);
  if (cached) return cached;
  const response = await fetch(event.request);
  if (!response || !response.ok || response.type !== 'basic') return response;
  // Checked before it reaches the page: this deploy's file is stored; a file
  // of another deploy means a new version is online, so look for its worker
  // (the page then offers "Aktualisieren").
  if (await matchesHash(response.clone(), key)) {
    event.waitUntil(cache.put(key, response.clone()).catch(() => {}));
  } else {
    event.waitUntil(self.registration.update().catch(() => {}));
  }
  return response;
}

self.addEventListener('message', (event) => {
  const data = event.data;
  if (data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  // PWA_UPDATE: a page is starting while this worker waits. It may take
  // over only if that page is the app's only window (a restart); the page
  // then answers with 'skipWaiting' if it has not started yet. Any other
  // window, or a sender that is gone, keeps the update waiting (SOL #274).
  if (data && data.type === 'activate-if-alone') {
    const source = event.source;
    event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((windows) => {
        if (!source) return;
        const alone = windows.length === 1 && windows[0].id === source.id;
        source.postMessage({ type: alone ? 'alone' : 'stay' });
      }));
    return;
  }
  if (data && data.type === 'cache-urls' && Array.isArray(data.urls)) {
    if (installing) {
      receiveList(data.urls);
      return;
    }
    event.waitUntil(cacheUrls(data.urls));
  }
});

async function cacheUrls(urls) {
  const cache = await caches.open(CACHE_NAME);
  const origin = self.location.origin;
  for (const url of urls) {
    const key = keyFor(String(url), origin);
    if (key == null || key === '/' || !RESOURCES[key]) continue;
    if (await cache.match(key)) continue;
    try {
      await fetchVerified(cache, key, false, 'default');
    } catch (e) {
      // Offline: the file is cached on its next use.
    }
  }
}
