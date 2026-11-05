import 'package:attendix/shared/widgets/dialogs/ion_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  // Phone: iOS card modal / md full screen; tablet: centred card.
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS])
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets(
      'page modal closes itself before a router navigation (Ionic isModal, $platform, $size)',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        late BuildContext homeContext;
        // Like the app: tabs in a ShellRoute, the target pushed onto it.
        final router = GoRouter(
          routes: [
            ShellRoute(
              builder: (_, __, child) => child,
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
