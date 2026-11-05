// MIGRATION: safety worker for browsers that still run the Ionic web app's
// Angular service worker (registered as /ngsw-worker.js with scope /).
//
// That worker serves its cached Ionic build for every navigation, so after
// attendix.de switches to Flutter an installed Ionic PWA would keep starting
// the old app. The browser re-fetches /ngsw-worker.js on navigations; it gets
// this script, which takes over, deletes the Angular caches, unregisters
// itself and reloads the open Ionic pages once, so they load the Flutter app
// from the network (Flutter then registers its own worker). Same approach as
// Angular's safety-worker.js. The Flutter app never registers this file.
self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil((async function () {
    await self.clients.claim();
    var names = await caches.keys();
    await Promise.all(names
      .filter(function (name) { return /^ngsw:/.test(name); })
      .map(function (name) { return caches.delete(name); }));
    // A Flutter page may have registered flutter_service_worker.js on the
    // same scope meanwhile: that newer worker replaces this one, so keep the
    // registration instead of unregistering it with the new worker.
    var reg = self.registration;
    if (!reg.installing && !reg.waiting) await reg.unregister();
    var windows = await self.clients.matchAll({ type: 'window' });
    windows.forEach(function (client) {
      // Only the old Ionic pages (path routes; Flutter uses #/ routes): their
      // lazy chunks are gone with the cache, so load the new app right away.
      if (new URL(client.url).hash.indexOf('#/') === 0) return;
      client.navigate(client.url).catch(function () {});
    });
  })());
});
