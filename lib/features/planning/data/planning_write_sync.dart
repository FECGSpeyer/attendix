import 'package:flutter/foundation.dart';

import '../../../data/models/plan/plan.dart';

/// SOL_FIX27: process-wide coordination of the writes of every Ablaufplan
/// editor (`PlanningPage`) instance.
///
/// - **One write chain per (tenant, Termin)** ([run]): every write of every
///   editor instance runs only after the previous write of that Termin
///   finished, also when an editor that was left while a write ran and a
///   newly opened editor write at the same time.
/// - **Commits** ([commit]): every stored write gets a per-Termin sequence
///   number and remembers the editor instance ([newInstance], increasing in
///   creation order) that made it.
/// - **Rule for writes queued by a disposed editor**: such a write is skipped
///   when an editor instance created later has already stored the Termin
///   after the disposed editor's last own commit (or its load), see
///   [newerCommit]. The later editor is what the user saw and edited last,
///   so its write wins; the skipped edit is kept as a local draft only when
///   it differs from what the later editor stored.
/// - **Writes build on the newest stored row** (SOL_FIX28, [latestSince]):
///   an editor whose copy of the Termin is older than the newest commit
///   builds its write on that commit, so it replaces only the plan it edited
///   and never resets another editor's stored plan with its stale copy.
class PlanningWriteSync {
  PlanningWriteSync._();

  static int _instances = 0;
  static final Map<String, Future<void>> _tails = {};
  static final Map<String, int> _seq = {};

  /// Per key: editor instance → sequence number of its last commit.
  static final Map<String, Map<int, int>> _writers = {};

  /// Per key: the row returned by the newest commit.
  static final Map<String, PlanAttendance> _lastRow = {};

  /// Number of a new editor instance (later instances get larger numbers).
  static int newInstance() => ++_instances;

  /// Key of the chain of Termin [attId] in [tenantId].
  static String keyFor(int? tenantId, int attId) => '${tenantId ?? 0}_$attId';

  /// Runs [task] after every task queued before it under [key]. Errors
  /// reach the caller, never the chain.
  static Future<T> run<T>(String key, Future<T> Function() task) {
    final previous = _tails[key] ?? Future<void>.value();
    final result = previous.then((_) => task());
    late final Future<void> tail;
    tail = result.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (identical(_tails[key], tail)) _tails.remove(key);
    });
    _tails[key] = tail;
    return result;
  }

  /// Sequence number of the newest commit under [key] (0 before any).
  static int seq(String key) => _seq[key] ?? 0;

  /// Records a stored write of editor [instance]; returns its sequence number.
  static int commit(String key, int instance, PlanAttendance row) {
    final s = seq(key) + 1;
    _seq[key] = s;
    (_writers[key] ??= {})[instance] = s;
    _lastRow[key] = row;
    return s;
  }

  /// The newest stored row when an editor created after [instance] committed
  /// under [key] after sequence number [sinceSeq]; null otherwise.
  static PlanAttendance? newerCommit(String key, int instance, int sinceSeq) {
    final writers = _writers[key];
    if (writers == null) return null;
    final newer = writers.entries.any((e) => e.key > instance && e.value > sinceSeq);
    return newer ? _lastRow[key] : null;
  }

  /// SOL_FIX28: the newest stored row under [key] when it was committed after
  /// sequence number [sinceSeq] (by any editor instance, also a disposed
  /// one); null when the caller already knows the newest commit.
  static PlanAttendance? latestSince(String key, int sinceSeq) => seq(key) > sinceSeq ? _lastRow[key] : null;

  @visibleForTesting
  static void reset() {
    _tails.clear();
    _seq.clear();
    _writers.clear();
    _lastRow.clear();
  }
}
