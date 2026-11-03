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
    await self.registration.unregister();
    var windows = await self.clients.matchAll({ type: 'window' });
    windows.forEach(function (client) {
      // The pages still run the old Ionic app, whose lazy chunks are gone
      // with the cache: reload them into the new app right away.
      client.navigate(client.url).catch(function () {});
    });
  })());
});
