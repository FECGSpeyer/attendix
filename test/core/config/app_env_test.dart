// PWA_OFFLINE: .env.app is kept in local storage on web so an installed PWA
// starts offline (Flutter's service worker never caches dotfiles).
import 'package:attendix/core/config/app_env.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.text);
  final String? text;

  @override
  Future<ByteData> load(String key) async {
    if (text == null) throw Exception('offline');
    return ByteData.sublistView(Uint8List.fromList(text!.codeUnits));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (text == null) throw Exception('offline');
    return text!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(fileInput: '');
  });

  test('web: loads the asset and keeps a copy', () async {
    await loadAppEnv(bundle: _Bundle("SUPABASE_URL=https://x.supabase.co\nDEMO_PASSWORD='a#b'"), web: true);
    expect(dotenv.get('SUPABASE_URL'), 'https://x.supabase.co');
    expect(dotenv.get('DEMO_PASSWORD'), 'a#b');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(appEnvCacheKey), contains('SUPABASE_URL'));
  });

  test('web offline: falls back to the stored copy', () async {
    SharedPreferences.setMockInitialValues({
      appEnvCacheKey: "SUPABASE_URL=https://x.supabase.co\nDEMO_PASSWORD='a#b'",
    });
    await loadAppEnv(bundle: _Bundle(null), web: true);
    expect(dotenv.isInitialized, isTrue);
    expect(dotenv.get('SUPABASE_URL'), 'https://x.supabase.co');
    expect(dotenv.get('DEMO_PASSWORD'), 'a#b');
  });

  test('native: no copy is stored', () async {
    await loadAppEnv(bundle: _Bundle('SUPABASE_URL=https://x.supabase.co'), web: false);
    expect(dotenv.get('SUPABASE_URL'), 'https://x.supabase.co');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(appEnvCacheKey), isNull);
  });
}
