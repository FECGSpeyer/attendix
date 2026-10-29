// SOL_FIX15: autosaves of "Meine Pläne" (public planning page) are
// serialised per plan, bound to the account and report success explicitly.
import 'dart:async';
import 'dart:io';

import 'package:attendix/features/planning/data/shared_plan_save_chain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SharedPlanSaveChain', () {
    late String? user;
    late SharedPlanSaveChain chain;
    late List<String> written;

    setUp(() {
      user = 'user-a';
      chain = SharedPlanSaveChain(currentUserId: () => user);
      written = [];
    });

    test('edits queued before a save starts collapse to the newest', () async {
      final f1 = chain.save('p1',
          accountId: 'user-a', write: () async => written.add('v1'));
      final f2 = chain.save('p1',
          accountId: 'user-a', write: () async => written.add('v2'));
      expect(await Future.wait([f1, f2]), [true, true]);
      expect(written, ['v2']);
    });

    test('reports success and failure explicitly', () async {
      expect(
          await chain.save('p1',
              accountId: 'user-a', write: () async => written.add('v1')),
          isTrue);
      expect(
          await chain.save('p1',
              accountId: 'user-a', write: () async => throw Exception('net')),
          isFalse);
      expect(written, ['v1']);
    });

    test('overlapping saves never write an older state last', () async {
      final first = Completer<void>();
      final f1 = chain.save('p1', accountId: 'user-a', write: () async {
        await first.future; // slow request
        written.add('v1');
      });
      await Future<void>.delayed(Duration.zero);
      expect(chain.isBusy('p1'), isTrue);
      // Two more edits while v1 is in flight: v2 is superseded by v3.
      final f2 = chain.save('p1',
          accountId: 'user-a', write: () async => written.add('v2'));
      final f3 = chain.save('p1',
          accountId: 'user-a', write: () async => written.add('v3'));
      first.complete();
      expect(await Future.wait([f1, f2, f3]), [true, true, true]);
      expect(written, ['v1', 'v3']);
      expect(written.last, 'v3');
      expect(chain.isBusy('p1'), isFalse);
    });

    test('a pending save after a failed one still runs', () async {
      final f1 = chain.save('p1',
          accountId: 'user-a', write: () async => throw Exception('net'));
      await Future<void>.delayed(Duration.zero); // f1 is running
      final f2 = chain.save('p1',
          accountId: 'user-a', write: () async => written.add('v2'));
      expect(await f1, isFalse);
      expect(await f2, isTrue);
      expect(written, ['v2']);
    });

    test('different plans are independent', () async {
      final slow = Completer<void>();
      final a = chain.save('p1', accountId: 'user-a', write: () async {
        await slow.future;
        written.add('p1');
      });
      final b = chain.save('p2',
          accountId: 'user-a', write: () async => written.add('p2'));
      expect(await b, isTrue);
      expect(written, ['p2']);
      slow.complete();
      expect(await a, isTrue);
    });

    test('nothing is written after an account switch', () async {
      final first = Completer<void>();
      final f1 = chain.save('p1', accountId: 'user-a', write: () async {
        await first.future;
        written.add('v1');
      });
      await Future<void>.delayed(Duration.zero); // f1 is running
      final f2 = chain.save('p1',
          accountId: 'user-a', write: () async => written.add('v2'));
      user = 'user-b';
      first.complete();
      expect(await f1, isTrue); // started before the switch
      expect(await f2, isFalse);
      expect(written, ['v1']);

      expect(
          await chain.save('p1',
              accountId: 'user-a', write: () async => written.add('v3')),
          isFalse);
      user = null;
      expect(
          await chain.save('p1',
              accountId: 'user-a', write: () async => written.add('v4')),
          isFalse);
      expect(written, ['v1']);
    });

    test('flush waits for every queued save', () async {
      final slow = Completer<void>();
      unawaited(chain.save('p1', accountId: 'user-a', write: () async {
        await slow.future;
        written.add('v1');
      }));
      var flushed = false;
      unawaited(chain.flush('p1').then((_) => flushed = true));
      await Future<void>.delayed(Duration.zero);
      expect(flushed, isFalse);
      slow.complete();
      await chain.flush('p1');
      expect(written, ['v1']);
    });
  });

  group('public planning page wiring (source analysis)', () {
    final src = File(
            'lib/features/planning/presentation/pages/public_planning_page.dart')
        .readAsStringSync();

    String method(String signature) {
      final start = src.indexOf(signature);
      expect(start, isNot(-1), reason: signature);
      final end = src.indexOf('\n  }\n', start);
      return src.substring(start, end);
    }

    test('saves go through the chain, bound to the account', () {
      final body = method('Future<bool> _persistToDb(');
      expect(body, contains('_saveChain.save('));
      expect(body, contains('accountId: account'));
      expect(body, contains('expectedUserId: account'));
      expect(body, isNot(contains('catch (_) {}')));
    });

    test('a new plan id is only taken over after a successful save', () {
      final body = method('Future<bool> _persistToDb(');
      final save = body.indexOf('_saveChain.save(');
      final ok = body.indexOf('if (!ok) return false;');
      final assign = body.indexOf('_planId = id;');
      expect(save, greaterThan(0));
      expect(ok, greaterThan(save));
      expect(assign, greaterThan(ok));
      // Never assigned before the save.
      expect(body.substring(0, save), isNot(contains('_planId = ')));
    });

    test('sharing and adding to the organisation require a successful save',
        () {
      expect(method('Future<void> _doShare('),
          contains('if (!await _persistToDb() || _planId == null)'));
      expect(method('Future<void> _toggleOrg('),
          contains('if (!await _persistToDb() || _planId == null)'));
    });

    test('a failed autosave shows an error toast', () {
      final body = method('Future<void> _autosave(');
      expect(body, contains('ToastHelper.showError('));
      expect(body, contains('plansSavePlanFailed'));
    });

    test('leaving the page flushes a pending debounced save', () {
      final body = method('void dispose()');
      final flush = body.indexOf('_persistToDb(repo: _dbRepo)');
      expect(flush, greaterThan(0));
      expect(flush, lessThan(body.indexOf('_titleController.dispose()')));
      // The flush never needs `ref` after dispose.
      expect(src, contains('_container.invalidate(mySharedPlansProvider)'));
      expect(src, contains('String? get _currentUserId => _auth?.currentUser?.id;'));
    });

    test('switching plans saves pending changes of the previous plan', () {
      expect(method('Future<void> _newPlan('), contains('_flushPendingSave();'));
      expect(method('void _loadPlan('), contains('_flushPendingSave();'));
    });
  });
}
