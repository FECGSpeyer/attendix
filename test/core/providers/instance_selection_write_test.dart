import 'dart:async';

import 'package:attendix/core/providers/user_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every write; each write waits for its completer.
class _Prefs extends UserPreferencesNotifier {
  final writes = <bool>[];
  final pending = <Completer<void>>[];

  @override
  Future<void> updatePreferences({
    int? currentTenantId,
    bool? wantInstanceSelection,
  }) {
    writes.add(wantInstanceSelection!);
    final c = Completer<void>();
    pending.add(c);
    return c.future;
  }
}

void main() {
  late ProviderContainer container;
  late _Prefs prefs;

  setUp(() {
    prefs = _Prefs();
    container = ProviderContainer(overrides: [
      userPreferencesNotifierProvider.overrideWith(() => prefs),
    ]);
    container.read(userPreferencesNotifierProvider);
  });

  tearDown(() => container.dispose());

  UserPreferencesNotifier notifier() =>
      container.read(userPreferencesNotifierProvider.notifier);
  bool? wanted() => container.read(wantedInstanceSelectionProvider);

  test('serializes writes and writes the latest wanted value once', () async {
    // Toggles from different widget instances (sheet closed and reopened)
    // share the one write loop in the notifier.
    final first = notifier().setWantInstanceSelection(true);
    final second = notifier().setWantInstanceSelection(false);
    final third = notifier().setWantInstanceSelection(true);
    final fourth = notifier().setWantInstanceSelection(false);
    expect(identical(first, fourth), isTrue);
    expect(identical(second, third), isTrue);
    expect(prefs.writes, [true]);
    expect(wanted(), isFalse);

    prefs.pending[0].complete();
    await pumpEventQueue();
    expect(prefs.writes, [true, false]);

    prefs.pending[1].complete();
    await first;
    expect(prefs.writes, [true, false]);
    expect(wanted(), isNull);
  });

  test('no second write when the latest wanted value was written', () async {
    final write = notifier().setWantInstanceSelection(true);
    notifier().setWantInstanceSelection(false);
    notifier().setWantInstanceSelection(true);
    prefs.pending[0].complete();
    await write;
    expect(prefs.writes, [true]);
    expect(wanted(), isNull);
  });

  test('failure: future throws, wanted value is reset, next write starts anew',
      () async {
    final write = notifier().setWantInstanceSelection(true);
    prefs.pending[0].completeError(Exception('offline'));
    await expectLater(write, throwsException);
    expect(wanted(), isNull);

    final next = notifier().setWantInstanceSelection(false);
    expect(identical(next, write), isFalse);
    expect(prefs.writes, [true, false]);
    prefs.pending[1].complete();
    await next;
  });
}
