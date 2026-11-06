import 'dart:io';

import 'package:attendix/core/utils/choir_file_utils.dart';
import 'package:attendix/features/redesign/data/import/rd_import_ai.dart';
import 'package:attendix/features/redesign/data/import/rd_import_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

const _q = [
  RdImportQuestion(key: 'sax', label: 'Sax', fileCount: 4, works: ['Wie wunderbar'], files: ['Sax 1.pdf', 'Sax 2.pdf']),
  RdImportQuestion(key: 'qfl', label: 'Qfl', fileCount: 2, works: ['Eins'], files: ['Qfl1.pdf']),
  RdImportQuestion(key: 'kl', label: 'Kl', fileCount: 2, works: ['Eins']),
];

void main() {
  group('category of an answer', () {
    Map<String, dynamic> a(String kind, [Map<String, dynamic> more = const {}]) => {'kind': kind, ...more};
    RdImportCategory? cat(Map<String, dynamic> answer, {bool isChoir = false}) =>
        rdImportAiCategory(answer, groups: {10, 14}, isChoir: isChoir);

    test('groups only of the tenant; new groups with a short name', () {
      expect(cat(a('group', {'groupId': 14})), const RdImportCategory(instrumentId: 14));
      expect(cat(a('group', {'groupId': 99})), isNull);
      expect(cat(a('group', {'groupId': '14'})), isNull);
      expect(cat(a('new', {'newGroup': ' Saxophon '})), const RdImportCategory(newGroup: 'Saxophon'));
      expect(cat(a('new', {'newGroup': ''})), isNull);
      expect(cat(a('new', {'newGroup': 'x' * 41})), isNull);
    });

    test('kinds of files', () {
      expect(cat(a('recording')), const RdImportCategory(instrumentId: 1));
      expect(cat(a('lyrics')), const RdImportCategory(instrumentId: 2));
      expect(cat(a('score')), const RdImportCategory(note: 'Partitur'));
      expect(cat(a('piano')), const RdImportCategory(note: 'Klavierauszug'));
      expect(cat(a('sibelius')), const RdImportCategory(note: 'Sibelius'));
      expect(cat(a('midi')), const RdImportCategory(note: 'MIDI'));
      expect(cat(a('other')), RdImportCategory.other);
      expect(cat(a('choir')), isNull);
      expect(cat(a('choir'), isChoir: true), const RdImportCategory(note: kChoirAllNote));
      expect(cat(a('delete everything')), isNull);
    });
  });

  group('suggest', () {
    test('one request with names and samples; only fitting answers count', () async {
      final calls = <Map<String, dynamic>>[];
      final ai = RdImportAi((body) async {
        calls.add(body);
        return {
          'answers': [
            {'key': 'sax', 'kind': 'new', 'newGroup': 'Saxophon', 'confidence': 'high'},
            {'key': 'qfl', 'kind': 'group', 'groupId': 14, 'confidence': 'low'},
            {'key': 'qfl', 'kind': 'group', 'groupId': 10, 'confidence': 'high'},
            {'key': 'kl', 'kind': 'group', 'groupId': 77, 'confidence': 'high'},
            {'key': 'other', 'kind': 'score', 'confidence': 'high'},
          ],
        };
      });
      final r = await ai.suggest(7, _q, groups: {10, 14}, isChoir: false);
      expect(calls, hasLength(1));
      expect(calls.single['tenantId'], 7);
      expect(calls.single['questions'], [
        {'key': 'sax', 'label': 'Sax', 'files': ['Sax 1.pdf', 'Sax 2.pdf'], 'works': ['Wie wunderbar']},
        {'key': 'qfl', 'label': 'Qfl', 'files': ['Qfl1.pdf'], 'works': ['Eins']},
        {'key': 'kl', 'label': 'Kl', 'files': <String>[], 'works': ['Eins']},
      ]);
      expect(r.status, RdImportAiStatus.done);
      expect(r.answers, {
        'sax': const RdImportAiAnswer(RdImportCategory(newGroup: 'Saxophon'), sure: true),
        'qfl': const RdImportAiAnswer(RdImportCategory(instrumentId: 14), sure: false),
      });
    });

    test('the day\'s limit, an error or a strange answer: no suggestions', () async {
      final limit = await RdImportAi((_) async => throw const FunctionException(status: 429, details: {'error': 'daily limit reached'}))
          .suggest(7, _q, groups: {10}, isChoir: false);
      expect(limit.status, RdImportAiStatus.limit);
      expect(limit.answers, isEmpty);
      final failed = await RdImportAi((_) async => throw const FunctionException(status: 404)).suggest(7, _q, groups: {10}, isChoir: false);
      expect(failed.status, RdImportAiStatus.failed);
      final odd = await RdImportAi((_) async => 'no json').suggest(7, _q, groups: {10}, isChoir: false);
      expect(odd.status, RdImportAiStatus.failed);
      final empty = await RdImportAi((_) async => {'answers': 'none'}).suggest(7, _q, groups: {10}, isChoir: false);
      expect(empty.status, RdImportAiStatus.done);
      expect(empty.answers, isEmpty);
    });

    test('nothing to ask: no request', () async {
      var called = false;
      final ai = RdImportAi((_) async {
        called = true;
        return {};
      });
      final r = await ai.suggest(7, const [RdImportQuestion(key: 'a/b', label: 'a/b', fileCount: 2, works: [])], groups: {}, isChoir: false);
      expect(r.status, RdImportAiStatus.off);
      expect(called, isFalse);
    });
  });

  test('the function checks the account, the tenant, the budget and every answer', () {
    final src = File('supabase/functions/part-suggest/index.ts').readAsStringSync();
    expect(src, contains('auth.getUser()'));
    expect(src, contains('.in("role", EDIT_ROLES)'));
    expect(src, contains('.eq("tenantId", tenantId)'));
    expect(src, contains('part_detect_take'));
    // The budget is taken before the paid call.
    expect(src.indexOf('part_detect_take'), lessThan(src.indexOf('chat.completions.create')));
    // Answers only for asked keys and the tenant's groups.
    expect(src, contains('keys.has(key)'));
    expect(src, contains('groups.some((g) => g.id === id)'));
    expect(src, contains('KINDS.has(kind)'));
    // No other outgoing request than the model.
    expect(src, isNot(contains('fetch(')));
  });
}
