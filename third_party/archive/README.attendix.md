# archive 3.6.1 (Attendix patch)

Copy of [archive 3.6.1](https://pub.dev/packages/archive/versions/3.6.1)
(MIT, see LICENSE) used through `dependency_overrides` in the app's
`pubspec.yaml`.

**Why:** `excel` 4.0.6 (newest) requires `archive ^3.6.1`. archive 3.x
picks its pure-Dart web code with `if (dart.library.js)`, which does not
exist in WebAssembly builds (`flutter build web --wasm`). There it fell back
to a stub and every Excel export/import failed with
"inflateBuffer requires html or io".

**Patch:** in `lib/src/zlib/inflate_buffer.dart`, `lib/src/zlib_decoder.dart`
and `lib/src/util/crc64.dart` the condition is `dart.library.js_interop`
instead of `dart.library.js`. Nothing else changed.

**Remove** this folder and the override once `excel` supports archive 4.
