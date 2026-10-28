import 'package:attendix/shared/widgets/display/avatar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/widget_test_helpers.dart';

void main() {
  widgetTestGroup('Avatar', () {
    // PARITY_R5: Ionic shows assets/icon/avatar-placeholder.svg for people
    // without a picture (iOS and md) – no teal initials disc.
    group('placeholder', () {
      widgetTest('shows the Ionic placeholder when no image URL provided',
          (tester) async {
        await tester.pumpApp(
          const Avatar(firstName: 'Max', lastName: 'Mustermann'),
        );

        expect(find.byType(IonAvatarPlaceholder), findsOneWidget);
        expect(find.text('MM'), findsNothing);
        expect(find.byType(CircleAvatar), findsNothing);
      });

      widgetTest('shows the placeholder when image URL is empty',
          (tester) async {
        await tester.pumpApp(
          const Avatar(firstName: 'Anna', lastName: 'Schmidt', imageUrl: ''),
        );

        expect(find.byType(IonAvatarPlaceholder), findsOneWidget);
      });

      widgetTest('handles empty names', (tester) async {
        await tester.pumpApp(const Avatar(firstName: '', lastName: ''));

        expect(find.byType(IonAvatarPlaceholder), findsOneWidget);
      });
    });

    group('size parameter', () {
      widgetTest('default size is 40', (tester) async {
        await tester.pumpApp(
          const Avatar(firstName: 'Test', lastName: 'User'),
        );

        final placeholder = tester.widget<IonAvatarPlaceholder>(
            find.byType(IonAvatarPlaceholder));
        expect(placeholder.size, 40);
      });

      widgetTest('respects custom size parameter', (tester) async {
        await tester.pumpApp(
          const Avatar(firstName: 'Test', lastName: 'User', size: 60),
        );

        expect(
            tester
                .widget<IonAvatarPlaceholder>(find.byType(IonAvatarPlaceholder))
                .size,
            60);
      });
    });

    group('image display', () {
      widgetTest('uses CachedNetworkImage when URL provided', (tester) async {
        await tester.pumpApp(
          const Avatar(
            firstName: 'Test',
            lastName: 'User',
            imageUrl: 'https://example.com/image.jpg',
          ),
        );

        expect(find.byType(CachedNetworkImage), findsOneWidget);
      });

      widgetTest('shows the placeholder while the image loads',
          (tester) async {
        await tester.pumpApp(
          const Avatar(
            firstName: 'Test',
            lastName: 'User',
            imageUrl: 'https://example.com/image.jpg',
          ),
        );

        await tester.pump();
        expect(find.byType(IonAvatarPlaceholder), findsOneWidget);
      });
    });
  });
}
