import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Shows the "Passwort ändern" dialog (Ionic settings changePassword alert).
Future<void> showChangePasswordDialog(BuildContext context) async {
  final changed = await showAppDialog<bool>(
    context: context,
    builder: (_) => const ChangePasswordDialog(),
  );
  if (changed == true && context.mounted) {
    ToastHelper.showSuccess(context, context.l10n.settingsPasswordChanged);
  }
}

/// Shows the "E-Mail ändern" dialog.
Future<void> showChangeEmailDialog(BuildContext context) async {
  final changed = await showAppDialog<bool>(
    context: context,
    builder: (_) => const ChangeEmailDialog(),
  );
  if (changed == true && context.mounted) {
    ToastHelper.showSuccess(
      context,
      context.l10n.settingsFlutterConfirmEmailChange,
    );
  }
}

/// Dialog for changing the own password
class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (password != _confirmController.text) {
      ToastHelper.showError(context, context.l10n.settingsPasswordsMismatch);
      return;
    }
    if (password.length < 6) {
      ToastHelper.showError(
          context, context.l10n.settingsPasswordTooShort);
      return;
    }

    if (DemoGuard.blocked()) return; // DEMO_GUARD (Ionic changePassword)

    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.auth.updateUser(UserAttributes(password: password));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ToastHelper.showError(
          context,
          context.l10n.settingsPasswordFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      title: Text(context.l10n.settingsChangePassword),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              hintText: context.l10n.settingsNewPasswordPh,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: context.l10n.settingsRepeatPasswordPh,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: AppSpinner(strokeWidth: 2),
                )
              : Text(context.l10n.settingsChange),
        ),
      ],
    );
  }
}

/// Dialog for changing the own login e-mail address
class ChangeEmailDialog extends ConsumerStatefulWidget {
  const ChangeEmailDialog({super.key});

  @override
  ConsumerState<ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends ConsumerState<ChangeEmailDialog> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!_emailRegex.hasMatch(email)) {
      ToastHelper.showError(context, context.l10n.settingsFlutterInvalidEmail);
      return;
    }
    final supabase = ref.read(supabaseClientProvider);
    if (email == supabase.auth.currentUser?.email?.toLowerCase()) {
      ToastHelper.showError(context, context.l10n.settingsFlutterSameEmail);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.auth.updateUser(UserAttributes(email: email));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.settingsFlutterChangeEmailFailed(friendlyErrorMessage(e)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail =
        ref.read(supabaseClientProvider).auth.currentUser?.email ?? '';
    return AppAlertDialog(
      title: Text(context.l10n.settingsFlutterChangeEmail),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currentEmail.isNotEmpty) ...[
            Text(context.l10n.settingsFlutterCurrentEmail(currentEmail)),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: context.l10n.settingsFlutterNewEmailPh,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: AppSpinner(strokeWidth: 2),
                )
              : Text(context.l10n.settingsChange),
        ),
      ],
    );
  }
}
