import 'package:flutter/material.dart';

/// Splits an i18n `*Html` message (Ionic renders these via innerHTML) into
/// text spans: `<strong>`/`<b>` parts become bold, every other tag is dropped.
List<InlineSpan> strongHtmlSpans(String html) {
  final spans = <InlineSpan>[];
  final re = RegExp(r'<(strong|b)>(.*?)</\1>', dotAll: true);
  var pos = 0;
  for (final m in re.allMatches(html)) {
    if (m.start > pos) spans.add(TextSpan(text: _stripTags(html.substring(pos, m.start))));
    spans.add(TextSpan(
      text: _stripTags(m.group(2)!),
      style: const TextStyle(fontWeight: FontWeight.bold),
    ));
    pos = m.end;
  }
  if (pos < html.length) spans.add(TextSpan(text: _stripTags(html.substring(pos))));
  return spans;
}

String _stripTags(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');

/// [Text.rich] for an i18n `*Html` message with `<strong>` markup.
class StrongHtmlText extends StatelessWidget {
  const StrongHtmlText(this.html, {super.key, this.style, this.textAlign});

  final String html;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: strongHtmlSpans(html)),
        style: style,
        textAlign: textAlign,
      );
}
