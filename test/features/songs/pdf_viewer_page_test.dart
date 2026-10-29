import 'dart:io';

import 'package:attendix/features/songs/presentation/widgets/pdf_viewer_page.dart';
import 'package:attendix/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PDF_SCROLL: the PDF viewer is a full-screen page (no bottom sheet whose
/// drag-to-close gesture takes the vertical swipes) with a scroll and a
/// page-by-page mode.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Widget app() => MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showPdfViewer(
                  context,
                  url: 'https://example.invalid/noten.pdf',
                  fileName: 'Noten Trompete 1.pdf',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  testWidgets('opens as a full-screen page, not as a bottom sheet', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('open'));
    await settle(tester);

    expect(find.byType(PdfViewerPage), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    final route = ModalRoute.of(tester.element(find.byType(PdfViewerPage)));
    expect(route, isA<PageRoute<void>>());
    expect((route! as PageRoute<void>).fullscreenDialog, isTrue);
    expect(find.text('Noten Trompete 1.pdf'), findsOneWidget);

    // Closes with the X.
    await tester.tap(find.byTooltip('Schließen'));
    await settle(tester);
    expect(find.byType(PdfViewerPage), findsNothing);
  });

  testWidgets('a failed download offers retry and opening externally', (tester) async {
    // Widget tests answer every HTTP request with 400.
    await tester.pumpWidget(app());
    await tester.tap(find.text('open'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);

    expect(find.text('PDF konnte nicht geladen werden'), findsOneWidget);
    expect(find.byTooltip('Extern öffnen'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    // No page switch without a document.
    expect(find.byTooltip('Seitenweise blättern'), findsNothing);
  });

  test('the viewer no longer uses a bottom sheet and offers both modes', () {
    final source = File('lib/features/songs/presentation/widgets/pdf_viewer_page.dart').readAsStringSync();
    expect(source, isNot(contains('showModalBottomSheet')));
    expect(source, contains('fullscreenDialog: true'));
    expect(source, contains('PdfViewPinch('));
    expect(source, contains('scrollDirection: Axis.vertical'));
    expect(source, contains('pageSnapping: true'));
    expect(source, contains('pdfViewModeStorageKey'));

    final opener = File('lib/features/songs/presentation/widgets/song_file_opener.dart').readAsStringSync();
    expect(opener, contains('showPdfViewer(context'));
  });

  test('the normal app keeps its PDF viewer, the new design opens the page', () {
    final opener = File('lib/features/songs/presentation/widgets/song_file_opener.dart').readAsStringSync();
    expect(opener, contains('if (RedesignRoutes.active) {'));
    expect(opener, contains('await showPdfViewer(context'));
    expect(opener, contains('await showPdfViewerSheet(context'));
  });
}
