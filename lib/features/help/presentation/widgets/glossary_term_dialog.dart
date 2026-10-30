import 'package:flutter/material.dart';

import '../../data/help_models.dart';
import 'help_markdown.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Shows a glossary definition (port of Ionic `HelpGlossaryPopoverComponent`).
Future<void> showGlossaryTermDialog(BuildContext context, GlossaryTerm term) {
  return showAppDialog<void>(
    context: context,
    builder: (context) => AppAlertDialog(
      title: Text(term.term),
      content: SingleChildScrollView(
        child: HelpMarkdown(data: term.definition),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonClose),
        ),
      ],
    ),
  );
}
