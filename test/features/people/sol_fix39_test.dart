
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/source_reader.dart';

// SOL_FIX39: Sol review 6497424908 on PR #236.
void main() {
  String src(String p) => readDartLibrary(p);

  test('members list clears bulk selection when tenant changes', () {
    final s = src('lib/features/redesign/presentation/pages/rd_members_page.dart');
    expect(s, contains('ref.listenManual(currentTenantIdProvider,'));
    expect(s, contains('bulkSelected.clear'));
  });

  test('reactivation invalidates the cached person', () {
    final s = src('lib/features/redesign/presentation/pages/rd_person_edit_page.dart');
    final i = s.indexOf('reactivatePlayer(person)');
    expect(i, isNonNegative);
    expect(s.substring(i, i + 400), contains('_container.invalidate(personProvider('));
  });

  test('archive list refreshes after returning from person page only when mounted', () {
    final s = src('lib/features/redesign/presentation/pages/rd_archive_page.dart');
    expect(s, contains('await context.push(RedesignRoutes.person(p.id!));'));
    expect(s, contains('if (context.mounted) ref.invalidate(leftPlayersProvider);'));
  });
}
