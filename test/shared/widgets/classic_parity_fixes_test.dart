import 'package:attendix/core/theme/app_icons.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
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
}
