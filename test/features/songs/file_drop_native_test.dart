import 'dart:io';

import 'package:attendix/features/songs/presentation/widgets/file_drop/file_drop_native.dart' show maxDroppedFileBytes;
import 'package:attendix/features/songs/presentation/widgets/file_drop/file_drop_target.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sends a desktop_drop platform event, as the macOS plugin does.
Future<void> _send(String method, Object? args) async {
  const codec = StandardMethodCodec();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    'desktop_drop',
    codec.encodeMethodCall(MethodCall(method, args)),
    (_) {},
  );
}

void main() {
  testWidgets('macOS app: files dragged from Finder onto the target are added', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dir = await tester.runAsync(() => Directory.systemTemp.createTemp('drop'));
    addTearDown(() => dir!.deleteSync(recursive: true));
    final file = File('${dir!.path}/Stimme 1.pdf');
    await tester.runAsync(() => file.writeAsBytes([1, 2, 3]));

    final dropped = <PlatformFile>[];
    await tester.pumpWidget(MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          height: 200,
          child: FileDropTarget(
            onFiles: dropped.addAll,
            builder: (context, hovering) => Text(hovering ? 'hover' : 'idle'),
          ),
        ),
      ),
    ));
    expect(isFileDropSupported, isTrue);

    // Outside the target: no hover.
    await _send('entered', [500.0, 500.0]);
    await tester.pump();
    expect(find.text('idle'), findsOneWidget);

    await _send('updated', [50.0, 50.0]);
    await tester.pump();
    expect(find.text('hover'), findsOneWidget);

    await tester.runAsync(() async {
      await _send('performOperation_macos', [
        {'path': file.path, 'isDirectory': false, 'fromPromise': false},
        {'path': dir.path, 'isDirectory': true, 'fromPromise': false},
      ]);
      // The files are read asynchronously.
      for (var i = 0; i < 50 && dropped.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    expect(find.text('idle'), findsOneWidget);
    expect(dropped, hasLength(1), reason: 'folders are skipped');
    expect(dropped.single.name, 'Stimme 1.pdf');
    expect(dropped.single.bytes, [1, 2, 3]);
    expect(dropped.single.size, 3);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('macOS app: Finder bookmark is opened and closed; huge files are not read', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final calls = <String>[];
    const channel = MethodChannel('desktop_drop');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add('${call.method} ${(call.arguments as Map)['apple-bookmark']}');
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final dir = await tester.runAsync(() => Directory.systemTemp.createTemp('drop'));
    addTearDown(() => dir!.deleteSync(recursive: true));
    final small = File('${dir!.path}/klein.pdf');
    final huge = File('${dir.path}/riesig.mp4');
    await tester.runAsync(() async {
      await small.writeAsBytes([7]);
      // Sparse file: 30 MiB without writing 30 MiB.
      final raf = await huge.open(mode: FileMode.write);
      await raf.truncate(30 * 1024 * 1024);
      await raf.close();
    });

    final dropped = <PlatformFile>[];
    await tester.pumpWidget(MaterialApp(
      home: FileDropTarget(
        onFiles: dropped.addAll,
        builder: (context, hovering) => const SizedBox.expand(),
      ),
    ));

    await _send('entered', [10.0, 10.0]);
    await tester.pump();
    await tester.runAsync(() async {
      await _send('performOperation_macos', [
        {'path': small.path, 'apple-bookmark': Uint8List.fromList([9]), 'isDirectory': false, 'fromPromise': false},
        {'path': huge.path, 'isDirectory': false, 'fromPromise': false},
      ]);
      for (var i = 0; i < 50 && dropped.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    expect(calls, ['startAccessingSecurityScopedResource [9]', 'stopAccessingSecurityScopedResource [9]']);
    expect(dropped.map((f) => f.name), ['klein.pdf', 'riesig.mp4']);
    expect(dropped.first.bytes, [7]);
    // Too large: only the size goes on (the dialogs say "zu groß"), no bytes.
    expect(dropped.last.size, 30 * 1024 * 1024);
    expect(dropped.last.bytes, isNull);
    expect(dropped.last.size, greaterThan(maxDroppedFileBytes));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  test('iOS / Android: no drop', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(isFileDropSupported, isFalse);
  });
}
