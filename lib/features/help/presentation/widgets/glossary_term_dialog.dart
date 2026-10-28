import 'package:flutter/material.dart';

import '../../data/help_models.dart';
import 'help_markdown.dart';

/// Shows a glossary definition (port of Ionic `HelpGlossaryPopoverComponent`).
Future<void> showGlossaryTermDialog(BuildContext context, GlossaryTerm term) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(term.term),
      content: SingleChildScrollView(
        child: HelpMarkdown(data: term.definition),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    ),
  );
}
