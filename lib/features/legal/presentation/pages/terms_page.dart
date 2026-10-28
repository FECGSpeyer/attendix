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
import '../../../../l10n/l10n.dart';

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
          context.l10n.termsPleaseAccept);
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
          context, context.l10n.termsSessionExpired);
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(
            context, context.l10n.termsSaveFailed);
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
        title: Text(context.l10n.termsTitle),
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
                  context.l10n.termsBeforeStart,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppDimensions.paddingS),
                Text(
                  context.l10n.termsIntro,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.medium),
                ),
                const SizedBox(height: AppDimensions.paddingL),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lock_outline,
                            color: AppColors.primary),
                        title: Text(context.l10n.termsSafe),
                        subtitle: Text(context.l10n.termsSafeText),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.people_outline,
                            color: AppColors.primary),
                        title: Text(context.l10n.termsUsage),
                        subtitle: Text(context.l10n.termsUsageText),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.description_outlined,
                            color: AppColors.primary),
                        title: Text(context.l10n.termsRead),
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
                        TextSpan(text: '${context.l10n.termsAcceptBefore} '),
                        TextSpan(
                          text: context.l10n.termsPrivacy,
                          style: const TextStyle(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _privacyRecognizer,
                        ),
                        TextSpan(text: ' ${context.l10n.termsAcceptAfter}'),
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
                  label: Text(context.l10n.termsAcceptContinue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
