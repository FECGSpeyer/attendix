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
import '../../../../shared/widgets/dialogs/ion_modal.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// How the registration ended (Ionic register-modal dismiss data).
enum RegisterOutcome {
  /// Password sign-up done, confirmation mail sent (`{ success: true }`).
  registered,

  /// The user is signed in (OTP registration or existing account,
  /// `{ success: true, signedIn: true }`).
  signedIn,
}

/// Opens the registration like Ionic `register()` on the login page: a
/// centred 600 × 500 modal on desktop, full screen on phones.
Future<RegisterOutcome?> showRegisterModal(BuildContext context,
    {String? email}) {
  return showIonModal<RegisterOutcome>(
    context,
    builder: (_) => RegisterPage(email: email, isModal: true),
  );
}

/// Register page (Ionic login/register-modal).
///
/// Shown as a modal from the login page ([showRegisterModal]); the
/// `/register` route renders the same widget full screen for deep links.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.email, this.isModal = false});

  final String? email;

  /// Presented via [showRegisterModal]: pops with a [RegisterOutcome].
  final bool isModal;

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
    // Ionic: the submit button is disabled until the fields are filled.
    for (final c in [
      _emailController,
      _passwordController,
      _confirmPasswordController,
      _otpController,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  /// Ionic `canSubmit` / `[disabled]` per mode.
  bool get _canSubmit {
    if (_isLoading) return false;
    final hasEmail = _emailController.text.isNotEmpty;
    if (_mode == AuthMode.password) {
      return hasEmail &&
          _passwordController.text.isNotEmpty &&
          _confirmPasswordController.text.isNotEmpty &&
          _privacyAccepted;
    }
    if (!_otpSent) return hasEmail && _privacyAccepted;
    return _otpController.text.isNotEmpty;
  }

  /// Ionic `Utils.showToast(..., 'danger')` instead of an inline error box.
  void _showError(String message) => ToastHelper.showError(context, message);

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
    });
    _cooldown.reset();
  }

  void _close() {
    if (widget.isModal || Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/login');
    }
  }

  /// Ionic: the modal dismisses only on success; the login page then shows
  /// the "registered" toast or routes the signed-in user.
  void _finish(RegisterOutcome outcome) {
    if (widget.isModal) {
      Navigator.of(context).pop(outcome);
      return;
    }
    // `/register` deep link: same follow-up as the login page.
    if (outcome == RegisterOutcome.registered) {
      ToastHelper.showSuccess(context, context.l10n.loginToastRegistered);
      context.go('/login');
    } else {
      context.go('/tenants');
    }
  }

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
      _showError(context.l10n.registerModalInvalidEmail);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError(context.l10n.registerModalPasswordMismatch);
      return;
    }
    if (_passwordController.text.length < 6) {
      _showError(context.l10n.registerModalPasswordTooShort);
      return;
    }
    if (!_privacyAccepted) {
      _showError(context.l10n.registerModalAcceptPrivacyToast);
      return;
    }

    setState(() => _isLoading = true);

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
          if (mounted) _finish(RegisterOutcome.signedIn);
          return;
        } catch (_) {
          if (!mounted) return;
          _showError(context.l10n.dbEmailExists);
          return;
        }
      }

      if (!mounted) return;
      if (response.session != null) {
        _finish(RegisterOutcome.signedIn); // auto-confirmed
        return;
      }
      _finish(RegisterOutcome.registered);
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
      _showError(errorMessage);
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
      _showError(context.l10n.registerModalInvalidEmail);
      return;
    }
    if (!_privacyAccepted) {
      _showError(context.l10n.registerModalAcceptPrivacyToast);
      return;
    }
    setState(() => _isLoading = true);
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
      _showError(result.message);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || _isLoading) return;
    setState(() => _isLoading = true);
    final service = ref.read(authFlowServiceProvider);
    final result =
        await service.verifyEmailOtp(_emailController.text.trim(), code);
    if (!result.success) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(result.message);
      return;
    }
    // Stamp terms acceptance — the checkbox was accepted before requesting.
    await service.stampTermsAccepted();
    if (!mounted) return;
    setState(() => _isLoading = false);
    // Signed in: the login page routes (new users land on the tenant page).
    _finish(RegisterOutcome.signedIn);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Ionic register-modal.component.scss
    const introStyle =
        TextStyle(fontSize: 15.2, height: 1.4, color: Color(0xFF86888F));
    const hintStyle =
        TextStyle(fontSize: 13.6, height: 1.4, color: AppColors.medium);
    const privacyStyle = TextStyle(fontSize: 14.4, height: 1.4);
    const actionGap = SizedBox(height: 4); // .actions gap: 0.25rem
    // Ionic register-modal: modal page on the plain background colour with
    // a close button on the right (no back arrow). Content starts at the top
    // (ion-content + ion-padding), no vertical centring.
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppDimensions.maxFormWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // AUTH: intro (Ionic registerModal.welcome/intro/hint)
                    Text(
                      context.l10n.registerModalWelcome,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(context.l10n.registerModalIntro, style: introStyle),
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(
                      _mode == AuthMode.otp
                          ? context.l10n.registerModalHintOtp
                          : context.l10n.registerModalHintPassword,
                      style: hintStyle,
                    ),
                    const SizedBox(height: AppDimensions.paddingM),

                    AuthModeSegment(
                      mode: _mode,
                      enabled: !_isLoading,
                      onChanged: _setMode,
                    ),
                    const SizedBox(height: AppDimensions.paddingM),

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
                        onFieldSubmitted: (_) {
                          if (_canSubmit) _onSubmit();
                        },
                        decoration: ionStackedInputDecoration(
                          context.l10n.registerModalConfirmPassword,
                          hint: context
                              .l10n.registerModalConfirmPasswordPlaceholder,
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
                      title: Text.rich(
                        TextSpan(
                          style: privacyStyle,
                          children: [
                            TextSpan(
                                text:
                                    '${context.l10n.registerModalPrivacyBefore} '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: InkWell(
                                onTap: () => showLegalModal(context),
                                child: Text(
                                  context.l10n.registerModalPrivacyLink,
                                  style: privacyStyle.copyWith(
                                    color: AppColors.primary,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            TextSpan(
                                text: context.l10n.registerModalPrivacyAfter),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingM),

                    ElevatedButton(
                      onPressed: _canSubmit ? _onSubmit : null,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: AppSpinner(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(_mode == AuthMode.password
                              ? context.l10n.registerModalTitle
                              : _otpSent
                                  ? context.l10n.registerModalConfirm
                                  : context.l10n.loginSendCode),
                    ),
                    if (_mode == AuthMode.otp && _otpSent) ...[
                      actionGap,
                      Center(
                        child: ResendCodeButton(
                          cooldown: _cooldown,
                          enabled: !_isLoading,
                          onResend: _requestCode,
                        ),
                      ),
                    ],
                    actionGap,
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
