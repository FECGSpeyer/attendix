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
import '../widgets/strong_html_text.dart';

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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.deleteAccountTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
            child: DefaultTextStyle.merge(
              style: white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  Center(
                    child: Text(
                      context.l10n.deleteAccountWarning,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  StrongHtmlText(context.l10n.deleteAccountIntro),
                  const SizedBox(height: AppDimensions.paddingS),
                  for (final item in [
                    context.l10n.deleteAccountProfile,
                    context.l10n.deleteAccountAttendance,
                    context.l10n.deleteAccountMemberships,
                    context.l10n.deleteAccountAccess,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 2),
                      child: Text('•  $item'),
                    ),
                  const SizedBox(height: AppDimensions.paddingS),
                  StrongHtmlText(context.l10n.deleteAccountCannotUndo),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingL),
          Text(
            context.l10n.deleteAccountEnterCode,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingL,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.danger, width: 2),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusS),
              ),
              child: SelectableText(
                _verificationCode,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          TextField(
            controller: _confirmController,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: context.l10n.deleteAccountCode,
              hintText: context.l10n.deleteAccountCodePlaceholder,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: !_canDelete || isDeleting ? null : _deleteAccount,
            icon: isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
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
