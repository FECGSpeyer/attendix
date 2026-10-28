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

    testWidgets('IonPage keeps the Material AppBar elsewhere', (tester) async {
      await tester.pumpWidget(_app(
        TargetPlatform.android,
        const IonPage(title: 'Lehrer', slivers: [SliverToBoxAdapter(child: Text('x'))]),
      ));
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(CupertinoSliverNavigationBar), findsNothing);
    });

    testWidgets('IonFabButton is a glass button on iOS and a FAB on md', (tester) async {
      await tester.pumpWidget(_app(
        TargetPlatform.iOS,
        Scaffold(floatingActionButton: IonFabButton(onPressed: () {})),
      ));
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.add), findsOneWidget);

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
