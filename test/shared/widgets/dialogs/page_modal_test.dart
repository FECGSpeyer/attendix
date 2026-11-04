import 'package:attendix/shared/widgets/dialogs/ion_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'page modal closes itself before a router navigation (Ionic isModal, $platform)',
      (tester) async {
        late BuildContext homeContext;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) {
                homeContext = context;
                return const Scaffold(body: Text('home'));
              },
            ),
            GoRoute(
              path: '/target',
              builder: (_, __) => const Scaffold(body: Text('target')),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            theme: ThemeData(platform: platform),
            routerConfig: router,
          ),
        );

        var inModal = false;
        showPageModal<void>(
          homeContext,
          builder: (_) {
            return Scaffold(
              body: Builder(
                builder: (inner) {
                  inModal = IonPageModalScope.isIn(inner);
                  return TextButton(
                    onPressed: () => inner.push('/target'),
                    child: const Text('go'),
                  );
                },
              ),
            );
          },
        );
        await tester.pumpAndSettle();
        expect(inModal, isTrue);

        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(find.text('go'), findsNothing);
        expect(find.text('target'), findsOneWidget);
      },
    );
  }
}
