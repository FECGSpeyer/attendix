import 'package:attendix/core/providers/team_org_providers.dart';
import 'package:attendix/data/models/team_org/team_org.dart';
import 'package:attendix/data/repositories/protocol_repository.dart';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo extends ProtocolRepository {
  _Repo(super.ref);
  ProtocolAttendance? fresh;
  Map<String, dynamic>? written;

  @override
  Future<ProtocolAttendance?> getAttendance(int attendanceId) async => fresh;

  @override
  Future<Map<String, dynamic>?> updateAttendancePlan(
      int attendanceId, Map<String, dynamic> plan) async {
    written = plan;
    return plan;
  }
}

final _repoProvider = Provider<_Repo>((ref) => _Repo(ref));

/// SOL_FIX32: the topic picker must not write back a plan that was deleted
/// since it opened.
void main() {
  ProtocolAttendance att({Map<String, dynamic>? plan}) =>
      ProtocolAttendance(id: 1, date: '2026-10-29', plan: plan);

  test('deleted plan → conflict, nothing written', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final repo = c.read(_repoProvider)..fresh = att();
    await expectLater(
      addTopicsToAttendance(repo, att(plan: {'fields': <dynamic>[]}), null, const []),
      throwsStateError,
    );
    expect(repo.written, isNull);
  });

  test('existing plan → written', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final repo = c.read(_repoProvider)..fresh = att(plan: {'fields': <dynamic>[]});
    await addTopicsToAttendance(repo, att(plan: {'fields': <dynamic>[]}), null, const []);
    expect(repo.written, isNotNull);
  });

  test('updateAttendancePlan fails when no row was updated', () {
    final src = File('lib/data/repositories/protocol_repository.dart').readAsStringSync();
    final start = src.indexOf('updateAttendancePlan(');
    final body = src.substring(start, src.indexOf('catch (e, stack)', start));
    expect(body, contains('if (response == null)'));
    expect(body, contains('throw StateError'));
  });

  test('SOL_FIX33: spontaneous point aborts on a deleted plan', () {
    final src = File('lib/features/team_organization/presentation/pages/protocol_page.dart')
        .readAsStringSync();
    expect(src, contains('fresh.plan == null && current.plan != null'));
    // SOL_FIX34: the conflict is checked before the topic is created.
    expect(src.indexOf('fresh.plan == null && current.plan != null'),
        lessThan(src.indexOf('_agendaRepo.createAgendaItem(')));
    expect(src, isNot(contains('if (fresh != null) current = _attendance!.copyWith(plan: fresh.plan);')));
  });

  test('SOL_FIX33: topic writes refresh the plan caches', () {
    for (final path in [
      'lib/features/team_organization/presentation/pages/protocol_page.dart',
      'lib/features/team_organization/presentation/widgets/agenda_picker_sheet.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, contains('container.invalidate(planAttendancesProvider);'), reason: path);
      expect(src, contains('container.invalidate(orgPlansProvider);'), reason: path);
      expect(src, contains('ProviderScope.containerOf(context, listen: false)'), reason: path);
    }
  });
}
