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
      setState(() => _errorMessage = 'Ungültige E-Mail-Adresse');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwörter stimmen nicht überein');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(
          () => _errorMessage = 'Passwort muss mindestens 6 Zeichen lang sein');
      return;
    }
    if (!_privacyAccepted) {
      setState(() => _errorMessage = 'Bitte stimme der Datenschutzerklärung zu');
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
              'Deine E-Mail-Adresse existiert bereits. Bitte melde dich an.');
          return;
        }
      }

      if (!mounted) return;
      if (response.session != null) return; // auto-confirmed → router
      ToastHelper.showSuccess(context,
          'Registrierung erfolgreich, bitte bestätige deine E-Mail-Adresse.');
      setState(() {
        _registrationSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;
      String errorMessage;
      if (e is AuthException) {
        errorMessage = switch (e.message) {
          'User already registered' =>
            'Deine E-Mail-Adresse existiert bereits. Bitte melde dich an.',
          _ when e.message.contains('password') =>
            'Das Passwort erfüllt nicht die Sicherheitsanforderungen.',
          _ when e.message.contains('rate limit') || e.message.contains('Too many') =>
            'Zu viele Anfragen. Bitte warte einen Moment und versuche es erneut.',
          _ when e.message.contains('email') => 'Ungültige E-Mail-Adresse',
          _ => 'Fehler beim Registrieren',
        };
      } else {
        errorMessage = 'Fehler beim Registrieren';
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
      setState(() => _errorMessage = 'Ungültige E-Mail-Adresse');
      return;
    }
    if (!_privacyAccepted) {
      setState(() => _errorMessage = 'Bitte stimme der Datenschutzerklärung zu');
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
                      'E-Mail bestätigen',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.paddingM),
                    Text(
                      'Wir haben dir eine E-Mail an ${_emailController.text} gesendet. '
                      'Bitte klicke auf den Link darin, um deinen Account zu aktivieren.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.paddingXL),
                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Zum Login'),
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading
              ? null
              : () => context.canPop() ? context.pop() : context.go('/login'),
        ),
        title: const Text('Registrieren'),
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
                      'Willkommen bei Attendix!',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    const Text(
                      'Lege einen Account an, um deine Anwesenheit zu verwalten oder eine neue Instanz für deine Gruppe, deinen Chor oder dein Orchester zu erstellen.',
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(
                      _mode == AuthMode.otp
                          ? 'Nach der Registrierung senden wir dir einen 6-stelligen Code per E-Mail. Gib ihn hier ein, um deinen Account zu aktivieren.'
                          : 'Nach der Registrierung senden wir dir eine Bestätigungs-E-Mail. Bitte klicke auf den Link darin, um deinen Account zu aktivieren.',
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
                      decoration: const InputDecoration(
                        labelText: 'E-Mail',
                        hintText: 'deine@email.de',
                        prefixIcon: Icon(Icons.email_outlined),
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
                        decoration: InputDecoration(
                          labelText: 'Passwort',
                          hintText: 'Mindestens 6 Zeichen',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            tooltip: 'Passwort anzeigen',
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
                        decoration: const InputDecoration(
                          labelText: 'Passwort bestätigen',
                          hintText: 'Passwort erneut eingeben',
                          prefixIcon: Icon(Icons.lock_outlined),
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
                          const Text(
                              'Ich akzeptiere die Nutzungsbedingungen und habe die '),
                          InkWell(
                            onTap: () => showLegalModal(context),
                            child: const Text(
                              'Datenschutzerklärung',
                              style: TextStyle(
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(' gelesen.'),
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
                              ? 'Registrieren'
                              : _otpSent
                                  ? 'Bestätigen'
                                  : 'Code senden'),
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

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Bereits ein Konto?'),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Anmelden'),
                        ),
                      ],
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
