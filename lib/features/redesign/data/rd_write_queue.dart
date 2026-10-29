import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';

/// REDESIGN: the writes of one `person_attendances` row (status, note) across
/// every copy of the Termin page, also one that was left and opened again:
///
/// - they run one after the other ([run]), so a slow earlier write never
///   lands after a later one such as "Rückgängig";
/// - every status change takes a change number ([nextRev]); a write only
///   runs and only rolls back while its change is still the row's newest, so
///   an older write (also of a page that was left meanwhile) can neither
///   overwrite nor reset a newer choice;
/// - a failed newest write rolls back to the status last known to be stored
///   ([stored]), not to an in-between choice that was never written.
///
/// Keyed by the row id (unique across tenants); a write of another account
/// or tenant is stopped by the write session bound in
/// `PersonAttendanceWriter`.
class RdWriteQueue {
  final Map<String, Future<void>> _tails = {};
  final Map<String, int> _revs = {};
  final Map<String, AttendanceStatus> _stored = {};

  /// Takes the next change number of [rowId].
  int nextRev(String rowId) => _revs[rowId] = (_revs[rowId] ?? 0) + 1;

  /// Whether [rev] is still the newest change of [rowId].
  bool isNewest(String rowId, int rev) => _revs[rowId] == rev;

  /// Whether writes of [rowId] are waiting or running.
  bool isBusy(String rowId) => _tails.containsKey(rowId);

  /// The status of [rowId] last known to be stored: the last successful
  /// (or offline queued) write, or the database row read while no write
  /// was pending.
  AttendanceStatus? stored(String rowId) => _stored[rowId];

  void markStored(String rowId, AttendanceStatus status) => _stored[rowId] = status;

  /// Runs [task] once every earlier task of [rowId] has finished.
  Future<T> run<T>(String rowId, Future<T> Function() task) {
    final before = _tails[rowId] ?? Future<void>.value();
    late final Future<void> tail;
    final result = before.then((_) => task());
    tail = result.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_tails[rowId], tail)) _tails.remove(rowId);
    });
    _tails[rowId] = tail;
    return result;
  }
}

/// One queue for the whole app session (see [RdWriteQueue]).
final rdWriteQueueProvider = Provider<RdWriteQueue>((ref) => RdWriteQueue());
