// Every IconButton needs a name for VoiceOver / TalkBack: a `tooltip` or a
// `semanticLabel` on its Icon. Without one the screen reader only says
// "Taste" / "button".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every IconButton has a tooltip or a semanticLabel', () {
    final missing = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'));
    for (final f in files) {
      final s = f.readAsStringSync();
      for (final m in RegExp(r'IconButton(\.(filled|outlined|filledTonal))?\(').allMatches(s)) {
        var i = m.end;
        var depth = 1;
        while (depth > 0 && i < s.length) {
          if (s[i] == '(') depth++;
          if (s[i] == ')') depth--;
          i++;
        }
        final body = s.substring(m.end, i - 1);
        final lineStart = s.lastIndexOf('\n', m.start) + 1;
        if (s.substring(lineStart, m.start).trimLeft().startsWith('//')) continue; // doc comment
        if (body.contains('tooltip') || body.contains('semanticLabel')) continue;
        final line = '\n'.allMatches(s.substring(0, m.start)).length + 1;
        missing.add('${f.path}:$line');
      }
    }
    expect(missing, isEmpty, reason: 'IconButton without tooltip/semanticLabel:\n${missing.join('\n')}');
  });
}
