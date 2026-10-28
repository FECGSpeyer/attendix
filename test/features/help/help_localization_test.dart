import 'package:attendix/features/help/data/help_content.dart';
import 'package:attendix/features/help/data/help_content_service.dart';
import 'package:attendix/l10n/generated/app_localizations_de.dart';
import 'package:attendix/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('localizedHelpContentService', () {
    test('German keeps the original content', () {
      final de = localizedHelpContentService('de');
      expect(de.articles.length, helpArticles.length);
      expect(de.articles.first.title, helpArticles.first.title);
      expect(de.categories.first.label, helpCategories.first.label);
    });

    test('English translates titles and keeps German glossary names as alias', () {
      final en = localizedHelpContentService('en');
      final de = localizedHelpContentService('de');
      expect(en.articles.length, de.articles.length);
      expect(en.getArticle(helpArticles.first.id)!.title, isNot(helpArticles.first.title));
      expect(en.getCategories().map((c) => c.label), contains('Getting started'));

      for (final g in glossaryTerms) {
        expect(en.findGlossaryTermByName(g.term)?.id, g.id,
            reason: 'German link [[${g.term}]] must resolve in English');
      }
    });
  });

  group('member lane l10n keys', () {
    final de = AppLocalizationsDe();
    final en = AppLocalizationsEn();

    test('German dashboard texts match the previous literals', () {
      expect(de.homeDashboardLastSummary(3, 5, 1), '3/5 anwesend · 1 entschuldigt');
      expect(de.homeDashboardPlanTimes('19:00', '21:00', 1), '19:00 – 21:00 Uhr · 1 Position');
      expect(de.homeDashboardPlanTimes('19:00', '21:00', 4), '19:00 – 21:00 Uhr · 4 Positionen');
      expect(de.homeDashboardFlutterLoadFailed('x'), 'Fehler beim Laden: x');
      expect(de.homeDashboardFlutterTimeRange('19:00'), '19:00 Uhr');
      expect(de.homeDashboardFlutterJoin, 'Beitritt');
      expect(de.homeDashboardFlutterExit, 'Austritt');
    });

    test('English has translations for Flutter-only keys', () {
      expect(en.homeDashboardFlutterLoadFailed('x'), 'Error while loading: x');
      expect(en.homeDashboardFlutterJoin, 'Joined');
      expect(en.dashSettingsFlutterReorder, 'Change order');
    });
  });
}
