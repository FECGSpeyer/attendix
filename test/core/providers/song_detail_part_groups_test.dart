// The Beta Werk page reads the parts of uploaded files against
// `SongDetailData.partGroups`. Outside orchestras `instruments` stays empty
// (classic page, as in Ionic), so a choir's upload of "Tenor.pdf" proposed
// "Neue Gruppe: Tenor" although the group existed.
import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/group_providers.dart';
import 'package:attendix/core/providers/song_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/data/models/song/song.dart';
import 'package:attendix/data/repositories/song_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<SongDetailData?> load(String type) async {
    const SongDetailParams params = (songId: 5, sharingId: null);
    final container = createTestContainer(
      tenant: TestFactories.createTenant(id: 7, type: type),
      overrides: [
        currentAuthUserIdProvider.overrideWithValue('u1'),
        currentRoleProvider.overrideWithValue(Role.admin),
        songTenantSettingsProvider.overrideWith((ref) async => const SongTenantSettings()),
        songByIdProvider(5).overrideWith((ref) async => const Song(id: 5, name: 'Großer Gott')),
        songCategoriesProvider.overrideWith((ref) async => const []),
        songHistoryProvider(5).overrideWith((ref) async => const []),
        groupsProvider.overrideWith(
          (ref) async => [
            TestFactories.createGroup(id: 1, name: 'Dirigent', maingroup: true),
            TestFactories.createGroup(id: 2, name: 'Sopran'),
            TestFactories.createGroup(id: 3, name: 'Tenor'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    // Keeps the autoDispose provider alive until it has loaded.
    container.listen(songDetailDataProvider(params), (_, __) {});
    return container.read(songDetailDataProvider(params).future);
  }

  test('a choir gets its voices as part groups, without the main group', () async {
    final data = await load('choir');

    expect(data!.instruments, isEmpty);
    expect(data.partGroups.map((g) => g.name), ['Sopran', 'Tenor']);
  });

  test('an orchestra keeps the same groups in both lists', () async {
    final data = await load('orchestra');

    expect(data!.instruments.map((g) => g.name), ['Sopran', 'Tenor']);
    expect(data.partGroups, data.instruments);
  });
}
