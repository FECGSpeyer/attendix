import 'package:attendix/core/theme/redesign/rd_palette.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/l10n/generated/app_localizations.dart';
import 'package:attendix/shared/widgets/adaptive/adaptive_platform.dart';
import 'package:attendix/shared/widgets/adaptive/app_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // BETA_SELECT: in the Beta design a select opens the Beta menu card, not
  // the Ionic glass popover – also on iOS / the Mac.
  testWidgets('Beta select opens its own menu instead of the glass popover', (tester) async {
    int? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRdTheme(RdFarbwelt.petrol, Brightness.dark).copyWith(platform: TargetPlatform.iOS),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: AppDropdownButton<int?>(
                value: null,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Sonstige')),
                  DropdownMenuItem(value: 7, child: Text('Viola')),
                ],
                onChanged: (v) => picked = v,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(IonSelectIcon), findsNothing);
    await tester.tap(find.text('Sonstige'));
    await tester.pumpAndSettle();
    expect(find.byType(IosGlassSurface), findsNothing);
    expect(find.byType(PopupMenuItem<AppSelection<int?>>), findsNWidgets(2));
    await tester.tap(find.text('Viola'));
    await tester.pumpAndSettle();
    expect(picked, 7);
  });
}
