import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SOL_FIX12: "Weitere Notizen" (notes of removed plan items) are shown from
/// the leftover's own document (Ionic `[content]="l.doc"`) — the controller
/// is cached under `leftover:<key>`, but the notes are stored under the
/// original section key, so `_docs['leftover:<key>']` would be empty.
void main() {
  final page = File('lib/features/team_organization/presentation/pages/protocol_page.dart')
      .readAsStringSync();

  test('every leftover editor is created from the leftover document', () {
    final calls = RegExp(r"_controllerFor\('leftover:[^;]*").allMatches(page).map((m) => m.group(0)!).toList();
    expect(calls, isNotEmpty);
    for (final call in calls) {
      expect(call, contains('initialDoc: l.doc'));
    }
  });

  test('controllerFor prefers the given document over the cache key', () {
    expect(page, contains('tiptapToDelta(initialDoc ?? _docs[id])'));
  });
}
