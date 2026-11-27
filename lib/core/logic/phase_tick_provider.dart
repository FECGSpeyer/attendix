import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Start and end of a Termin (see `rdEventSpan`).
typedef RdPhaseTickKey = ({DateTime start, DateTime end});

/// REDESIGN (concept "Termin-Bereich neu"): emits whenever the phase of a
/// Termin can change without new data: at its start and end, at midnight
/// ("Morgen" → "Heute", "Heute" → "Gestern"), once a minute on the Termin
/// day before the start ("in 40 Min.") and once a minute while it runs
/// (the Ablauf may start later, "Jetzt im Ablauf" moves on). Termin pages
/// watch it so their head and top card move on by themselves.
final rdPhaseTickProvider = StreamProvider.autoDispose.family<DateTime, RdPhaseTickKey>((ref, span) {
  final controller = StreamController<DateTime>();
  Timer? timer;

  void schedule() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    var next = midnight;
    for (final t in [span.start, span.end]) {
      if (t.isAfter(now) && t.isBefore(next)) next = t;
    }
    final sameDay = now.year == span.start.year && now.month == span.start.month && now.day == span.start.day;
    final running = !now.isBefore(span.start) && now.isBefore(span.end);
    if ((sameDay && now.isBefore(span.start)) || running) {
      final minute = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
      if (minute.isBefore(next)) next = minute;
    }
    timer = Timer(next.difference(now) + const Duration(milliseconds: 500), () {
      if (controller.isClosed) return;
      controller.add(DateTime.now());
      schedule();
    });
  }

  schedule();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});
