import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// Lightweight renderer for the help-center markdown subset.
///
/// Port of Ionic `help-markdown.util.ts` (marked with `breaks: true`).
/// Supports paragraphs, single line breaks, `- ` bullet lists, `1. ` numbered
/// lists, `**bold**`, `*italic*`, `` `code` `` and glossary references
/// `[[Begriff]]` / `[[Begriff|Anzeigetext]]`.
///
/// When [onGlossaryTap] is null, glossary references render as italic text
/// (Ionic `renderGlossaryDefinitionHtml`).
class HelpMarkdown extends StatefulWidget {
  const HelpMarkdown({
    super.key,
    required this.data,
    this.onGlossaryTap,
    this.style,
  });

  final String data;
  final void Function(String term)? onGlossaryTap;
  final TextStyle? style;

  @override
  State<HelpMarkdown> createState() => _HelpMarkdownState();
}

class _HelpMarkdownState extends State<HelpMarkdown> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final baseStyle = widget.style ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45) ??
        const TextStyle(height: 1.45);
    final blocks = parseHelpMarkdownBlocks(widget.data);

    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (i > 0) children.add(const SizedBox(height: AppDimensions.paddingS));
      switch (block) {
        case HelpParagraph(:final text):
          children.add(Text.rich(
            TextSpan(style: baseStyle, children: _inline(text, baseStyle)),
          ));
        case HelpList(:final items, :final ordered):
          for (var n = 0; n < items.length; n++) {
            children.add(Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: ordered ? 24 : 16,
                    child: Text(ordered ? '${n + 1}.' : '•', style: baseStyle),
                  ),
                  Expanded(
                    child: Text.rich(TextSpan(
                      style: baseStyle,
                      children: _inline(items[n], baseStyle),
                    )),
                  ),
                ],
              ),
            ));
          }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  List<InlineSpan> _inline(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    for (final token in parseHelpInline(text)) {
      var style = const TextStyle();
      if (token.bold) style = style.copyWith(fontWeight: FontWeight.w600);
      if (token.italic) style = style.copyWith(fontStyle: FontStyle.italic);
      if (token.code) {
        style = style.copyWith(
          fontFamily: 'monospace',
          backgroundColor: AppColors.medium.withValues(alpha: 0.12),
        );
      }
      final glossaryTerm = token.glossaryTerm;
      if (glossaryTerm != null) {
        final onTap = widget.onGlossaryTap;
        if (onTap == null) {
          style = style.copyWith(fontStyle: FontStyle.italic);
          spans.add(TextSpan(text: token.text, style: style));
        } else {
          final recognizer = TapGestureRecognizer()
            ..onTap = () => onTap(glossaryTerm);
          _recognizers.add(recognizer);
          spans.add(TextSpan(
            text: token.text,
            style: style.copyWith(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
            ),
            recognizer: recognizer,
          ));
        }
      } else {
        spans.add(TextSpan(text: token.text, style: style));
      }
    }
    return spans;
  }
}

// ---------------------------------------------------------------------------
// Parsing (pure functions, unit-tested)
// ---------------------------------------------------------------------------

sealed class HelpBlock {
  const HelpBlock();
}

class HelpParagraph extends HelpBlock {
  const HelpParagraph(this.text);
  final String text;
}

class HelpList extends HelpBlock {
  const HelpList(this.items, {required this.ordered});
  final List<String> items;
  final bool ordered;
}

final _bulletRe = RegExp(r'^\s*[-*]\s+(.*)$');
final _orderedRe = RegExp(r'^\s*\d+\.\s+(.*)$');

/// Splits markdown into paragraphs and flat lists.
List<HelpBlock> parseHelpMarkdownBlocks(String source) {
  final blocks = <HelpBlock>[];
  final para = <String>[];
  List<String>? listItems;
  var listOrdered = false;

  void flushPara() {
    if (para.isNotEmpty) {
      blocks.add(HelpParagraph(para.join('\n')));
      para.clear();
    }
  }

  void flushList() {
    if (listItems != null && listItems!.isNotEmpty) {
      blocks.add(HelpList(List.of(listItems!), ordered: listOrdered));
    }
    listItems = null;
  }

  for (final rawLine in source.replaceAll('\r\n', '\n').split('\n')) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty) {
      flushPara();
      flushList();
      continue;
    }
    final bullet = _bulletRe.firstMatch(line);
    final ordered = bullet == null ? _orderedRe.firstMatch(line) : null;
    if (bullet != null || ordered != null) {
      flushPara();
      final isOrdered = ordered != null;
      if (listItems != null && listOrdered != isOrdered) flushList();
      listItems ??= [];
      listOrdered = isOrdered;
      listItems!.add((bullet ?? ordered)!.group(1)!);
    } else if (listItems != null && rawLine.startsWith(RegExp(r'\s'))) {
      // Continuation line of a list item.
      listItems![listItems!.length - 1] += '\n${line.trim()}';
    } else {
      flushList();
      para.add(line);
    }
  }
  flushPara();
  flushList();
  return blocks;
}

class HelpInlineToken {
  const HelpInlineToken(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.glossaryTerm,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool code;

  /// Referenced glossary term name (not the display text), if a link.
  final String? glossaryTerm;
}

final _inlineRe = RegExp(
  r'\[\[([^\]|]+)(?:\|([^\]]+))?\]\]' // 1,2: glossary
  r'|\*\*(.+?)\*\*' // 3: bold
  r'|(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])' // 4: italic
  r'|`([^`]+)`', // 5: code
);

/// Splits a text run into styled inline tokens. Bold/italic content may itself
/// contain glossary references.
List<HelpInlineToken> parseHelpInline(
  String text, {
  bool bold = false,
  bool italic = false,
}) {
  final tokens = <HelpInlineToken>[];
  var last = 0;
  for (final m in _inlineRe.allMatches(text)) {
    if (m.start > last) {
      tokens.add(HelpInlineToken(text.substring(last, m.start),
          bold: bold, italic: italic));
    }
    if (m.group(1) != null) {
      final term = m.group(1)!.trim();
      tokens.add(HelpInlineToken(
        (m.group(2) ?? term).trim(),
        bold: bold,
        italic: italic,
        glossaryTerm: term,
      ));
    } else if (m.group(3) != null) {
      tokens.addAll(parseHelpInline(m.group(3)!, bold: true, italic: italic));
    } else if (m.group(4) != null) {
      tokens.addAll(parseHelpInline(m.group(4)!, bold: bold, italic: true));
    } else if (m.group(5) != null) {
      tokens.add(HelpInlineToken(m.group(5)!,
          bold: bold, italic: italic, code: true));
    }
    last = m.end;
  }
  if (last < text.length) {
    tokens.add(
        HelpInlineToken(text.substring(last), bold: bold, italic: italic));
  }
  return tokens;
}
