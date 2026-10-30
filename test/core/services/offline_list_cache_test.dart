import 'package:attendix/core/services/attendance_detail_cache.dart';
import 'package:attendix/core/services/offline_list_cache.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool online;
  late String? userId;

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      connectivityCheckProvider.overrideWithValue(() async => online),
      offlineQueueUserIdProvider.overrideWithValue(() => userId),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  final refProvider = Provider((ref) => ref);

  Future<List<String>> read(ProviderContainer c, Future<List<String>> Function() fetch) =>
      OfflineListCache.read<String>(
        c.read(refProvider),
        tenantId: 42,
        part: 'players',
        fetch: fetch,
        toJson: (s) => {'name': s},
        fromJson: (j) => j['name'] as String,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    online = true;
    userId = 'u1';
  });

  test('offline: the last loaded list is returned', () async {
    final c = container();
    expect(await read(c, () async => ['Anna', 'Ben']), ['Anna', 'Ben']);

    online = false;
    expect(await read(c, () async => throw StateError('no network')), ['Anna', 'Ben']);
  });

  test('fresh results come back unchanged, not rebuilt from JSON', () async {
    final c = container();
    final fresh = ['Anna', 'Ben'];
    final result = await OfflineListCache.read<String>(
      c.read(refProvider),
      tenantId: 42,
      part: 'players',
      fetch: () async => fresh,
      // A lossy round trip: only the offline copy may go through it.
      toJson: (s) => {'name': s.substring(0, 1)},
      fromJson: (j) => j['name'] as String,
    );
    expect(identical(result, fresh), isTrue);
  });

  test('network error while online falls back to the copy', () async {
    final c = container();
    await read(c, () async => ['Anna']);
    expect(await read(c, () async => throw Exception('SocketException: Failed host lookup')), ['Anna']);
  });

  test('sign-out clears the copy', () async {
    final c = container();
    await read(c, () async => ['Anna']);
    await clearOfflineReadCaches();
    online = false;
    await expectLater(read(c, () async => throw Exception('SocketException')), throwsException);
  });

  test('no signed-in user: nothing is cached', () async {
    userId = null;
    final c = container();
    await read(c, () async => ['Anna']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith(OfflineListCache.prefix)), isEmpty);
  });
}
