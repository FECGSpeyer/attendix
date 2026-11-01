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
// - A new worker fills its cache completely while installing: unchanged
//   files are copied from the previous cache, changed ones are downloaded
//   again. If that fails, the install fails and the old worker (with its
//   complete cache) stays.
// - No skipWaiting on install: the new worker takes over only when the app
//   is closed, or when the user taps "Aktualisieren" (web/index.html posts
//   'skipWaiting' and reloads). A running page never switches versions.
//
// Requests:
// - Navigations (index.html): network first, cache as fallback (offline).
//   index.html only names fixed file names, so it is not version-bound.
// - Other files of the build: cache first, filled on first use; the page
//   also posts the files it loaded before ('cache-urls', web/index.html), so
//   the very first visit is enough for an offline start.

const VERSION = /*VERSION*/'';
const RESOURCES = /*RESOURCES*/{};
const CACHE_PREFIX = 'attendix-app-cache-';
const CACHE_NAME = CACHE_PREFIX + VERSION;
const INDEX = './';

self.addEventListener('install', (event) => {
  event.waitUntil(fillCache());
});

/** Builds this deploy's cache from the previous one; rejects on failure. */
async function fillCache() {
  const cache = await caches.open(CACHE_NAME);
  const origin = self.location.origin;
  await cache.add(new Request(INDEX, { cache: 'reload' }));
  for (const name of await caches.keys()) {
    if (!name.startsWith(CACHE_PREFIX) || name === CACHE_NAME) continue;
    const old = await caches.open(name);
    for (const request of await old.keys()) {
      const key = keyFor(request.url, origin);
      if (key == null || key === '/' || !RESOURCES[key]) continue;
      if (await cache.match(key)) continue;
      const response = await old.match(request);
      if (response && (await matchesHash(response.clone(), key))) {
        await cache.put(key, response);
      } else {
        // Changed in this deploy: download it now, so the cache is complete
        // before this worker takes over (throws, and fails the install,
        // when the file is unreachable or already from a newer deploy).
        await fetchVerified(cache, key, true);
      }
    }
  }
}

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      const ours = name.startsWith(CACHE_PREFIX) || name === 'attendix-app-cache' ||
        name === 'attendix-app-manifest';
      // Older Attendix deploys and Flutter's old worker caches.
      const flutter = name === 'flutter-app-cache' || name === 'flutter-temp-cache' ||
        name === 'flutter-app-manifest';
      if ((ours && name !== CACHE_NAME) || flutter) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

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

/** Fetches [key] and stores it only if it is this deploy's version. */
async function fetchVerified(cache, key, required) {
  const response = await fetch(new Request(key, { cache: 'no-cache' }));
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
  if (response && response.ok && response.type === 'basic') {
    const copy = response.clone();
    // The page gets the file at once; hashing and storing run afterwards.
    event.waitUntil((async () => {
      if (await matchesHash(copy.clone(), key)) await cache.put(key, copy);
    })().catch(() => {}));
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
      await fetchVerified(cache, key, false);
    } catch (e) {
      // Offline: the file is cached on its next use.
    }
  }
}
