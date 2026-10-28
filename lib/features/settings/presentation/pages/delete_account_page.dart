import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/legal_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/base_repository.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)
import '../widgets/strong_html_text.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Characters for the verification code — avoids visually ambiguous chars
/// (0/O, 1/I/L), identical to Ionic.
const String deleteAccountCodeChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Generates a random 6-char verification code (Ionic `generateCode`).
String generateDeleteAccountCode([Random? random]) {
  final rng = random ?? Random.secure();
  return List.generate(
    6,
    (_) => deleteAccountCodeChars[rng.nextInt(deleteAccountCodeChars.length)],
  ).join();
}

/// Whether the typed text matches the code (trimmed, case-insensitive).
bool isDeleteAccountCodeValid(String input, String code) =>
    input.trim().toUpperCase() == code;

/// DSGVO account deletion (`/settings/delete-account`).
///
/// Port of Ionic `settings/delete-account/delete-account.page`: the user must
/// re-type a random code, confirm a dialog, then the `delete-account` edge
/// function removes the account and all personal data.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  // Regenerated every time the page opens — prevents muscle-memory confirms.
  final String _verificationCode = generateDeleteAccountCode();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canDelete =>
      isDeleteAccountCodeValid(_confirmController.text, _verificationCode);

  Future<void> _deleteAccount() async {
    if (!_canDelete) return;

    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.deleteAccountConfirm),
        content: Text(context.l10n.deleteAccountConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(context.l10n.deleteAccountDeleteFinal),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(accountNotifierProvider.notifier).deleteAccount();
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.deleteAccountDeleted);
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      final message = e is RepositoryException ? e.message : e.toString();
      ToastHelper.showError(
        context,
        context.l10n.deleteAccountFailed(message.isEmpty ? context.l10n.commonUnknown : message),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDeleting = ref.watch(accountNotifierProvider).isLoading;
    const white = TextStyle(color: Colors.white);

    final ios = ionIsIos(context);
    // UX_SETTINGS (WAVE 8): delete-account.page.html — arrow-back, danger
    // tint warning box (radius 12), centred code chip, stacked input item.
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.l10n.deleteAccountTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              // --ion-color-danger-tint
              color: Color.lerp(AppColors.danger, Colors.white, 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DefaultTextStyle.merge(
              style: white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.deleteAccountWarning,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StrongHtmlText(context.l10n.deleteAccountIntro),
                  const SizedBox(height: 8),
                  for (final item in [
                    context.l10n.deleteAccountProfile,
                    context.l10n.deleteAccountAttendance,
                    context.l10n.deleteAccountMemberships,
                    context.l10n.deleteAccountAccess,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                      child: Text('•  $item'),
                    ),
                  const SizedBox(height: 8),
                  StrongHtmlText(context.l10n.deleteAccountCannotUndo),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            context.l10n.deleteAccountEnterCode,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.medium),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF222428)
                    : const Color(0xFFF4F5F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                _verificationCode,
                style: TextStyle(
                  fontFamily: 'Courier New',
                  fontFamilyFallback: const ['Courier', 'monospace'],
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          IonStackedField(
            label: context.l10n.deleteAccountCode,
            hint: context.l10n.deleteAccountCodePlaceholder,
            builder: (decoration) => TextField(
              controller: _confirmController,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              decoration: decoration,
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (ios)
            Divider(height: 0.5, thickness: 0.5, color: IonIos.line(context)),
          const SizedBox(height: AppDimensions.paddingM),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.danger.withValues(alpha: 0.5),
              disabledForegroundColor: Colors.white,
            ),
            onPressed: !_canDelete || isDeleting ? null : _deleteAccount,
            icon: isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: AppSpinner(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.delete_outline),
            label: Text(
                isDeleting ? context.l10n.deleteAccountDeleting : context.l10n.deleteAccountDeleteForever),
          ),
        ],
      ),
    );
  }
}
