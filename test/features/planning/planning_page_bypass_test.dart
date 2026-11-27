
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/source_reader.dart';

/// Regression test: ensure planning_page never reintroduces a direct
/// supabase bypass or unsafe tenant-id force-unwrap.
void main() {
  test('planning_page does not use supabaseClientProvider directly', () {
    final source = readDartLibrary('lib/features/planning/presentation/pages/planning_page.dart');

    expect(source, isNot(contains('supabaseClientProvider')));
    expect(source, isNot(contains('tenant.id!')));
    expect(source, isNot(contains('tenant!.id!')));
  });
}
