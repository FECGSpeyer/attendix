import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Exact shrinking allowlist of files under `lib/features/` that still use
/// legacy `IonSheetHeader` or `IonInsetList`. Removing entries as features are
/// migrated to Redesign primitives (`RdSheetHead`, `RdGroupedList`) is allowed;
/// adding new usages anywhere under `lib/features/` fails this guard.
const _legacyIonSheetHeaderAllowlist = <String>{
  'lib/features/self_service/presentation/widgets/upcoming_songs_sheet.dart',
  'lib/features/songs/presentation/widgets/group_files_sheet.dart',
};

const _legacyIonInsetListAllowlist = <String>{
  'lib/features/planning/presentation/pages/shared_plan_page_view.dart',
  'lib/features/self_service/presentation/widgets/upcoming_songs_sheet.dart',
  'lib/features/songs/presentation/widgets/group_files_sheet.dart',
  'lib/features/team_organization/presentation/pages/agenda_item_detail_page.dart',
  'lib/features/team_organization/presentation/widgets/agenda_picker_sheet.dart',
  'lib/features/team_organization/presentation/widgets/task_form_sheet.dart',
  'lib/features/team_organization/presentation/widgets/tasks_tab.dart',
  'lib/features/team_organization/presentation/widgets/topics_tab_leader.dart',
  'lib/features/team_organization/presentation/widgets/topics_tab_member.dart',
};

List<File> _dartFilesIn(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String _normalize(String path) => path.replaceAll('\\', '/');

void main() {
  group('Design-system & architecture static guards', () {
    test('no new IonSheetHeader usages under lib/features/', () {
      final matches = <String>{};
      final pattern = RegExp(r'\bIonSheetHeader\b');
      for (final file in _dartFilesIn('lib/features')) {
        if (pattern.hasMatch(file.readAsStringSync())) {
          matches.add(_normalize(file.path));
        }
      }
      final unexpected = matches.difference(_legacyIonSheetHeaderAllowlist);
      expect(
        unexpected,
        isEmpty,
        reason: 'New IonSheetHeader usage(s) found; use RdSheetHead instead: $unexpected',
      );
    });

    test('no new IonInsetList usages under lib/features/', () {
      final matches = <String>{};
      final pattern = RegExp(r'\bIonInsetList\b');
      for (final file in _dartFilesIn('lib/features')) {
        if (pattern.hasMatch(file.readAsStringSync())) {
          matches.add(_normalize(file.path));
        }
      }
      final unexpected = matches.difference(_legacyIonInsetListAllowlist);
      expect(
        unexpected,
        isEmpty,
        reason: 'New IonInsetList usage(s) found; use RdGroupedList instead: $unexpected',
      );
    });

    test('org_song_copy_sheet.dart has zero legacy Ion* widgets', () {
      final file = File('lib/features/organisation/presentation/widgets/org_song_copy_sheet.dart');
      expect(file.existsSync(), isTrue);
      final source = file.readAsStringSync();
      final legacyIon = RegExp(r'\bIon[A-Z]\w*\b').allMatches(source).map((m) => m.group(0)!).toSet();
      expect(legacyIon, isEmpty, reason: 'Legacy Ion* symbols found in org_song_copy_sheet.dart: $legacyIon');
    });

    test('zero *_beta*.dart filenames exist anywhere in lib/', () {
      final betaFiles = _dartFilesIn('lib')
          .map((f) => _normalize(f.path))
          .where((path) => path.split('/').last.contains('_beta'))
          .toList();
      expect(betaFiles, isEmpty, reason: 'Unexpected *_beta*.dart files in lib/: $betaFiles');
    });

    test('orphan directories lib/core/models/ and lib/data/services/ do not exist', () {
      expect(Directory('lib/core/models').existsSync(), isFalse);
      expect(Directory('lib/data/services').existsSync(), isFalse);
    });
  });
}
