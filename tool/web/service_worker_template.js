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
//   including the engine files of this browser's variant), or, without such
//   a list, every file of the previous Attendix cache. Unchanged files are
//   copied, changed ones downloaded and checked. Anything missing fails the
//   install, and the old worker with its complete cache stays.
// - No skipWaiting on install: the new worker takes over when the app is
//   closed, or when the user taps "Aktualisieren"; then every open tab
//   reloads (activate navigates them; web/index.html also reloads on
//   controllerchange), so no page keeps running old code under the new
//   worker.
// - A cache miss that the network answers with another deploy's file still
//   reaches the page (no other copy exists), but triggers an update check,
//   so the page offers "Aktualisieren".
//
// Requests:
// - Navigations (index.html): network first, cache as fallback (offline).
//   index.html only names fixed file names, so it is not version-bound.
// - Other files of the build: cache first, filled on first use.

const VERSION = /*VERSION*/'';
const RESOURCES = /*RESOURCES*/{};
const CACHE_PREFIX = 'attendix-app-cache-';
const CACHE_NAME = CACHE_PREFIX + VERSION;
const INDEX = './';
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
  const cache = await caches.open(CACHE_NAME);
  const origin = self.location.origin;
  await cache.add(new Request(INDEX, { cache: 'reload' }));
  // Files the device used with the previous deploy(s).
  const previous = new Set();
  for (const name of await caches.keys()) {
    if (!name.startsWith(CACHE_PREFIX) || name === CACHE_NAME) continue;
    const old = await caches.open(name);
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
  if (!urls && !previous.size) throw new Error('[SW] no file list from the page');
  const needed = new Set(previous);
  for (const url of urls || []) {
    const key = keyFor(String(url), origin);
    if (key != null && key !== '/' && RESOURCES[key]) needed.add(key);
  }
  for (const key of needed) {
    if (await cache.match(key)) continue;
    // Throws, and fails the install, when the file is unreachable or
    // already from a newer deploy.
    await fetchVerified(cache, key, true, 'no-cache');
  }
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
    event.respondWith(onlineFirst(request));
    return;
  }
  const key = keyFor(request.url, origin);
  if (key == null || key === '/' || !RESOURCES[key]) return;
  event.respondWith(cacheFirst(event, key));
});

async function onlineFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  try {
    const response = await fetch(request);
    if (response && response.ok) await cache.put(INDEX, response.clone());
    return response;
  } catch (e) {
    const cached = await cache.match(INDEX);
    if (cached) return cached;
    throw e;
  }
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
