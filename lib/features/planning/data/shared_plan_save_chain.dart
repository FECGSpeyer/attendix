import 'dart:async';

/// SOL_FIX15: serialised DB saves of the ad-hoc plans ("Meine Pläne").
///
/// - One chain per plan id: a save starts only after the previous save of
///   the same plan finished, so an older plan state can never be written
///   last (overlapping autosaves).
/// - Requests that arrive while a save runs collapse to the newest one,
///   which is saved right afterwards (pending changes are never dropped).
/// - Every save is bound to the account that requested it: right before
///   the write, [currentUserId] must still return that account, otherwise
///   nothing is written and the save reports `false`.
/// - The returned future reports explicitly whether the requested state (or
///   a newer one that superseded it) reached the database; errors never
///   escape.
class SharedPlanSaveChain {
  SharedPlanSaveChain({required this.currentUserId});

  /// Signed-in account at the moment of the write (null = signed out).
  final String? Function() currentUserId;

  final _latest = <String, _PendingSave>{};
  final _tails = <String, Future<bool>>{};
  final _lastResult = <String, bool>{};

  /// Whether a save of [planId] is queued or running.
  bool isBusy(String planId) => _tails.containsKey(planId);

  /// Queues the save of plan [planId] for [accountId]; [write] performs the
  /// upsert of the state captured when this method was called.
  Future<bool> save(
    String planId, {
    required String accountId,
    required Future<void> Function() write,
  }) {
    _latest[planId] = _PendingSave(accountId, write);
    final previous = _tails[planId] ?? Future<bool>.value(true);
    late final Future<bool> next;
    next = previous.then((_) => _run(planId)).whenComplete(() {
      if (identical(_tails[planId], next)) _tails.remove(planId);
    });
    _tails[planId] = next;
    return next;
  }

  /// Completes once every queued save of [planId] has finished.
  Future<void> flush(String planId) async {
    final tail = _tails[planId];
    if (tail != null) await tail;
  }

  Future<bool> _run(String planId) async {
    final pending = _latest.remove(planId);
    // Already written by an earlier run (collapsed into the newest state).
    if (pending == null) return _lastResult[planId] ?? false;
    var ok = false;
    try {
      if (currentUserId() == pending.accountId) {
        await pending.write();
        ok = true;
      }
    } catch (_) {
      ok = false;
    }
    _lastResult[planId] = ok;
    return ok;
  }
}

class _PendingSave {
  _PendingSave(this.accountId, this.write);
  final String accountId;
  final Future<void> Function() write;
}
