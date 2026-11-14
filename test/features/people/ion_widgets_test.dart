import 'package:attendix/core/theme/app_icons.dart';
import 'package:attendix/features/people/presentation/widgets/ion/ion_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(TargetPlatform platform, Widget child) => MaterialApp(
      theme: ThemeData(platform: platform),
      home: child,
    );

void main() {
  group('UX_PEOPLE ion widgets', () {
    testWidgets('IonPage uses a condensed large title on iOS', (tester) async {
      await tester.pumpWidget(_app(
        TargetPlatform.iOS,
        const IonPage(title: 'Lehrer', slivers: [SliverToBoxAdapter(child: Text('x'))]),
      ));
      expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('PERF_GLASS: nav bar turns solid once content is under it, no blur',
        (tester) async {
      await tester.pumpWidget(_app(
        TargetPlatform.iOS,
        IonPage(title: 'Lehrer', slivers: [
          SliverList.list(children: [
            for (var i = 0; i < 60; i++) SizedBox(height: 40, child: Text('$i')),
          ]),
        ]),
      ));
      CupertinoSliverNavigationBar bar() => tester
          .widget<CupertinoSliverNavigationBar>(
              find.byType(CupertinoSliverNavigationBar));
      expect(bar().enableBackgroundFilterBlur, isFalse);
      expect(bar().backgroundColor!.a, lessThan(1));
      await tester.drag(find.text('3'), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(bar().enableBackgroundFilterBlur, isFalse);
      expect(bar().backgroundColor!.a, 1);
    });

    testWidgets('IonPage keeps the Material AppBar elsewhere', (tester) async {
      await tester.pumpWidget(_app(
        TargetPlatform.android,
        const IonPage(title: 'Lehrer', slivers: [SliverToBoxAdapter(child: Text('x'))]),
      ));
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(CupertinoSliverNavigationBar), findsNothing);
    });

    // One "+" for every page: the theme's FAB (glass on iOS) in both looks,
    // so the Termine and the Personen button look the same.
    testWidgets('IonFabButton is the themed FAB on iOS and md', (tester) async {
      await tester.pumpWidget(_app(
        TargetPlatform.iOS,
        Scaffold(floatingActionButton: IonFabButton(onPressed: () {})),
      ));
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(AppIcons.add), findsOneWidget);

      await tester.pumpWidget(_app(
        TargetPlatform.android,
        Scaffold(floatingActionButton: IonFabButton(onPressed: () {})),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('IonAccordion shows its child only when expanded', (tester) async {
      var expanded = false;
      await tester.pumpWidget(_app(
        TargetPlatform.iOS,
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => IonAccordion(
              title: 'Allgemein',
              expanded: expanded,
              onToggle: () => setState(() => expanded = !expanded),
              child: const Text('Telefon'),
            ),
          ),
        ),
      ));
      expect(find.text('Telefon'), findsNothing);
      await tester.tap(find.text('Allgemein'));
      await tester.pumpAndSettle();
      expect(find.text('Telefon'), findsOneWidget);
    });
  });
}
