import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../data/auth_flow_service.dart';

/// AUTH: "Neues Passwort eingeben" after a password-recovery link
/// (Ionic app.component.ts presentPasswordRecoveryAlert).
///
/// The recovery session is already established when this page opens. The
/// page only closes on success so the user can retry without losing it.
class NewPasswordPage extends ConsumerStatefulWidget {
  const NewPasswordPage({super.key});

  @override
  ConsumerState<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends ConsumerState<NewPasswordPage> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _controller.text;
    if (password.length < 6) {
      ToastHelper.showError(
          context, 'Bitte gib ein Passwort mit mindestens 6 Zeichen ein');
      return;
    }
    setState(() => _isLoading = true);
    final (ok, message) =
        await ref.read(authFlowServiceProvider).updatePassword(password);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      ToastHelper.showSuccess(context, message);
      context.go('/tenants');
    } else {
      ToastHelper.showError(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neues Passwort eingeben'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppDimensions.maxFormWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset, size: 64),
                  const SizedBox(height: AppDimensions.paddingL),
                  TextField(
                    controller: _controller,
                    obscureText: _obscure,
                    autofocus: true,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Neues Passwort',
                      hintText: 'Min. 6 Zeichen eingeben...',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        tooltip: 'Passwort anzeigen',
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingL),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Passwort ändern'),
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  TextButton(
                    onPressed: _isLoading ? null : () => context.go('/tenants'),
                    child: const Text('Abbrechen'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
