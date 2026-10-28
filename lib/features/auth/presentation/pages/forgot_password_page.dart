import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../data/auth_flow_service.dart';
import '../../../../l10n/l10n.dart';

/// Forgot password page
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.email});

  /// AUTH: prefilled e-mail (Ionic forgotPassword alert uses the login e-mail).
  final String? email;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void initState() {
    super.initState();
    if (widget.email != null) _emailController.text = widget.email!;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // AUTH: Ionic auth.resetPassword (redirect to /resetPassword).
      final (ok, message) = await ref
          .read(authFlowServiceProvider)
          .resetPassword(_emailController.text.trim());

      if (!mounted) return;
      if (ok) {
        setState(() => _emailSent = true);
      } else {
        ToastHelper.showError(context, message);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        title: Text(context.l10n.loginResetHeader),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppDimensions.maxFormWidth),
              child: _emailSent ? _buildSuccessContent() : _buildFormContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 40,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: AppDimensions.paddingL),
        Text(
          context.l10n.messagesEmailSent,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.paddingM),
        Text(
          context.l10n.loginFlutterResetLinkSent(_emailController.text.trim()),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.medium,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.paddingS),
        Text(
          context.l10n.loginFlutterCheckSpam,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.medium,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.paddingXL),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            child: Text(context.l10n.loginFlutterBackToLogin),
          ),
        ),
        const SizedBox(height: AppDimensions.paddingM),
        TextButton(
          onPressed: () => setState(() => _emailSent = false),
          child: Text(context.l10n.loginFlutterOtherEmail),
        ),
      ],
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon
          const Icon(
            Icons.lock_reset_outlined,
            size: 80,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppDimensions.paddingL),

          // Title
          Text(
            context.l10n.loginForgotPassword,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Text(
            context.l10n.loginFlutterResetIntro,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.medium,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.paddingXL),

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.loginEmail,
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.l10n.loginToastEnterEmail;
              }
              if (!isValidEmail(value)) {
                return context.l10n.loginToastInvalidEmail;
              }
              return null;
            },
            onFieldSubmitted: (_) => _resetPassword(),
          ),
          const SizedBox(height: AppDimensions.paddingL),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.l10n.loginFlutterSendLink),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Back to login
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text(context.l10n.loginFlutterBackToLogin),
          ),
        ],
      ),
    );
  }
}
