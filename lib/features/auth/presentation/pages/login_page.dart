import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../legal/presentation/widgets/legal_content_view.dart';
import '../../data/auth_flow_service.dart';
import '../widgets/otp_widgets.dart';
import '../../../../core/providers/dashboard_providers.dart'; // DASHBOARD
import '../../../../l10n/l10n.dart'; // I18N_INFRA

/// Login page
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _cooldown = ResendCooldown();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  // AUTH: passwordless e-mail code mode (Ionic otpMode/otpSent)
  AuthMode _mode = AuthMode.password;
  bool _otpSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _cooldown.dispose();
    super.dispose();
  }

  void _startDemo() {
    _setMode(AuthMode.password);
    _emailController.text = AppConstants.demoMail;
    _passwordController.text = AppConstants.demoPassword;
    _login();  // Fire-and-forget OK — _login has its own try-catch + mounted checks
  }

  void _setMode(AuthMode mode) {
    setState(() {
      _mode = mode;
      _otpSent = false;
      _otpController.clear();
      _errorMessage = null;
    });
    _cooldown.reset();
  }

  /// Ionic onEnter(): route Enter/submit to the action of the current mode.
  void _onSubmit() {
    if (_mode == AuthMode.otp) {
      _otpSent ? _verifyCode() : _requestCode();
    } else {
      _login();
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref.read(authFlowServiceProvider).signInWithPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (mounted) await _routeAfterAuth(user);
    } on LoginFailure catch (failure) {
      if (!mounted) return;
      setState(() => _errorMessage = failure.message);
      switch (failure.kind) {
        case LoginFailureKind.emailNotConfirmed:
          await _promptResendConfirmation();
        case LoginFailureKind.invalidCredentials:
          await _promptSwitchToOtp();
        case LoginFailureKind.userNotFound:
          await _promptRegister();
        case LoginFailureKind.other:
          break;
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = context.l10n.loginFlutterUnexpectedError;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Ionic requestCode(): sign-in only, never creates a new account.
  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (!isValidEmail(email)) {
      setState(() => _errorMessage = context.l10n.loginToastInvalidEmail);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await ref
        .read(authFlowServiceProvider)
        .sendEmailOtp(email, allowCreate: false);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      setState(() => _otpSent = true);
      _cooldown.start();
      ToastHelper.showSuccess(context, result.message);
    } else {
      setState(() => _errorMessage = result.message);
      if (result.noAccount) await _promptRegister();
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || _isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await ref
        .read(authFlowServiceProvider)
        .verifyEmailOtp(_emailController.text.trim(), code);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!result.success) {
      setState(() => _errorMessage = result.message);
      return;
    }
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user != null) await _routeAfterAuth(user);
  }

  /// Navigate after a successful sign-in (Ionic routeAfterAuth).
  Future<void> _routeAfterAuth(User user) async {
    // Check if user wants to skip tenant selection
    final userPrefs = UserPreferences.fromUserMetadata(user.userMetadata);

    if (!userPrefs.wantInstanceSelection && userPrefs.currentTenantId != null) {
      // Try to auto-navigate to saved tenant
      final navigated = await _tryAutoNavigateToTenant(
        userPrefs.currentTenantId!,
      );
      if (navigated) return;
    }

    // Default: show tenant selection
    if (mounted) {
      context.go('/tenants');
    }
  }

  void _openRegister() {
    final email = _emailController.text.trim();
    final path = email.isNotEmpty
        ? '/register?email=${Uri.encodeComponent(email)}'
        : '/register';
    context.push(path);
  }

  /// Ionic promptResendConfirmation(): "E-Mail nicht bestätigt".
  Future<void> _promptResendConfirmation() async {
    final controller = TextEditingController(text: _emailController.text.trim());
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.loginNotConfirmedHeader),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.l10n.loginNotConfirmedMessage),
            const SizedBox(height: AppDimensions.paddingM),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  InputDecoration(hintText: ctx.l10n.loginEmailPlaceholder),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                ToastHelper.showWarning(ctx, ctx.l10n.loginToastEnterEmail);
                return;
              }
              Navigator.pop(ctx, value);
            },
            child: Text(ctx.l10n.loginNotConfirmedResend),
          ),
        ],
      ),
    );
    controller.dispose();
    if (target == null || !mounted) return;
    final (ok, message) =
        await ref.read(authFlowServiceProvider).resendConfirmationEmail(target);
    if (!mounted) return;
    ok
        ? ToastHelper.showSuccess(context, message)
        : ToastHelper.showError(context, message);
  }

  /// Ionic promptRegister(): "Kein Konto gefunden".
  Future<void> _promptRegister() async {
    final register = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.loginNoAccountHeader,
      message: context.l10n.loginNoAccountMessage,
      confirmText: context.l10n.loginRegister,
    );
    if (register && mounted) _openRegister();
  }

  /// Ionic promptSwitchToOtp(): wrong password → offer code login.
  Future<void> _promptSwitchToOtp() async {
    final switchMode = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.loginFailedHeader,
      message: context.l10n.loginFailedMessage,
      confirmText: context.l10n.loginModeOtp,
    );
    if (switchMode && mounted) _setMode(AuthMode.otp);
  }

  /// Try to auto-navigate to the saved tenant
  /// Returns true if navigation was successful, false otherwise
  Future<bool> _tryAutoNavigateToTenant(int tenantId) async {
    try {
      // Load user's tenants to verify access
      final tenants = await ref.read(userTenantsProvider.future);
      final savedTenant = tenants.where((t) => t.id == tenantId).firstOrNull;

      if (savedTenant == null) {
        // User no longer has access to this tenant
        return false;
      }

      // Get user's role FIRST, before any state changes
      final role = await _getTenantUserRole(tenantId);

      if (!mounted) return false;

      // Set tenant locally WITHOUT triggering auth sync
      await ref.read(currentTenantProvider.notifier).setTenantLocal(savedTenant);

      // Wait for currentTenantUserProvider to load so router doesn't redirect back
      await ref.read(currentTenantUserProvider.future);

      if (!mounted) return false;

      // Get notifier BEFORE navigation (widget may be disposed after go())
      final prefsNotifier = ref.read(userPreferencesNotifierProvider.notifier);

      // Navigate FIRST
      context.go(homeRouteFor(role, tenantId, ref.read(supabaseAuthProvider).currentUser?.userMetadata)); // DASHBOARD

      // Auth sync AFTER navigation (fire and forget, notifier captured above)
      prefsNotifier.updateCurrentTenantId(tenantId);

      return true;
    } catch (e) {
      debugPrint('Auto-navigation failed: $e');
      return false;
    }
  }

  /// Get the user's role for a specific tenant
  Future<Role> _getTenantUserRole(int tenantId) async {
    final supabase = ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return Role.none;

    final response = await supabase
        .from('tenantUsers')
        .select('role')
        .eq('tenantId', tenantId)
        .eq('userId', userId)
        .maybeSingle();

    if (response == null) return Role.none;
    return Role.fromValue(response['role'] as int? ?? 99);
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(label),
    );
  }

  /// Ionic login.page.scss: ion-item with stacked label and a primary-tinted
  /// bottom line instead of a filled/outlined field.
  InputDecoration _ionInputDecoration(String label, {Widget? suffixIcon}) {
    final line = UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
    );
    return InputDecoration(
      labelText: label,
      hintText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      border: line,
      enabledBorder: line,
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    const footerStyle = TextStyle(fontSize: 13, color: Colors.white);

    // Ionic login: background photo, centered card (60 % / 95 % under
    // 700px, max 500px) with the round app logo overlapping its top edge and
    // the version/demo/legal line in white at the bottom of the screen.
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: AppColors.primary),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cardWidth =
                    (width < 700 ? width * 0.95 : width * 0.6).clamp(0.0, 500.0);
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 80, bottom: 56),
                    child: SizedBox(
                      width: cardWidth,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x73000000),
                                  blurRadius: 60,
                                  spreadRadius: -15,
                                  offset: Offset(0, 20),
                                ),
                              ],
                            ),
                            child: Padding(
                              // room for the overlapping logo (115 - 80) + 2rem
                              padding: const EdgeInsets.only(top: 35 + 32),
                              child: _buildForm(context),
                            ),
                          ),
                          Positioned(
                            top: -80,
                            child: Container(
                              width: 115,
                              height: 115,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cardColor,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x8F000000),
                                    blurRadius: 38,
                                    spreadRadius: -12,
                                    offset: Offset(0, 16),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text(context.l10n.loginVersion(AppConstants.appVersion),
                      style: footerStyle),
                  if (AppConstants.demoMail.isNotEmpty &&
                      AppConstants.demoPassword.isNotEmpty) ...[
                    const Text(' | ', style: footerStyle),
                    GestureDetector(
                      onTap: _startDemo,
                      child: Text(context.l10n.loginStartDemo, style: footerStyle),
                    ),
                  ],
                  // LEGAL_HELP: Impressum & Datenschutz modal
                  const Text(' | ', style: footerStyle),
                  GestureDetector(
                    onTap: () => showLegalModal(context),
                    child: Text(context.l10n.loginLegal, style: footerStyle),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusM),
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

          // AUTH: mode segment (Passwort / Code per E-Mail)
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
            textInputAction: _mode == AuthMode.password
                ? TextInputAction.next
                : TextInputAction.go,
            autocorrect: false,
            readOnly: _mode == AuthMode.otp && _otpSent,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: _mode == AuthMode.otp && !_otpSent
                ? (_) => _requestCode()
                : null,
            decoration: _ionInputDecoration(context.l10n.loginEmail),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.l10n.loginToastEnterEmail;
              }
              if (!isValidEmail(value)) {
                return context.l10n.loginToastInvalidEmail;
              }
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.paddingM),

          if (_mode == AuthMode.password) ...[
            // Password field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _onSubmit(),
              decoration: _ionInputDecoration(
                context.l10n.loginPassword,
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.l10n.loginFlutterEnterPassword;
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.paddingS),

            // Register + forgot password (Ionic: small clear buttons, left)
            Wrap(
              children: [
                TextButton(
                  onPressed: _openRegister,
                  child: Text(context.l10n.loginRegister),
                ),
                TextButton(
                  onPressed: () {
                    final email = _emailController.text.trim();
                    context.push(email.isNotEmpty
                        ? '/forgot-password?email=${Uri.encodeComponent(email)}'
                        : '/forgot-password');
                  },
                  child: Text(context.l10n.loginForgotPassword),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingS),
            _primaryButton(context.l10n.loginSignIn, _login),
          ] else if (!_otpSent) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _openRegister,
                child: Text(context.l10n.loginRegister),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingS),
            _primaryButton(context.l10n.loginSendCode, _requestCode),
          ] else ...[
            OtpCodeField(
              controller: _otpController,
              enabled: !_isLoading,
              onCompleted: (_) => _verifyCode(),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            _primaryButton(context.l10n.loginSignIn, _verifyCode),
            const SizedBox(height: AppDimensions.paddingS),
            Center(
              child: ResendCodeButton(
                cooldown: _cooldown,
                enabled: !_isLoading,
                onResend: _requestCode,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
