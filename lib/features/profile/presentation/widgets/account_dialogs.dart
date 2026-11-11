import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/event/rd_form_widgets.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Shows the "Passwort ändern" dialog (Ionic settings changePassword alert).
Future<void> showChangePasswordDialog(BuildContext context) async {
  // REDESIGN (E2): in the Beta a sheet from below, same checks and write.
  final beta = ProviderScope.containerOf(context, listen: false).read(redesignEnabledProvider);
  final changed = beta
      ? await showRdSheet<bool>(context, const ChangePasswordDialog(beta: true))
      : await showAppDialog<bool>(
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
  const ChangePasswordDialog({super.key, this.beta = false});

  /// Beta look (content of an [showRdSheet] sheet).
  final bool beta;

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
    if (widget.beta) return _buildBeta(context);
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

/// REDESIGN (E2): "Passwort ändern" as a Beta sheet.
extension on _ChangePasswordDialogState {
  Widget _buildBeta(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(l10n.settingsChangePassword, style: RdType.section(p))),
              const SizedBox(height: 12),
              RdGroupedList(
                children: [
                  RdFieldRow(
                    label: l10n.redesignMePasswordNew,
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      autofocus: true,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      decoration: rdInputDecoration(p, l10n.settingsNewPasswordPh),
                    ),
                  ),
                  RdFieldRow(
                    label: l10n.redesignMePasswordRepeat,
                    child: TextField(
                      controller: _confirmController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: rdInputDecoration(p, l10n.settingsRepeatPasswordPh),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(l10n.redesignMePasswordHint, style: RdType.meta(p, size: 13)),
              ),
              const SizedBox(height: 16),
              RdPrimaryButton(
                label: l10n.settingsChangePassword,
                loading: _isLoading,
                onPressed: _isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
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
          onPressed:
              _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        IosAlertButton(
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

// PARITY_R5: IosAlertInput moved to the shared adaptive app_dialog.dart.

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
              prefixIcon: Icon(AppIcons.emailOutlined),
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
