import 'dart:convert';

/// How a realtime row relates to the own writes of the shared plan page.
enum EchoKind {
  /// Echo of the newest own write (the state the editor already holds).
  latestOwn,

  /// Echo of an own write that a newer own write has replaced: stale.
  olderOwn,

  /// Not one of the remembered own writes (another editor, the app).
  foreign,
}

/// Remembers the written columns of the last [capacity] own writes, so a
/// delayed realtime echo of an older own write can be told apart from the echo
/// of the newest one and from a foreign change. Values are compared as
/// canonical JSON (sorted keys, nulls dropped), so the echo matches no matter
/// how the database orders the jsonb keys.
///
/// The tables carry no server revision (`attendance` and `shared_plans` have no
/// `updated_at`), so echoes are matched by content, but each own write
/// suppresses at most ONE matching echo: a matching echo consumes its write.
/// A write that completed more than [window] ago no longer matches. Once the
/// echo of a write arrives (or its window expires), that write and every older
/// one are dropped.
class OwnWriteLog {
  OwnWriteLog({
    this.capacity = 10,
    this.window = const Duration(seconds: 15),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int capacity;

  /// How long after a write completed its echo is expected.
  final Duration window;
  final DateTime Function() _clock;
  final _writes = <_OwnWrite>[];
  int _nextId = 0;

  /// Records a write of [columns] (call before sending it); returns its id.
  int record(Map<String, dynamic> columns) {
    final id = _nextId++;
    _writes.add(_OwnWrite(id, {for (final e in columns.entries) e.key: canonicalJson(e.value)}));
    if (_writes.length > capacity) _writes.removeAt(0);
    return id;
  }

  /// Marks write [id] as stored; its echo window starts now.
  void complete(int id) {
    for (final w in _writes) {
      if (w.id == id) w.completedAt = _clock();
    }
  }

  /// Forgets a write that failed (it is not the stored state).
  void forget(int id) => _writes.removeWhere((w) => w.id == id);

  /// Classifies an incoming [row]: the newest matching own write that has
  /// not been echoed yet decides, and is consumed by it.
  EchoKind classify(Map<String, dynamic> row) {
    _prune();
    for (var i = _writes.length - 1; i >= 0; i--) {
      final w = _writes[i];
      if (w.echoed) continue;
      final matches = w.columns.entries.every((c) => row.containsKey(c.key) && canonicalJson(row[c.key]) == c.value);
      if (!matches) continue;
      final kind = i == _writes.length - 1 ? EchoKind.latestOwn : EchoKind.olderOwn;
      w.echoed = true;
      _prune();
      return kind;
    }
    return EchoKind.foreign;
  }

  /// Drops the newest write that was echoed or whose window expired, and
  /// every older write.
  void _prune() {
    final now = _clock();
    for (var i = _writes.length - 1; i >= 0; i--) {
      final w = _writes[i];
      final done = w.completedAt;
      if (w.echoed || (done != null && now.difference(done) > window)) {
        _writes.removeRange(0, i + 1);
        return;
      }
    }
  }

  /// Canonical JSON of [value]: map keys sorted, null values dropped,
  /// integral doubles as ints (jsonb returns `1` for a written `1.0`).
  static String canonicalJson(Object? value) {
    Object? norm(Object? v) {
      if (v is Map) {
        final keys = v.keys.map((k) => k.toString()).toList()..sort();
        return {
          for (final k in keys)
            if (v[k] != null) k: norm(v[k]),
        };
      }
      if (v is List) return v.map(norm).toList();
      if (v is double && v == v.truncateToDouble() && v.isFinite) return v.toInt();
      return v;
    }

    return jsonEncode(norm(jsonDecode(jsonEncode(value))));
  }
}

class _OwnWrite {
  _OwnWrite(this.id, this.columns);

  final int id;
  final Map<String, String> columns;

  /// Set once the write was stored (null while it runs: no expiry yet).
  DateTime? completedAt;

  /// Its echo arrived (it suppresses no further row).
  bool echoed = false;
}
