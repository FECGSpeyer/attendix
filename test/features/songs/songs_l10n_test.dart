import 'package:attendix/features/duty/presentation/widgets/self_service_duty_section.dart';
import 'package:attendix/features/songs/presentation/utils/song_utils.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// I18N lane "songs" (songs, duty, shifts): helpers without BuildContext follow
/// the active language, German output stays as before.
void main() {
  tearDown(() => setActiveLanguage(defaultLanguage));

  group('German (default)', () {
    setUp(() => setActiveLanguage('de'));

    test('difficulty labels', () {
      expect(SongUtils.difficultyLabel(1), '1 - Leicht');
      expect(SongUtils.difficultyLabel(3), '3 - Schwer');
      expect(SongUtils.difficultyLabel(null), 'Nicht definiert');
    });

    test('conjunction list', () {
      expect(SongUtils.formatList(['a', 'b', 'c']), 'a, b und c');
      expect(SongUtils.formatList(['a']), 'a');
    });

    test('open duties tile subtitle', () {
      expect(openDutiesTileSubtitle(0), 'alles besetzt');
      expect(openDutiesTileSubtitle(1), '1 offen');
      expect(openDutiesTileSubtitle(3), '3 offen');
    });
  });

  group('English', () {
    setUp(() => setActiveLanguage('en'));

    test('difficulty labels and list use English texts', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(SongUtils.difficultyLabel(1), en.songsEasy);
      expect(SongUtils.formatList(['a', 'b', 'c']), 'a, b and c');
      expect(openDutiesTileSubtitle(0), 'all filled');
    });
  });

  test('fragment keys exist in both languages', () {
    final de = lookupAppLocalizations(const Locale('de'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(de.shiftsFlutterSegments(2), '2 Segmente');
    expect(en.shiftsFlutterSegments(1), '1 segment');
    expect(de.dutyFlutterNameRequested('Anna'), 'Anna (angefragt)');
    expect(de.songsFlutterFilesSkipped(2), '2 Datei(en) konnten nicht eingebunden werden.');
  });
}
