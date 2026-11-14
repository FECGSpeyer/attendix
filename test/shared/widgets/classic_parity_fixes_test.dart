// Classic design parity with the Ionic app: the filter popover keeps open
// while a select inside is used, sheet headers span the sheet and move it.
import 'package:attendix/core/theme/app_icons.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:attendix/shared/widgets/layout/ionic_ios.dart';
import 'package:attendix/shared/widgets/layout/sheet_drag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filter popover stays open while a nested select is used', (tester) async {
    var sort = 'a';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: Builder(
            builder: (context) => IconButton(
              icon: Icon(AppIcons.tune),
              onPressed: () => showAppFilterPopover(
                context: context,
                rows: () => [
                  AppFilterSelect<String>(
                    icon: AppIcons.filterList,
                    value: sort,
                    options: const [('a', 'Stimme'), ('b', 'Nachname')],
                    onSelected: (v) => sort = v,
                  ),
                  AppFilterAction(icon: AppIcons.edit, label: 'Mehrere bearbeiten', onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byIcon(AppIcons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stimme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nachname'));
    await tester.pumpAndSettle();

    expect(sort, 'b');
    // Only the nested popover closed; the row shows the new value.
    expect(find.text('Mehrere bearbeiten'), findsOneWidget);
    expect(find.text('Nachname'), findsOneWidget);
  });

  testWidgets('sheet header spans the sheet and a drag on it moves the sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
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
                expand: false,
                initialChildSize: 0.5,
                minChildSize: 0.3,
                maxChildSize: 1,
                builder: (_, controller) => Column(
                  children: [
                    IonSheetHeader(
                      title: 'Dirigenten',
                      start: [IconButton(icon: Icon(AppIcons.arrowBack), onPressed: () {})],
                    ),
                    Expanded(
                      child: ListView(
                        controller: controller,
                        children: [for (var i = 0; i < 30; i++) ListTile(title: Text('Werk $i'))],
                      ),
                    ),
                  ],
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

    // The start button sits at the sheet's edge, not next to the title.
    expect(tester.getTopLeft(find.byIcon(AppIcons.arrowBack)).dx, lessThan(30));

    final before = tester.getTopLeft(find.text('Dirigenten')).dy;
    await tester.drag(find.text('Dirigenten'), const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Dirigenten')).dy, lessThan(before - 150));

    await tester.fling(find.text('Dirigenten'), const Offset(0, 300), 1500);
    await tester.pumpAndSettle();
    await tester.fling(find.text('Dirigenten'), const Offset(0, 300), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Dirigenten'), findsNothing);
  });
}
