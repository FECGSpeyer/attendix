'use strict';
// PWA_SW: Attendix service worker (offline start like the Ionic PWA).
//
// Flutter 3.47 ships a service worker that only unregisters itself, so the
// installed PWA would lose its offline start. tool/web/write_service_worker.dart
// writes this file to build/web/flutter_service_worker.js after
// `flutter build web` (same URL as before, so existing installs update in
// place) and fills in RESOURCES (path -> md5 of every built file).
//
// - Navigations (index.html): network first, cache as fallback (offline).
// - Other files of the build: cache first, filled on first use.
// - The page posts the files it loaded before this worker controlled it
//   ('cache-urls', web/index.html), so the very first visit is enough for an
//   offline start.
// - A new deploy changes RESOURCES, so the browser installs a new worker;
//   changed files are dropped, unchanged ones stay cached.

const CACHE_NAME = 'attendix-app-cache';
const MANIFEST = 'attendix-app-manifest';
const RESOURCES = /*RESOURCES*/{};

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.add(new Request('./', { cache: 'reload' })))
      .catch((e) => console.warn('[SW] precache failed', e)),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      const contentCache = await caches.open(CACHE_NAME);
      const manifestCache = await caches.open(MANIFEST);
      const oldResponse = await manifestCache.match('manifest');
      const oldManifest = oldResponse ? await oldResponse.json() : {};
      const origin = self.location.origin;
      for (const request of await contentCache.keys()) {
        const key = keyFor(request.url, origin);
        if (key === '/') continue; // refreshed on every online navigation
        if (key == null || !RESOURCES[key] || RESOURCES[key] !== oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Old Flutter worker caches are no longer used.
      await caches.delete('flutter-app-cache');
      await caches.delete('flutter-temp-cache');
      await caches.delete('flutter-app-manifest');
    } catch (e) {
      console.error('[SW] activate failed', e);
      await caches.delete(CACHE_NAME);
      await caches.delete(MANIFEST);
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

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const origin = self.location.origin;
  if (request.mode === 'navigate') {
    // Hash routing: every app navigation is index.html (any query, e.g. ?mode=ios).
    if (!request.url.startsWith(origin)) return;
    const key = keyFor(request.url, origin);
    if (key !== '/') return;
    event.respondWith(onlineFirst(request));
    return;
  }
  const key = keyFor(request.url, origin);
  if (key == null || key === '/' || !RESOURCES[key]) return;
  event.respondWith(cacheFirst(request, key));
});

async function onlineFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  try {
    const response = await fetch(request);
    if (response && response.ok) await cache.put('./', response.clone());
    return response;
  } catch (e) {
    const cached = await cache.match('./');
    if (cached) return cached;
    throw e;
  }
}

async function cacheFirst(request, key) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(key);
  if (cached) return cached;
  const response = await fetch(request);
  if (response && response.ok && response.type === 'basic') {
    await cache.put(key, response.clone());
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
      const response = await fetch(key);
      if (response && response.ok) await cache.put(key, response);
    } catch (e) {
      // Offline or a newer deploy: the file is cached on its next use.
    }
  }
}
