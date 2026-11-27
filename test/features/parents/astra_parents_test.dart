
import 'package:attendix/core/providers/signout_providers.dart';
import 'package:attendix/data/repositories/sign_in_out_repository.dart';
import 'package:attendix/features/parents/data/providers/parents_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/source_reader.dart';

/// Records sign-ins and fails for the ids in [failing].
class _FakeSignInOutRepository extends SignInOutRepository {
  _FakeSignInOutRepository(super.ref, {this.failing = const {}});

  final Set<String> failing;
  final List<(String, SignInType)> calls = [];

  @override
  Future<void> signIn(
    String personAttendanceId,
    SignInType type, {
    String notes = '',
    bool ownAcrossTenants = false,
  }) async {
    calls.add((personAttendanceId, type));
    if (failing.contains(personAttendanceId)) throw Exception('update failed');
  }
}

void main() {
  group('ASTRA_PARENTS extra_plans', () {
    test('parents load path selects attendance.extra_plans', () {
      final src = readDartLibrary('lib/data/repositories/attendance_repository.dart');
      final start = src.indexOf('getPersonAttendancesForPersons(');
      final body = src.substring(start, src.indexOf('handleError', start));
      expect(body, contains('extra_plans'));
      expect(body, contains(".eq('attendance.tenantId', currentTenantId)"));
    });

    test('parseExtraPlans keeps plan maps only', () {
      expect(parseExtraPlans(null), isNull);
      expect(parseExtraPlans('x'), isNull);
      expect(parseExtraPlans([]), isNull);
      final plans = parseExtraPlans([
        {'time': '10:00', 'fields': [], 'day': 1},
        42,
      ]);
      expect(plans, hasLength(1));
      expect(plans!.first['day'], 1);
    });

    test('groups carry extra plans and the page passes them to the viewer', () {
      final providers = readDartLibrary('lib/features/parents/data/providers/parents_providers.dart');
      expect(providers, contains("extraPlans: parseExtraPlans(attendance?['extra_plans'])"));
      expect(providers, contains('extraPlans: first.extraPlans'));
      final card = readDartLibrary('lib/features/redesign/presentation/widgets/event/rd_parent_event_card.dart');
      expect(card, contains('extraPlans: group.extraPlans'));
      expect(card, contains('durationDays: group.durationDays'));
    });
  });

  group('ASTRA_PARENTS signInAll', () {
    late _FakeSignInOutRepository repo;
    late ProviderContainer container;

    ProviderContainer make(Set<String> failing) => ProviderContainer(overrides: [
          signInOutRepositoryWithTenantProvider.overrideWith((ref) {
            repo = _FakeSignInOutRepository(ref, failing: failing);
            return repo;
          }),
        ]);

    tearDown(() => container.dispose());

    test('all children signed in → true, no error', () async {
      container = make({});
      final ok = await container.read(parentSignInOutNotifierProvider.notifier).signInAll([
        ('1', SignInType.normal),
        ('2', SignInType.late),
      ]);
      expect(ok, isTrue);
      expect(repo.calls, [('1', SignInType.normal), ('2', SignInType.late)]);
      expect(container.read(parentSignInOutNotifierProvider).hasError, isFalse);
    });

    test('a failing child is not hidden by a later success and aborts like Ionic', () async {
      container = make({'1'});
      final ok = await container.read(parentSignInOutNotifierProvider.notifier).signInAll([
        ('1', SignInType.normal),
        ('2', SignInType.normal),
      ]);
      expect(ok, isFalse);
      expect(repo.calls.map((c) => c.$1), ['1']);
      expect(container.read(parentSignInOutNotifierProvider).hasError, isTrue);
    });

    test('parent today widget uses signInAll and checks result before toast', () {
      final page = readDartLibrary('lib/features/redesign/presentation/widgets/today/rd_parent_today.dart');
      expect(page, contains('.signInAll(entries)'));
      expect(page, isNot(contains('notifier.signIn(')));
    });
  });
}
