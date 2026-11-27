import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart' show IonSheetHeader;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    required Size size,
    required double textScale,
    String title = 'Werk kopieren',
    List<Widget>? start,
    List<Widget>? end,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: IonSheetHeader(
                title: title,
                start: start ??
                    [
                      TextButton(
                        onPressed: () {},
                        child: const Text('Abbrechen'),
                      ),
                    ],
                end: end ??
                    [
                      TextButton(
                        onPressed: () {},
                        child: const Text('Kopieren'),
                      ),
                    ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('IonSheetHeader', () {
    for (final caseData in [
      (name: '390x844 @ 1.0x', size: const Size(390, 844), scale: 1.0),
      (name: '320x640 @ 1.6x', size: const Size(320, 640), scale: 1.6),
    ]) {
      testWidgets(
        'start, title, and end never overlap or overflow (${caseData.name})',
        (tester) async {
          final errors = <FlutterErrorDetails>[];
          final prev = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details);
          };
          addTearDown(() => FlutterError.onError = prev);

          await pumpHeader(
            tester,
            size: caseData.size,
            textScale: caseData.scale,
          );

          expect(errors, isEmpty, reason: 'unexpected layout/overflow error');
          expect(tester.takeException(), isNull);

          final rStart = tester.getRect(find.text('Abbrechen'));
          final rTitle = tester.getRect(find.text('Werk kopieren'));
          final rEnd = tester.getRect(find.text('Kopieren'));

          expect(rStart.overlaps(rTitle), isFalse);
          expect(rTitle.overlaps(rEnd), isFalse);
          expect(rStart.right, lessThanOrEqualTo(rTitle.left));
          expect(rTitle.right, lessThanOrEqualTo(rEnd.left));
        },
      );
    }

    testWidgets('balances centered title when only one side has an action', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        size: const Size(390, 844),
        textScale: 1.0,
        start: const [],
        end: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.close),
          ),
        ],
      );

      expect(tester.takeException(), isNull);
      final rTitle = tester.getRect(find.text('Werk kopieren'));
      final rEnd = tester.getRect(find.byIcon(Icons.close));
      expect(rTitle.overlaps(rEnd), isFalse);
      expect((rTitle.center.dx - 195.0).abs(), lessThan(8.0));
    });
  });
}
