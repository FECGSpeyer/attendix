import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../legal/presentation/widgets/legal_content_view.dart';
import '../../data/auth_flow_service.dart';
import '../widgets/otp_widgets.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/ion_input_decoration.dart';

/// Register page (Ionic login/register-modal).
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.email});

  final String? email;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _cooldown = ResendCooldown();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _registrationSuccess = false;
  // LEGAL_HELP: privacy consent (Ionic register modal)
  bool _privacyAccepted = false;
  // AUTH: passwordless registration with an e-mail code
  AuthMode _mode = AuthMode.password;
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    if (widget.email != null && widget.email!.isNotEmpty) {
      _emailController.text = widget.email!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _cooldown.dispose();
    super.dispose();
  }

  void _setMode(AuthMode mode) {
    if (_isLoading) return;
    setState(() {
      _mode = mode;
      _otpSent = false;
      _otpController.clear();
      _errorMessage = null;
    });
    _cooldown.reset();
  }

  void _close() => context.canPop() ? context.pop() : context.go('/login');

  void _onSubmit() {
    if (_mode == AuthMode.otp) {
      _otpSent ? _verifyCode() : _requestCode();
    } else {
      _register();
    }
  }

  /// Ionic register-modal submit(): password registration.
  Future<void> _register() async {
    final email = _emailController.text.trim();
    if (!isValidEmail(email)) {
      setState(() => _errorMessage = context.l10n.registerModalInvalidEmail);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = context.l10n.registerModalPasswordMismatch);
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(
          () => _errorMessage = context.l10n.registerModalPasswordTooShort);
      return;
    }
    if (!_privacyAccepted) {
      setState(() => _errorMessage = context.l10n.registerModalAcceptPrivacyToast);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.auth.signUp(
        email: email,
        password: _passwordController.text,
        emailRedirectTo: '${authRedirectBase()}/login',
        // Stamp terms acceptance (checkbox accepted), like Ionic.
        data: {
          AccountRepository.termsAcceptedAtKey:
              DateTime.now().toUtc().toIso8601String(),
        },
      );

      // Ionic db.register: no identities → the e-mail already exists; try to
      // sign in with the given password instead.
      if (response.user != null &&
          (response.user!.identities?.isEmpty ?? true)) {
        try {
          await supabase.auth.signInWithPassword(
            email: email,
            password: _passwordController.text,
          );
          return; // Signed in – the router takes over.
        } catch (_) {
          if (!mounted) return;
          setState(() => _errorMessage =
              context.l10n.dbEmailExists);
          return;
        }
      }

      if (!mounted) return;
      if (response.session != null) return; // auto-confirmed → router
      ToastHelper.showSuccess(context,
          context.l10n.loginToastRegistered);
      setState(() {
        _registrationSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;
      String errorMessage;
      if (e is AuthException) {
        errorMessage = switch (e.message) {
          'User already registered' =>
            context.l10n.dbEmailExists,
          _ when e.message.contains('password') =>
            context.l10n.dbWeakPasswordRequirements,
          _ when e.message.contains('rate limit') || e.message.contains('Too many') =>
            context.l10n.dbTooManyRequests,
          _ when e.message.contains('email') => context.l10n.registerModalInvalidEmail,
          _ => context.l10n.registerModalFailed,
        };
      } else {
        errorMessage = context.l10n.registerModalFailed;
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Ionic requestCode(): registration surface → may create the account.
  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (!isValidEmail(email)) {
      setState(() => _errorMessage = context.l10n.registerModalInvalidEmail);
      return;
    }
    if (!_privacyAccepted) {
      setState(() => _errorMessage = context.l10n.registerModalAcceptPrivacyToast);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await ref
        .read(authFlowServiceProvider)
        .sendEmailOtp(email, allowCreate: true);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      setState(() => _otpSent = true);
      _cooldown.start();
      ToastHelper.showSuccess(context, result.message);
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || _isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final service = ref.read(authFlowServiceProvider);
    final result =
        await service.verifyEmailOtp(_emailController.text.trim(), code);
    if (!result.success) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
      });
      return;
    }
    // Stamp terms acceptance — the checkbox was accepted before requesting.
    await service.stampTermsAccepted();
    if (!mounted) return;
    setState(() => _isLoading = false);
    // Signed in: new users without a tenant land on the tenant page.
    context.go('/tenants');
  }

  @override
  Widget build(BuildContext context) {
    if (_registrationSuccess) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppDimensions.maxFormWidth),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 80,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: AppDimensions.paddingL),
                    Text(
                      context.l10n.loginFlutterConfirmEmail,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.paddingM),
                    Text(
                      context.l10n.loginFlutterConfirmEmailSent(_emailController.text),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.paddingXL),
                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      child: Text(context.l10n.loginFlutterToLogin),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    // Ionic register-modal: modal page on the plain background colour with
    // a close button on the right (no back arrow).
    return Scaffold(
      backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.l10n.registerModalTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.commonClose,
            onPressed: _isLoading ? null : _close,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppDimensions.maxFormWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // AUTH: intro (Ionic registerModal.welcome/intro/hint)
                    Text(
                      context.l10n.registerModalWelcome,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(
                      context.l10n.registerModalIntro,
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(
                      _mode == AuthMode.otp
                          ? context.l10n.registerModalHintOtp
                          : context.l10n.registerModalHintPassword,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.medium),
                    ),
                    const SizedBox(height: AppDimensions.paddingL),

                    AuthModeSegment(
                      mode: _mode,
                      enabled: !_isLoading,
                      onChanged: _setMode,
                    ),
                    const SizedBox(height: AppDimensions.paddingM),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.paddingM),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.danger),
                            const SizedBox(width: AppDimensions.paddingS),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.paddingM),
                    ],

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      readOnly: _mode == AuthMode.otp && _otpSent,
                      autofillHints: const [AutofillHints.email],
                      decoration: ionStackedInputDecoration(
                        context.l10n.loginEmail,
                        hint: context.l10n.registerModalEmailPlaceholder,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingM),

                    if (_mode == AuthMode.password) ...[
                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: ionStackedInputDecoration(
                          context.l10n.loginModePassword,
                          hint: context.l10n.registerModalPasswordPlaceholder,
                          suffixIcon: IconButton(
                            tooltip: context.l10n.loginShowPassword,
                            color: AppColors.primary,
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.paddingM),

                      // Confirm password field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _onSubmit(),
                        decoration: ionStackedInputDecoration(
                          context.l10n.registerModalConfirmPassword,
                          hint: context.l10n.registerModalConfirmPasswordPlaceholder,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.paddingM),
                    ] else if (_otpSent) ...[
                      OtpCodeField(
                        controller: _otpController,
                        enabled: !_isLoading,
                        onCompleted: (_) => _verifyCode(),
                      ),
                      const SizedBox(height: AppDimensions.paddingM),
                    ],

                    // LEGAL_HELP: privacy consent checkbox
                    CheckboxListTile(
                      value: _privacyAccepted,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) =>
                          setState(() => _privacyAccepted = v ?? false),
                      title: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('${context.l10n.registerModalPrivacyBefore} '),
                          InkWell(
                            onTap: () => showLegalModal(context),
                            child: Text(
                              context.l10n.registerModalPrivacyLink,
                              style: const TextStyle(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Text(context.l10n.registerModalPrivacyAfter),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingM),

                    ElevatedButton(
                      onPressed: _isLoading || !_privacyAccepted ? null : _onSubmit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(_mode == AuthMode.password
                              ? context.l10n.registerModalTitle
                              : _otpSent
                                  ? context.l10n.registerModalConfirm
                                  : context.l10n.loginSendCode),
                    ),
                    if (_mode == AuthMode.otp && _otpSent)
                      Center(
                        child: ResendCodeButton(
                          cooldown: _cooldown,
                          enabled: !_isLoading,
                          onResend: _requestCode,
                        ),
                      ),
                    const SizedBox(height: AppDimensions.paddingL),

                    // Ionic: clear "Abbrechen" button closes the modal.
                    TextButton(
                      onPressed: _isLoading ? null : _close,
                      child: Text(context.l10n.commonCancel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
