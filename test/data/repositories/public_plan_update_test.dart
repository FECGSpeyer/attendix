import 'dart:io';

import 'package:attendix/data/models/plan/plan.dart';
import 'package:attendix/data/repositories/public_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// SOL_FIX12: editing a shared ad-hoc plan persists the recomputed end time.
void main() {
  const fields = [PlanField(id: 'a', name: 'Gebet', time: '10')];

  test('update data carries end_time together with time and fields', () {
    final data = PublicPlanRepository.sharedPlanUpdateData(
      fields: fields,
      title: 'Ablauf',
      time: '2026-11-01T10:00',
      endTime: '2026-11-01T10:10',
    );
    expect(data['time'], '2026-11-01T10:00');
    expect(data['end_time'], '2026-11-01T10:10');
    expect(data['plan_title'], 'Ablauf');
    expect(data['fields'], [fields.first.toJson()]);
  });

  test('an unknown end is not written', () {
    final data = PublicPlanRepository.sharedPlanUpdateData(fields: fields, endTime: '');
    expect(data.containsKey('end_time'), isFalse);
  });

  test('shared plan page saves the recomputed end', () {
    final page = File('lib/features/planning/presentation/pages/shared_plan_page.dart').readAsStringSync();
    expect(page, contains('updateSharedPlan(key, editKey, fields: _fields, title: _title, time: _time, endTime: _end)'));
  });

  test('repository still filters the update by id and edit_key', () {
    final repo = File('lib/data/repositories/public_plan_repository.dart').readAsStringSync();
    final start = repo.indexOf('Future<void> updateSharedPlan(');
    final body = repo.substring(start, repo.indexOf('handleError', start));
    expect(body, contains('sharedPlanUpdateData('));
    expect(body, contains(".eq('id', key)"));
    expect(body, contains(".eq('edit_key', editKey)"));
  });
}
