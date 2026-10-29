import 'dart:js_interop';

@JS('Intl.DateTimeFormat')
external _DateTimeFormat _dateTimeFormat();

extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external _ResolvedOptions resolvedOptions();
}

extension type _ResolvedOptions._(JSObject _) implements JSObject {
  external JSString? get timeZone;
}

/// Browser IANA timezone (e.g. `Europe/Berlin`), or null if unavailable.
String? deviceTimezone() {
  try {
    final zone = _dateTimeFormat().resolvedOptions().timeZone?.toDart;
    return (zone == null || zone.isEmpty) ? null : zone;
  } catch (_) {
    return null;
  }
}
