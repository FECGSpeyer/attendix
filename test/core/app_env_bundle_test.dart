// The app bundles only .env.app (client keys). A developer's .env may hold
// SUPABASE_SERVICE_ROLE_KEY and must never be a pubspec asset again.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only .env.app is bundled and loaded', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(RegExp(r'^\s*-\s*\.env\s*$', multiLine: true).hasMatch(pubspec), isFalse);
    expect(pubspec, contains('- .env.app'));
    expect(File('lib/main.dart').readAsStringSync(), contains('await loadAppEnv();'));
    expect(File('lib/core/config/app_env.dart').readAsStringSync(),
        contains("const appEnvFileName = '.env.app';"));
  });

  test('write_app_env.sh never copies the service role key', () {
    final script = File('tool/write_app_env.sh').readAsStringSync();
    expect(script, contains('SUPABASE_URL|SUPABASE_ANON_KEY|DEMO_EMAIL|DEMO_PASSWORD'));
    expect(script, isNot(contains('SERVICE_ROLE_KEY|')));
  });
}
