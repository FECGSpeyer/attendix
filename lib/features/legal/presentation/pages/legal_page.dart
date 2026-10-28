import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/legal_content_view.dart';
import '../../../../l10n/l10n.dart';

/// Public Impressum & Datenschutz page (`/legal`, no login required).
///
/// Port of Ionic `legal/legal.page`.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      // Ionic legal page: plain (white) content background.
      backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(context.l10n.legalTitle),
        leading: IconButton(
          icon: const BackButtonIcon(),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/login'),
        ),
      ),
      // Scrolls itself, capped at 800px; loading/error centred.
      body: const LegalContentView(),
    );
  }
}
