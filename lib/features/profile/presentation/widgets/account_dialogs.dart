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
    if (useIosLook(context)) return _buildIos(context);
    // IOS_FORMS1 (md): Ionic md alert – underlined inputs without icons and
    // the uppercase text buttons "ABBRECHEN  ÄNDERN" right-aligned.
    InputDecoration underline(String hint) {
      final theme = Theme.of(context);
      final line = UnderlineInputBorder(
        borderSide: BorderSide(color: theme.dividerColor),
      );
      return InputDecoration(
        hintText: hint,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: line,
        enabledBorder: line,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      );
    }

    return AppAlertDialog(
      title: Text(context.l10n.settingsChangePassword),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            decoration: underline(context.l10n.settingsNewPasswordPh),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: underline(context.l10n.settingsRepeatPasswordPh),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(context.l10n.commonCancel.toUpperCase()),
        ),
        TextButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: AppSpinner(strokeWidth: 2),
                )
              : Text(context.l10n.settingsChange.toUpperCase()),
        ),
      ],
    );
  }
}

/// IOS_FORMS1: Ionic iOS `ion-alert` with two password inputs (rounded
/// 7pt boxes with a hairline border, no icons) and the two buttons
/// "Abbrechen | Ändern" side by side.
extension on _ChangePasswordDialogState {
  Widget _buildIos(BuildContext context) {
    final l10n = context.l10n;
    return IosAlertCard(
      title: Text(l10n.settingsChangePassword),
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 21),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IosAlertInput(
            controller: _passwordController,
            placeholder: l10n.settingsNewPasswordPh,
            obscureText: true,
            autofocus: true,
          ),
          IosAlertInput(
            controller: _confirmController,
            placeholder: l10n.settingsRepeatPasswordPh,
            obscureText: true,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      // Two buttons → side by side (IosAlertCard lays them out).
      actions: [
        IosAlertButton(
          bold: false,
          onPressed:
              _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        IosAlertButton(
          bold: false,
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: AppSpinner(strokeWidth: 2),
                )
              : Text(l10n.settingsChange),
        ),
      ],
    );
  }
}

/// IOS_FORMS1: text input of an iOS `ion-alert` (`.alert-input`): 16pt
/// text, 7pt padding and radius, 0.55pt grey border on the page
/// background, 10pt above each input.
class IosAlertInput extends StatelessWidget {
  const IosAlertInput({
    super.key,
    required this.controller,
    this.placeholder,
    this.obscureText = false,
    this.autofocus = false,
    this.keyboardType,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? placeholder;
  final bool obscureText;
  final bool autofocus;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: BorderSide(
        color: dark ? const Color(0xFF404040) : const Color(0xFFBFBFBF),
        width: 0.55,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        autofocus: autofocus,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(
            fontSize: 16,
            color: dark ? const Color(0xFF8C8C8C) : const Color(0xFF999999),
          ),
          isDense: true,
          filled: true,
          fillColor: dark ? Colors.black : Colors.white,
          contentPadding: const EdgeInsets.all(7),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
          disabledBorder: border,
        ),
      ),
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
