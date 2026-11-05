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
      final ios = useIosLook(context);
      final onSurface = Theme.of(context).colorScheme.onSurface;
      // ion-card-header / ion-card-content (md 16 / iOS 20 side padding).
      final side = ios ? 20.0 : 16.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(side, ios ? 12 : 8, side, 8),
            child: Text(
              term.term,
              // ion-card-title: md 20/500, iOS 28/700.
              style: TextStyle(
                fontSize: ios ? 28 : 20,
                fontWeight: ios ? FontWeight.w700 : FontWeight.w500,
                color: onSurface,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(side, 0, side, ios ? 12 : 8),
            child: HelpMarkdown(
              data: term.definition,
              // ion-card-content: md 14px, iOS 16px.
              style: TextStyle(
                fontSize: ios ? 16 : 14,
                height: 1.45,
                color: onSurface.withValues(alpha: ios ? 0.75 : 0.6),
              ),
            ),
          ),
        ],
      );
    },
  );
}
