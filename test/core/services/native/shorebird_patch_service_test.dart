import 'package:attendix/core/providers/shorebird_providers.dart';
import 'package:attendix/core/services/native/native_platform.dart';
import 'package:attendix/core/services/native/shorebird_patch_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => debugIsNativeAppOverride = null);

  test('Nicht-Shorebird-Build: keine Patch-Nummer, Version unverändert', () async {
    // Pretend to be the native app so the real updater is asked; this test
    // binary has no Shorebird engine, so it must report "no patch".
    debugIsNativeAppOverride = true;
    final patch = await readShorebirdPatchNumber();
    expect(patch, isNull);
    expect(appVersionLabel(patch), appVersionLabel(null));
    expect(appVersionLabel(2), endsWith(' (Patch 2)'));
  });
}
