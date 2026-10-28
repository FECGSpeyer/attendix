import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/legal_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/account_repository.dart';
import '../widgets/legal_content_view.dart';

/// One-time consent gate (`/terms`): the user must accept the terms and
/// privacy policy before using the app.
///
/// Port of Ionic `terms/terms.page`. The router redirects every logged-in
/// user without `user_metadata.terms_accepted_at` here (Ionic `TermsGuard`).
class TermsPage extends ConsumerStatefulWidget {
  const TermsPage({super.key});

  @override
  ConsumerState<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends ConsumerState<TermsPage> {
  bool _privacyAccepted = false;
  bool _saving = false;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => showLegalModal(context);
  }

  @override
  void dispose() {
    _privacyRecognizer.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (!_privacyAccepted) {
      ToastHelper.showError(context,
          'Bitte akzeptiere die Nutzungsbedingungen und Datenschutzerklärung.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(accountNotifierProvider.notifier).acceptTerms();
      if (mounted) context.go('/tenants');
    } on SessionExpiredException {
      if (!mounted) return;
      context.go('/login');
      ToastHelper.showWarning(
          context, 'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.');
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(
            context, 'Fehler beim Speichern. Bitte versuche es erneut.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Datenschutz & Nutzung'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppDimensions.maxFormWidth),
            child: ListView(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              children: [
                const SizedBox(height: AppDimensions.paddingL),
                const Icon(Icons.verified_user_outlined,
                    size: 64, color: AppColors.primary),
                const SizedBox(height: AppDimensions.paddingM),
                Text(
                  'Kurz bevor es losgeht',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppDimensions.paddingS),
                Text(
                  'Um Attendix nutzen zu können, benötigen wir einmalig deine '
                  'Zustimmung zu unseren Nutzungsbedingungen und der '
                  'Datenschutzerklärung.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.medium),
                ),
                const SizedBox(height: AppDimensions.paddingL),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.lock_outline,
                            color: AppColors.primary),
                        title: Text('Deine Daten sind sicher'),
                        subtitle: Text(
                          'Wir speichern nur die Daten, die für den Betrieb '
                          'der App notwendig sind, und geben sie nicht an '
                          'Dritte weiter.',
                        ),
                      ),
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(Icons.people_outline,
                            color: AppColors.primary),
                        title: Text('Wofür werden deine Daten genutzt?'),
                        subtitle: Text(
                          'Ausschließlich zur Verwaltung deiner Anwesenheit '
                          'und zur Kommunikation innerhalb deiner Gruppe oder '
                          'deines Chores.',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.description_outlined,
                            color: AppColors.primary),
                        title: const Text(
                            'Datenschutzerklärung & Impressum lesen'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showLegalModal(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingM),
                Card(
                  margin: EdgeInsets.zero,
                  child: CheckboxListTile(
                    value: _privacyAccepted,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) =>
                        setState(() => _privacyAccepted = v ?? false),
                    title: Text.rich(
                      TextSpan(children: [
                        const TextSpan(
                          text: 'Ich akzeptiere die Nutzungsbedingungen und '
                              'habe die ',
                        ),
                        TextSpan(
                          text: 'Datenschutzerklärung',
                          style: const TextStyle(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _privacyRecognizer,
                        ),
                        const TextSpan(text: ' gelesen.'),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingL),
                ElevatedButton.icon(
                  onPressed: !_privacyAccepted || _saving ? null : _accept,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Akzeptieren und fortfahren'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
