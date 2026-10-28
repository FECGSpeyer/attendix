{{flutter_js}}
{{flutter_build_config}}

// TEAMS: same as Flutter's default bootstrap, except that the service worker
// is not registered when the app is framed (Microsoft Teams tab). The SW would
// cache index.html across deploys inside Teams (Ionic disables it there too).
// window.attendixInIframe is set by web/index.html.
_flutter.loader.load(window.attendixInIframe ? {} : {
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});
