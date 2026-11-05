import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('probe: invalidate dependency watched via .future', () async {
    var n = 0;
    final a = FutureProvider<int>((ref) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return ++n;
    });
    final b = FutureProvider<int>((ref) async => ref.watch(a.future));
    final c = ProviderContainer();
    final states = <AsyncValue<int>>[];
    c.listen(b, (_, s) => states.add(s), fireImmediately: true);
    await c.read(b.future);
    states.clear();
    c.invalidate(a);
    c.invalidate(b);
    await c.read(b.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    for (final s in states) {
      // ignore: avoid_print
      print('PROBE ${s.runtimeType} loading=${s.isLoading} '
          'reloading=${s.isReloading} refreshing=${s.isRefreshing} '
          'value=${s.valueOrNull} when=${s.when(data: (_) => 'data', error: (_, __) => 'error', loading: () => 'loading')}');
    }
  });
}
