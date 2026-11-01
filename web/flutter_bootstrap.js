{{flutter_js}}
{{flutter_build_config}}

// PWA_WASM: the build has a WebAssembly (skwasm) and a JavaScript (CanvasKit)
// variant; Flutter's loader picks WebAssembly for Chrome/Edge and JavaScript
// elsewhere. Safari gets WebAssembly too from 26.2 on (window.attendixSafariWasm,
// set in web/index.html), the version Flutter's docs name for WebKit support.
//
// PWA_SW: the service worker is no longer registered here (Flutter 3.47's
// loader would wait for it before starting the app); web/index.html
// registers Attendix's own worker after the first frame, never inside an
// iframe (Microsoft Teams tab).
_flutter.loader.load({
  config: {
    wasmAllowList: { webkit: window.attendixSafariWasm === true },
  },
});
