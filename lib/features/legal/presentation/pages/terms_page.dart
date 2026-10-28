import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/legal_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../public_links/presentation/pages/open_file_page.dart';
import '../widgets/legal_content_view.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../../../settings/presentation/widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)

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
      // REVIEW_FIX2: resume a link stashed before login (kept through /terms).
      if (mounted) context.go(PendingFileLink.consume() ?? '/tenants');
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

  /// Ionic info item: primary start icon, h3 (600) + p (0.85rem, medium).
  Widget _infoItem(IconData icon, String title, String text) {
    return SettingsListTile(
      icon: icon,
      iconColor: AppColors.primary,
      title: title,
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(text,
              style: const TextStyle(fontSize: 13.6, color: AppColors.medium)),
        ],
      ),
      detail: false,
    );
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
                // UX_SETTINGS (WAVE 8): terms.page.html — centred hero
                // (shield icon 3.5rem, h2 1.4rem bold, medium p), inset info
                // list with primary icons, inset accept list, block button.
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 32, 24, 12),
                  child: Icon(Icons.verified_user_outlined,
                      size: 56, color: AppColors.primary),
                ),
                Text(
                  context.l10n.termsBeforeStart,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontSize: 22.4, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppDimensions.paddingS),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  child: Text(
                    context.l10n.termsIntro,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 15.2, height: 1.5, color: AppColors.medium),
                  ),
                ),
                SettingsListSection(
                  children: [
                    _infoItem(Icons.lock_outline, context.l10n.termsSafe,
                        context.l10n.termsSafeText),
                    _infoItem(Icons.people_outline, context.l10n.termsUsage,
                        context.l10n.termsUsageText),
                    SettingsListTile(
                      icon: Icons.description_outlined,
                      iconColor: AppColors.primary,
                      title: context.l10n.termsRead,
                      titleWidget: Text(
                        context.l10n.termsRead,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => showLegalModal(context),
                    ),
                  ],
                ),
                SettingsListSection(
                  icons: false,
                  children: [
                    CheckboxListTile(
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
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: !_privacyAccepted || _saving ? null : _accept,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: AppSpinner(strokeWidth: 2),
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
