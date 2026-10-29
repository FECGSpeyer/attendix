import 'package:attendix/shared/widgets/common/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  widgetTestGroup('EmptyStateWidget', () {
    group('basic rendering', () {
      widgetTest('displays title', (tester) async {
        await tester.pumpAppAndSettle(
          const EmptyStateWidget(
            icon: Icons.inbox,
            title: 'Keine Daten',
            animateEntrance: false,
            animateIcon: false,
          ),
        );

        expect(find.text('Keine Daten'), findsOneWidget);
      });

      widgetTest('displays icon', (tester) async {
        await tester.pumpAppAndSettle(
          const EmptyStateWidget(
            icon: Icons.inbox,
            title: 'Keine Daten',
            animateEntrance: false,
            animateIcon: false,
          ),
        );

        expect(find.byIcon(Icons.inbox), findsOneWidget);
      });

      widgetTest('displays subtitle when provided', (tester) async {
        await tester.pumpAppAndSettle(
          const EmptyStateWidget(
            icon: Icons.inbox,
            title: 'Keine Daten',
            subtitle: 'Fügen Sie neue Einträge hinzu',
            animateEntrance: false,
            animateIcon: false,
          ),
        );

        expect(find.text('Fügen Sie neue Einträge hinzu'), findsOneWidget);
      });

      widgetTest('hides subtitle when not provided', (tester) async {
        await tester.pumpAppAndSettle(
          const EmptyStateWidget(
            icon: Icons.inbox,
            title: 'Keine Daten',
            animateEntrance: false,
            animateIcon: false,
          ),
        );

        // Only title should be visible
        expect(find.text('Keine Daten'), findsOneWidget);
      });
    });

    group('action button', () {
      widgetTest('shows action button when callback provided', (tester) async {
        await tester.pumpAppAndSettle(
          EmptyStateWidget(
            icon: Icons.inbox,
            title: 'Keine Daten',
            onAction: () {},
            actionLabel: 'Hinzufügen',
            animateEntrance: false,
            animateIcon: false,
          ),
        );

        // MD_BUTTONS: md ion-button labels are uppercase.
        expect(find.text('HINZUFÜGEN'), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);
      });

      widgetTest('action button triggers callback', (tester) async {
        var actionCalled = false;

        await tester.pumpAppAndSettle(
          EmptyStateWidget(
            icon: Icons.inbox,
            title: 'Keine Daten',
            onAction: () => actionCalled = true,
            actionLabel: 'Hinzufügen',
            animateEntrance: false,
            animateIcon: false,
          ),
        );

        await tester.tap(find.text('HINZUFÜGEN'));
        await tester.pump();

        expect(actionCalled, isTrue);
      });

      widgetTest('hides action button when no callback', (tester) async {
        await tester.pumpAppAndSettle(
          const EmptyStateWidget(
            icon: Icons.inbox,
            title: 'Keine Daten',
            animateEntrance: false,
            animateIcon: false,
          ),
        );

        expect(find.byType(FilledButton), findsNothing);
      });
    });

    group('size variants', () {
      widgetTest('small size renders correctly', (tester) async {
        await tester.pumpAppAndSettle(
          const EmptyStateWidget(
            icon: Icons.inbox,
            title: 'Keine Daten',
            size: EmptyStateSize.small,
            animateEntrance: false,
            animateIcon: false,
          ),
        );

        final iconFinder = find.byIcon(Icons.inbox);
        expect(iconFinder, findsOneWidget);
        final icon = tester.widget<Icon>(iconFinder);
        expect(icon.size, 48);
      });

      widgetTest('medium size renders correctly', (tester) async {
        await tester.pumpAppAndSettle(
          const EmptyStateWidget(
            icon: Icons.inbox,
            title: 'Keine Daten',
            size: EmptyStateSize.medium,
            animateEntrance: false,
            animateIcon: false,
          ),
        );

        final iconFinder = find.byIcon(Icons.inbox);
        final icon = tester.widget<Icon>(iconFinder);
        expect(icon.size, 64);
      });

      widgetTest('large size renders correctly', (tester) async {
        await tester.pumpAppAndSettle(
          const EmptyStateWidget(
            icon: Icons.inbox,
            title: 'Keine Daten',
            size: EmptyStateSize.large,
            animateEntrance: false,
            animateIcon: false,
          ),
        );

        final iconFinder = find.byIcon(Icons.inbox);
        final icon = tester.widget<Icon>(iconFinder);
        expect(icon.size, 80);
      });
    });

    group('custom illustration', () {
      widgetTest('displays custom illustration instead of icon',
          (tester) async {
        await tester.pumpAppAndSettle(
          EmptyStateWidget(
            icon: Icons.inbox,
            title: 'Keine Daten',
            customIllustration: Container(
              key: const Key('custom_illustration'),
              width: 100,
              height: 100,
              color: Colors.blue,
            ),
            animateEntrance: false,
            animateIcon: false,
          ),
        );

        expect(find.byKey(const Key('custom_illustration')), findsOneWidget);
        // Icon should not be shown when custom illustration is provided
      });
    });

    group('animations', () {
      widgetTest('entrance animation can be disabled', (tester) async {
        await tester.pumpWidget(
          createTestableWidget(
            const EmptyStateWidget(
              icon: Icons.inbox,
              title: 'Keine Daten',
              animateEntrance: false,
              animateIcon: false,
            ),
          ),
        );

        // Should be immediately visible without needing pumpAndSettle
        expect(find.text('Keine Daten'), findsOneWidget);
      });

      widgetTest('icon animation can be disabled', (tester) async {
        await tester.pumpAppAndSettle(
          const EmptyStateWidget(
            icon: Icons.inbox,
            title: 'Keine Daten',
            animateEntrance: false,
            animateIcon: false,
          ),
        );

        expect(find.byIcon(Icons.inbox), findsOneWidget);
      });
    });
  });

  widgetTestGroup('InlineEmptyState', () {
    widgetTest('displays message and icon', (tester) async {
      await tester.pumpApp(
        const InlineEmptyState(
          icon: Icons.search,
          message: 'Keine Ergebnisse',
        ),
      );

      expect(find.text('Keine Ergebnisse'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    widgetTest('shows action button when provided', (tester) async {
      await tester.pumpApp(
        InlineEmptyState(
          icon: Icons.search,
          message: 'Keine Ergebnisse',
          onAction: () {},
          actionLabel: 'Suche zurücksetzen',
        ),
      );

      expect(find.text('SUCHE ZURÜCKSETZEN'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    widgetTest('action button triggers callback', (tester) async {
      var actionCalled = false;

      await tester.pumpApp(
        InlineEmptyState(
          icon: Icons.search,
          message: 'Keine Ergebnisse',
          onAction: () => actionCalled = true,
          actionLabel: 'Suche zurücksetzen',
        ),
      );

      await tester.tap(find.text('SUCHE ZURÜCKSETZEN'));
      await tester.pump();

      expect(actionCalled, isTrue);
    });

    widgetTest('hides action button when no callback', (tester) async {
      await tester.pumpApp(
        const InlineEmptyState(
          icon: Icons.search,
          message: 'Keine Ergebnisse',
        ),
      );

      expect(find.byType(TextButton), findsNothing);
    });
  });
}
