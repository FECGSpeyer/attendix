// IOS_R4: Ionic iOS toolbar height and tenant order.
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/theme/app_theme.dart';
import 'package:attendix/features/settings/presentation/widgets/settings_list.dart';
import 'package:attendix/shared/widgets/event_list/event_list_widgets.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../factories/test_factories.dart';

void main() {
  group('Ionic iOS toolbar height', () {
    test('max(safe-10, 6) + 64 + 3 below the status bar', () {
      // browser without safe area: hairline at 73, capsules centred ≈38
      expect(ionToolbarHeight(0), 73);
      // notched iPhone: safe area + 57
      expect(ionToolbarHeight(59), 57);
      expect(ionToolbarHeight(47), 57);
    });

    Future<double> barHeight(WidgetTester tester, TargetPlatform p) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: p),
        builder: (context, child) => IonToolbarMetrics(child: child!),
        home: Scaffold(appBar: AppBar(title: const Text('T'))),
      ));
      await tester.pumpAndSettle(); // theme animation
      return tester.getSize(find.byType(AppBar)).height;
    }

    testWidgets('IonToolbarMetrics: iOS 73pt, Material unchanged',
        (tester) async {
      expect(await barHeight(tester, TargetPlatform.iOS), 73);
      expect(await barHeight(tester, TargetPlatform.android), 56);
    });
  });

  test('tenants sort by longName like Ionic (not by short name)', () {
    final chor = TestFactories.createTenant(id: 1, longName: 'Chor')
        .copyWith(shortName: 'ZZ');
    final orchester = TestFactories.createTenant(id: 2, longName: 'orchester')
        .copyWith(shortName: 'AA');
    final list = [orchester, chor]..sort(compareTenantLongNames);
    expect(list.map((t) => t.id), [1, 2]);
  });

  testWidgets(
      'dark iOS: grouped page #222428 with black item groups, cards #1c1c1d, '
      'plain Termin pages stay black', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.forPlatform(Brightness.dark, TargetPlatform.iOS)
          .copyWith(platform: TargetPlatform.iOS),
      home: Builder(builder: (context) {
        ctx = context;
        return const Scaffold(
          body: IonInsetGroup(children: [ListTile(title: Text('a'))]),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(Theme.of(ctx).scaffoldBackgroundColor, const Color(0xFF222428));
    final colors = tester
        .widgetList<Material>(find.descendant(
            of: find.byType(IonInsetGroup), matching: find.byType(Material)))
        .map((m) => m.color)
        .toList();
    expect(colors, contains(Colors.black));
    expect(IonIos.cardBackground(ctx), const Color(0xFF1C1C1D));
    expect(eventPageBackground(ctx), Colors.black);
  });
}
