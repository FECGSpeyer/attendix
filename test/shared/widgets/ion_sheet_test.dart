// Shared classic sheet scaffold (Ionic sheet modal): breakpoints 1:1, the
// Ionic handle, the toolbar header in both looks, drag on the header, close
// at breakpoint 0.
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:flutter/rendering.dart';
import 'package:attendix/shared/widgets/layout/sheet_drag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(390, 844);

Future<void> _open(
  WidgetTester tester, {
  required TargetPlatform platform,
  List<double> breakpoints = const [0, 0.5, 1],
  double initialBreakpoint = 0.5,
  bool canDismiss = true,
  bool showClose = false,
}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(platform: platform),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showIonSheet<void>(
            context,
            breakpoints: breakpoints,
            initialBreakpoint: initialBreakpoint,
            canDismiss: canDismiss,
            builder: (_, controller) => IonSheetScaffold(
              title: 'Personen',
              showClose: showClose,
              body: ListView(
                controller: controller,
                children: [for (var i = 0; i < 40; i++) ListTile(title: Text('Zeile $i'))],
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

double _sheetTop(WidgetTester tester) => tester.getTopLeft(find.byType(IonSheetScaffold)).dy;

void main() {
  testWidgets('breakpoints are fractions of the Ionic sheet height (10pt gap), header drag moves and closes',
      (tester) async {
    await _open(tester, platform: TargetPlatform.iOS);
    // Ionic `.modal-sheet --height: calc(100% - (safe-area-top + 10px))`
    final full = _size.height - IonBreakpointSheet.topGap;
    expect(_sheetTop(tester), moreOrLessEquals(_size.height - 0.5 * full, epsilon: 1));
    expect(find.byType(IonModalHandle), findsOneWidget);

    // Dragging the toolbar up expands to breakpoint 1.
    await tester.drag(find.text('Personen'), const Offset(0, -330));
    await tester.pumpAndSettle();
    expect(_sheetTop(tester), moreOrLessEquals(IonBreakpointSheet.topGap, epsilon: 1));

    // Down to breakpoint 0 = closed.
    await tester.fling(find.text('Personen'), const Offset(0, 400), 2000);
    await tester.pumpAndSettle();
    if (find.text('Personen').evaluate().isNotEmpty) {
      await tester.fling(find.text('Personen'), const Offset(0, 400), 2000);
      await tester.pumpAndSettle();
    }
    expect(find.text('Personen'), findsNothing);
  });

  testWidgets('without breakpoint 0 / canDismiss the sheet stays open', (tester) async {
    await _open(tester, platform: TargetPlatform.iOS, canDismiss: false);
    await tester.fling(find.text('Personen'), const Offset(0, 400), 2000);
    await tester.pumpAndSettle();
    await tester.fling(find.text('Personen'), const Offset(0, 400), 2000);
    await tester.pumpAndSettle();
    expect(find.text('Personen'), findsOneWidget);
    // The backdrop does not close it either.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Personen'), findsOneWidget);
  });

  testWidgets('toolbar header: centred 64pt on iOS, start-aligned 56px in md; close button at the end',
      (tester) async {
    await _open(tester, platform: TargetPlatform.iOS, showClose: true);
    final iosHeader = tester.getSize(find.byType(IonSheetHeader));
    expect(iosHeader.height, moreOrLessEquals(64.5, epsilon: 0.01));
    expect(tester.getCenter(find.text('Personen')).dx, moreOrLessEquals(_size.width / 2, epsilon: 1));
    expect(find.byType(IonCloseButton), findsOneWidget);
    expect(tester.getSize(find.byType(IonModalHandle)), IonModalHandle.size);
    await tester.tap(find.byType(IonCloseButton));
    await tester.pumpAndSettle();
    expect(find.text('Personen'), findsNothing);

    await _open(tester, platform: TargetPlatform.android, showClose: true);
    final mdHeader = tester.getSize(find.byType(IonSheetHeader));
    expect(mdHeader.height, 56);
    expect(tester.getTopLeft(find.text('Personen')).dx, moreOrLessEquals(20, epsilon: 1));
    // md keeps the Ionic handle too (36 × 5).
    expect(tester.getSize(find.byType(IonModalHandle)), IonModalHandle.mdSize);
    expect(tester.getTopRight(find.byType(IonCloseButton)).dx, greaterThan(_size.width - 12));
  });

  testWidgets('AppDraggableSheet.breakpoints renders the Ionic sheet in the classic design', (tester) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => AppDraggableSheet(
                breakpoints: const [0, 0.6, 1],
                initialBreakpoint: 0.6,
                initialChildSize: 0.3,
                expand: false,
                builder: (_, controller) => IonSheetScaffold(
                  title: 'Werke',
                  body: ListView(controller: controller, children: const [ListTile(title: Text('A'))]),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final full = _size.height - IonBreakpointSheet.topGap;
    expect(_sheetTop(tester), moreOrLessEquals(_size.height - 0.6 * full, epsilon: 1));
    expect(find.byType(IonModalHandle), findsOneWidget);
  });

  testWidgets('NB-T03: iOS title keeps the Ionic room next to wide text buttons', (tester) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Scaffold(
        body: IonSheetHeader(
          title: 'Feld bearb',
          start: [SizedBox(width: 140, child: TextButton(onPressed: () {}, child: const Text('A')))],
          end: [SizedBox(width: 140, child: TextButton(onPressed: () {}, child: const Text('U')))],
        ),
      ),
    ));
    final title = tester.renderObject<RenderParagraph>(find.text('Feld bearb'));
    expect(title.didExceedMaxLines, isFalse);
    expect(tester.getCenter(find.text('Feld bearb')).dx, moreOrLessEquals(_size.width / 2, epsilon: 1));
  });
}
