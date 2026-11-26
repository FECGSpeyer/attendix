import 'package:flutter/material.dart';

import '../../data/help_models.dart';
import 'help_markdown.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Shows a glossary definition (port of Ionic `HelpGlossaryPopoverComponent`):
/// an `ion-popover` at the tapped term ([anchor], global coordinates) with an
/// `ion-card` – the term as card title, the definition below. No button, a
/// tap outside closes it (Ionic `.help-glossary-popover`: `--width:
/// min(90vw, 420px)`, `--max-height: 70vh`).
Future<void> showGlossaryTermPopover(
  BuildContext context,
  GlossaryTerm term, {
  required Rect anchor,
}) {
  final size = MediaQuery.sizeOf(context);
  return showAppPopover<void>(
    context: context,
    anchor: anchor,
    width: size.width * 0.9 < 420 ? size.width * 0.9 : 420,
    maxHeight: size.height * 0.7,
    builder: (context) {
      final onSurface = Theme.of(context).colorScheme.onSurface;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              term.term,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: HelpMarkdown(
              data: term.definition,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      );
    },
  );
}
