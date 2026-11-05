import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class N extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);
  Future<bool> run() async {
    state = const AsyncValue.loading();
    try {
      await Future<void>.delayed(Duration.zero);
      state = const AsyncValue.data(null);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final nProvider = NotifierProvider<N, AsyncValue<void>>(N.new);
Object? caught;

class Child extends ConsumerStatefulWidget {
  const Child({super.key});
  @override
  ConsumerState<Child> createState() => _ChildState();
}

class _ChildState extends ConsumerState<Child> {
  late final N n;
  @override
  void initState() {
    super.initState();
    n = ref.read(nProvider.notifier);
  }

  @override
  void dispose() {
    n.run().then((v) => caught = 'ok $v', onError: (Object e) => caught = e);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class Watcher extends ConsumerWidget {
  const Watcher({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(nProvider);
    return const SizedBox();
  }
}

void main() {
  testWidgets('modify provider from dispose', (tester) async {
    final show = ValueNotifier(true);
    await tester.pumpWidget(ProviderScope(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [
          const Watcher(),
          ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, s, __) => s ? const Child() : const SizedBox(),
          ),
        ]),
      ),
    ));
    show.value = false;
    await tester.pump();
    await tester.pump();
    // ignore: avoid_print
    print('RESULT: $caught');
  });
}
