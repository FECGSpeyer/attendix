import 'dart:async';

import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/features/redesign/data/rd_write_queue.dart';
import 'package:flutter_test/flutter_test.dart';

/// REDESIGN: writes of one person_attendances row across page copies.
void main() {
  test('tasks of a row run one after the other, other rows do not wait', () async {
    final queue = RdWriteQueue();
    final log = <String>[];
    final slow = Completer<void>();
    final first = queue.run('pa-1', () async {
      log.add('a start');
      await slow.future;
      log.add('a end');
    });
    final second = queue.run('pa-1', () async => log.add('b'));
    final other = queue.run('pa-2', () async => log.add('c'));
    await other;
    expect(log, ['a start', 'c']);
    expect(queue.isBusy('pa-1'), isTrue);
    expect(queue.isBusy('pa-2'), isFalse);

    slow.complete();
    await Future.wait([first, second]);
    expect(log, ['a start', 'c', 'a end', 'b']);
    expect(queue.isBusy('pa-1'), isFalse);
  });

  test('a failing task does not stop the next one and reaches its caller', () async {
    final queue = RdWriteQueue();
    final failing = queue.run<void>('pa-1', () async => throw StateError('weg'));
    final next = queue.run('pa-1', () async => 'ok');
    await expectLater(failing, throwsStateError);
    expect(await next, 'ok');
    expect(queue.isBusy('pa-1'), isFalse);
  });

  test('change numbers: only the newest change of a row counts', () {
    final queue = RdWriteQueue();
    final a = queue.nextRev('pa-1');
    final b = queue.nextRev('pa-1');
    final other = queue.nextRev('pa-2');
    expect(queue.isNewest('pa-1', a), isFalse);
    expect(queue.isNewest('pa-1', b), isTrue);
    expect(queue.isNewest('pa-2', other), isTrue);
  });

  test('stored status', () {
    final queue = RdWriteQueue();
    expect(queue.stored('pa-1'), isNull);
    queue.markStored('pa-1', AttendanceStatus.present);
    expect(queue.stored('pa-1'), AttendanceStatus.present);
  });
}
