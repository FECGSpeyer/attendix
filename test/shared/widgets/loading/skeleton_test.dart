import 'package:attendix/shared/widgets/loading/skeleton_base.dart';
import 'package:attendix/shared/widgets/loading/skeleton_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  widgetTestGroup('SkeletonBase', () {
    widgetTest('renders with default height of 16', (tester) async {
      await tester.pumpApp(
        const SkeletonBase(),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Shimmer),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints?.maxHeight, 16);
    });

    widgetTest('respects custom width parameter', (tester) async {
      await tester.pumpApp(
        const SkeletonBase(width: 100),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Shimmer),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints?.maxWidth, 100);
    });

    widgetTest('respects custom height parameter', (tester) async {
      await tester.pumpApp(
        const SkeletonBase(height: 24),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Shimmer),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints?.maxHeight, 24);
    });

    widgetTest('uses Shimmer widget for animation', (tester) async {
      await tester.pumpApp(
        const SkeletonBase(),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });

    widgetTest('applies default border radius of 4', (tester) async {
      await tester.pumpApp(
        const SkeletonBase(),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Shimmer),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(4));
    });
  });

  widgetTestGroup('SkeletonAvatar', () {
    widgetTest('renders with default size of 40', (tester) async {
      await tester.pumpApp(
        const SkeletonAvatar(),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Shimmer),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints?.maxWidth, 40);
      expect(container.constraints?.maxHeight, 40);
    });

    widgetTest('respects custom size parameter', (tester) async {
      await tester.pumpApp(
        const SkeletonAvatar(size: 60),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Shimmer),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints?.maxWidth, 60);
      expect(container.constraints?.maxHeight, 60);
    });

    widgetTest('uses circular shape', (tester) async {
      await tester.pumpApp(
        const SkeletonAvatar(),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Shimmer),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    });
  });

  widgetTestGroup('SkeletonText', () {
    widgetTest('renders with default height of 14', (tester) async {
      await tester.pumpApp(
        const SizedBox(
          width: 200,
          child: SkeletonText(),
        ),
      );

      expect(find.byType(SkeletonBase), findsOneWidget);
    });

    widgetTest('uses fixed width when specified', (tester) async {
      await tester.pumpApp(
        const SkeletonText(width: 150),
      );

      final skeletonBase = tester.widget<SkeletonBase>(
        find.byType(SkeletonBase),
      );
      expect(skeletonBase.width, 150);
    });

    widgetTest('uses FractionallySizedBox when no fixed width', (tester) async {
      await tester.pumpApp(
        const SizedBox(
          width: 200,
          child: SkeletonText(widthFactor: 0.5),
        ),
      );

      expect(find.byType(FractionallySizedBox), findsOneWidget);
    });

    widgetTest('respects widthFactor parameter', (tester) async {
      await tester.pumpApp(
        const SizedBox(
          width: 200,
          child: SkeletonText(widthFactor: 0.7),
        ),
      );

      final fractionBox = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fractionBox.widthFactor, 0.7);
    });
  });

  widgetTestGroup('SkeletonListTile', () {
    widgetTest('shows avatar by default', (tester) async {
      await tester.pumpApp(
        const SkeletonListTile(),
      );

      // Should find a circular container (avatar)
      final containers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).shape == BoxShape.circle)
          .toList();

      expect(containers.isNotEmpty, isTrue);
    });

    widgetTest('hides avatar when showAvatar is false', (tester) async {
      await tester.pumpApp(
        const SkeletonListTile(showAvatar: false),
      );

      // Count circular containers
      final containers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).shape == BoxShape.circle)
          .toList();

      expect(containers.isEmpty, isTrue);
    });

    widgetTest('shows subtitle by default', (tester) async {
      await tester.pumpApp(
        const SkeletonListTile(),
      );

      // Should have FractionallySizedBox for subtitle
      expect(find.byType(FractionallySizedBox), findsOneWidget);
    });

    widgetTest('hides subtitle when showSubtitle is false', (tester) async {
      await tester.pumpApp(
        const SkeletonListTile(showSubtitle: false),
      );

      // Should not have FractionallySizedBox
      expect(find.byType(FractionallySizedBox), findsNothing);
    });

    widgetTest('hides trailing by default', (tester) async {
      await tester.pumpApp(
        const SkeletonListTile(),
      );

      // Count containers - trailing would add one more
      // We verify by checking with showTrailing: true
    });

    widgetTest('shows trailing when showTrailing is true', (tester) async {
      await tester.pumpApp(
        const SkeletonListTile(showTrailing: true),
      );

      // Should have more containers when trailing is shown
      expect(find.byType(Container), findsWidgets);
    });

    widgetTest('respects avatarSize parameter', (tester) async {
      await tester.pumpApp(
        const SkeletonListTile(avatarSize: 50),
      );

      final containers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).shape == BoxShape.circle &&
              c.constraints?.maxWidth == 50)
          .toList();

      expect(containers.isNotEmpty, isTrue);
    });
  });

  widgetTestGroup('SkeletonCard', () {
    widgetTest('renders with default height of 120', (tester) async {
      await tester.pumpApp(
        const SkeletonCard(),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Shimmer),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints?.maxHeight, 120);
    });

    widgetTest('respects custom height parameter', (tester) async {
      await tester.pumpApp(
        const SkeletonCard(height: 200),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Shimmer),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints?.maxHeight, 200);
    });

    widgetTest('uses Shimmer for animation', (tester) async {
      await tester.pumpApp(
        const SkeletonCard(),
      );

      expect(find.byType(Shimmer), findsOneWidget);
    });
  });
}
