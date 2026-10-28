import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../widgets/legal_content_view.dart';
import '../../../../l10n/l10n.dart';

/// Public Impressum & Datenschutz page (`/legal`, no login required).
///
/// Port of Ionic `legal/legal.page`.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.legalTitle),
        leading: IconButton(
          icon: const BackButtonIcon(),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/login'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: const LegalContentView(),
          ),
        ),
      ),
    );
  }
}
