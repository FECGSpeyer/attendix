import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_registration_providers.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../legal/presentation/widgets/legal_content_view.dart';
import '../../data/auth_flow_service.dart';
import '../widgets/otp_widgets.dart';
import 'register_page.dart';
import '../../../../core/providers/dashboard_providers.dart';
import '../../../../core/services/teams/teams_service.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/display/attendix_logo.dart';
import '../../../redesign/presentation/widgets/rd_logo.dart' show rdLogoColors;
import '../widgets/ion_buttons.dart';
import '../widgets/ion_input_decoration.dart';
import '../widgets/reset_password_dialog.dart';

/// Login page
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  /// LOGO: original colours, or those of the Farbwelt when the new design is on.
  AttendixLogoColors _logoColors() {
    final settings = ref.watch(redesignSettingsProvider);
    return settings.enabled ? rdLogoColors(settings.world) : AttendixLogoColors.original;
  }

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _cooldown = ResendCooldown();
  bool _isLoading = false;
  bool _obscurePassword = true;
  /// `/forgot-password` deep link (→ `/login?reset=1`) opens the reset alert once.
  bool _resetHandled = false;
  // AUTH: passwordless e-mail code mode (Ionic otpMode/otpSent)
  AuthMode _mode = AuthMode.password;
  bool _otpSent = false;
  // TEAMS: one-time account-linking mode (/login?teamsLink=1 after silent SSO
  // found no linked account; only inside Teams).
  bool _teamsLinkMode = false;

  @override
  void initState() {
    super.initState();
    // Ionic: "Anmelden"/"Code senden" stay disabled until the fields are filled.
    for (final c in [_emailController, _passwordController, _otpController]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Map<String, String> query;
    try {
      query = GoRouterState.of(context).uri.queryParameters;
    } catch (_) {
      query = const {};
    }
    _teamsLinkMode = ref.read(isInTeamsProvider) && query['teamsLink'] == '1';
    // AUTH: legacy `/forgot-password` route redirects here with reset=1.
    if (!_resetHandled && query['reset'] == '1') {
      _resetHandled = true;
      final email = query['email'];
      if (email != null && email.isNotEmpty) _emailController.text = email;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _forgotPassword();
      });
    }
  }

  /// Ionic `[disabled]="!registerForm.form.valid"` (password mode),
  /// `!registerCredentials.email` (send code) and `!otpCode` (verify).
  bool get _canSubmit {
    if (_mode == AuthMode.password) {
      return _emailController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty;
    }
    if (!_otpSent) return _emailController.text.isNotEmpty;
    return _otpController.text.isNotEmpty;
  }

  /// Ionic shows login errors as danger toasts (db.login / Utils.showToast),
  /// not inside the card.
  /// A null message means a dialog explains the failure instead.
  void _showError(String? message) {
    if (message != null) ToastHelper.showError(context, message);
  }

  /// Ionic `forgotPassword()`: alert "Passwort zurücksetzen" with the login
  /// e-mail prefilled, buttons Abbrechen / Zurücksetzen → db.resetPassword
  /// (success/danger toast).
  Future<void> _forgotPassword() async {
    final email = await showResetPasswordDialog(
      context,
      email: _emailController.text.trim(),
    );
    if (email == null || !mounted) return;
    final (ok, message) =
        await ref.read(authFlowServiceProvider).resetPassword(email.trim());
    if (!mounted) return;
    ok
        ? ToastHelper.showSuccess(context, message)
        : ToastHelper.showError(context, message);
  }

  late final TapGestureRecognizer _demoTap = TapGestureRecognizer()
    ..onTap = _startDemo;
  late final TapGestureRecognizer _legalTap = TapGestureRecognizer()
    ..onTap = () => showLegalModal(context);

  @override
  void dispose() {
    _demoTap.dispose();
    _legalTap.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _cooldown.dispose();
    super.dispose();
  }

  /// Ionic `startDemo()`: log in with the demo credentials directly
  /// (`db.login(environment.demoMail, environment.demoPassword)`), without
  /// touching the form. The demo account is write-protected (DEMO_GUARD).
  Future<void> _startDemo() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final user = await ref.read(authFlowServiceProvider).signInWithPassword(
            AppConstants.demoMail,
            AppConstants.demoPassword,
          );
      if (mounted) await _routeAfterAuth(user);
    } on LoginFailure catch (failure) {
      if (mounted) _showError(failure.message);
    } catch (e) {
      debugPrint('Demo login error: $e');
      if (mounted) _showError(context.l10n.loginFlutterUnexpectedError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setMode(AuthMode mode) {
    setState(() {
      _mode = mode;
      _otpSent = false;
      _otpController.clear();
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

    setState(() => _isLoading = true);

    try {
      if (_teamsLinkMode) {
        await _linkTeamsAccount();
        return;
      }
      final user = await ref.read(authFlowServiceProvider).signInWithPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (mounted) await _routeAfterAuth(user);
    } on LoginFailure catch (failure) {
      if (!mounted) return;
      _showError(failure.message);
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
      _showError(context.l10n.loginFlutterUnexpectedError);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// TEAMS: verify the Attendix credentials, then bind the Microsoft identity
  /// so future Teams launches sign in silently (Ionic login() in linkMode).
  /// LoginFailure from the password sign-in propagates to [_login].
  Future<void> _linkTeamsAccount() async {
    // The root messenger outlives this page (the auth redirect may already
    // have left /login when linking finishes).
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final result = await ref.read(teamsServiceProvider).ssoLink(() async {
      await ref.read(authFlowServiceProvider).signInWithPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );
    });
    final message = result.ok
        ? l10n.loginToastMsLinked
        : (result.error ?? l10n.svcLinkFailed);
    messenger?.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: result.ok ? AppColors.success : AppColors.danger,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
    // Usually the auth redirect has already left /login at this point.
    if (!result.ok || !mounted) return;
    setState(() => _teamsLinkMode = false);
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user != null) await _routeAfterAuth(user);
  }

  /// Ionic requestCode(): sign-in only, never creates a new account.
  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (!isValidEmail(email)) {
      _showError(context.l10n.loginToastInvalidEmail);
      return;
    }
    setState(() => _isLoading = true);
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
      _showError(result.message);
      if (result.noAccount) await _promptRegister();
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || _isLoading) return;
    setState(() => _isLoading = true);
    final result = await ref
        .read(authFlowServiceProvider)
        .verifyEmailOtp(_emailController.text.trim(), code);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!result.success) {
      _showError(result.message);
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

  /// Ionic `register()`: RegisterModalComponent as a modal over the login
  /// page. On `registered` show the toast, on `signedIn` route like a login.
  Future<void> _openRegister() async {
    final email = _emailController.text.trim();
    final outcome = await showRegisterModal(
      context,
      email: email.isNotEmpty ? email : null,
    );
    if (!mounted || outcome == null) return;
    if (outcome == RegisterOutcome.signedIn) {
      final user = ref.read(supabaseClientProvider).auth.currentUser;
      if (user != null) await _routeAfterAuth(user);
    } else {
      ToastHelper.showSuccess(context, context.l10n.loginToastRegistered);
    }
  }

  /// Ionic promptResendConfirmation(): "E-Mail nicht bestätigt".
  Future<void> _promptResendConfirmation() async {
    final controller = TextEditingController(text: _emailController.text.trim());
    final target = await showAppDialog<String>(
      context: context,
      builder: (ctx) => AppAlertDialog(
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
    // IOS_SHELL: the router may replace this page as soon as the session or
    // the tenant changes (e.g. demo login → /tenants), so never touch `ref`
    // or `context` after an async gap: capture the container and router now.
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    try {
      // Load user's tenants to verify access
      final tenants = await container.read(userTenantsProvider.future);
      final savedTenant = tenants.where((t) => t.id == tenantId).firstOrNull;

      if (savedTenant == null) {
        // User no longer has access to this tenant
        return false;
      }

      // Get user's role FIRST, before any state changes
      final role = await _getTenantUserRole(container, tenantId);

      // Page already replaced (e.g. by the tenant selection, which then
      // auto-navigates itself): don't change any state from here.
      if (!mounted) return false;

      // Set tenant locally WITHOUT triggering auth sync
      await container
          .read(currentTenantProvider.notifier)
          .setTenantLocal(savedTenant);

      // Wait for currentTenantUserProvider to load so router doesn't redirect back
      await container.read(currentTenantUserProvider.future);

      // Get notifier BEFORE navigation (widget may be disposed after go())
      final prefsNotifier =
          container.read(userPreferencesNotifierProvider.notifier);

      // Navigate FIRST – also when the router already disposed this page
      // after the tenant change, so the user lands on the tenant's home.
      router.go(homeRouteFor(role, tenantId,
          container.read(supabaseAuthProvider).currentUser?.userMetadata));

      // Auth sync AFTER navigation (fire and forget, notifier captured above)
      prefsNotifier.updateCurrentTenantId(tenantId);

      return true;
    } catch (e) {
      debugPrint('Auto-navigation failed: $e');
      return false;
    }
  }

  /// Get the user's role for a specific tenant
  Future<Role> _getTenantUserRole(
      ProviderContainer container, int tenantId) async {
    final supabase = container.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return Role.none;

    final repo =
        container.read(userRegistrationRepositoryForTenantProvider(tenantId));
    return await repo.getTenantUserRole(userId, tenantId: tenantId) ??
        Role.none;
  }

  /// Ionic `ion-button color="primary" expand="block"` (disabled = teal at
  /// opacity .5).
  Widget _primaryButton(String label, VoidCallback onPressed) =>
      IonBlockButton(
        label: label,
        loading: _isLoading,
        onPressed: _isLoading || !_canSubmit ? null : onPressed,
      );

  Widget _smallClearButton(String label, VoidCallback? onPressed) =>
      IonSmallClearButton(label: label, onPressed: onPressed);

  /// Height of the password-mode form; the code mode keeps the card at this
  /// height like Ionic (the card does not shrink when switching modes).
  final _formBoxKey = GlobalKey();
  double? _passwordFormHeight;

  void _measurePasswordForm() {
    if (_mode != AuthMode.password || _otpSent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _formBoxKey.currentContext?.findRenderObject() as RenderBox?;
      if (!mounted || box == null || !box.hasSize) return;
      if (_passwordFormHeight != box.size.height) {
        setState(() => _passwordFormHeight = box.size.height);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    final cardColor = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    // Ionic .version: white ion-label at the root font size (iOS 17pt via
    // -apple-system-body, md 16px), 20 high lines, flowing text that wraps
    // between words ("… | Impressum &" / "Datenschutz").
    final footerStyle = TextStyle(
      fontSize: ios ? 17 : 16,
      height: 20 / (ios ? 17 : 16),
      color: Colors.white,
    );
    // Ionic login.page.scss `.around` in rem: on the iPhone 1rem = 17px.
    final rem = ios ? 17.0 : 16.0;
    _measurePasswordForm();

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
          // Ionic .around: absolutely centred in the full screen
          // (top/left 50 % + translate(-50 %, -50 %)), not below a safe area.
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final cardWidth =
                  (width < 700 ? width * 0.95 : width * 0.6).clamp(0.0, 500.0);
              // Avatar: margin-top -5rem inside the 1.75rem card padding.
              final avatarTop = 1.75 * rem - 5 * rem;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 64),
                  child: SizedBox(
                    width: cardWidth,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          // padding 1.75rem 1.5rem 1.5rem + ion-col 5px; the
                          // bottom also holds the last row's col/margins.
                          padding: EdgeInsets.fromLTRB(
                            1.5 * rem + 5,
                            1.75 * rem,
                            1.5 * rem + 5,
                            ios ? 43.2 : 33.1,
                          ),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(1.25 * rem),
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
                            // avatar 115 + margin-bottom 2rem + ion-col 5
                            padding: EdgeInsets.only(
                                top: avatarTop + 115 + 2 * rem + 5 - 1.75 * rem),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: _mode == AuthMode.password
                                    ? 0
                                    : (_passwordFormHeight ?? 0),
                              ),
                              child: KeyedSubtree(
                                key: _formBoxKey,
                                child: _buildForm(context),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: avatarTop,
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
                            // LOGO: the Ionic logo as a vector; in the new
                            // design in the colours of the Farbwelt.
                            child: AttendixLogo(
                              size: 115,
                              radius: 0,
                              colors: _logoColors(),
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
          Positioned(
            left: 0,
            right: 0,
            bottom: rem, // .version { bottom: 1rem }
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // NATIVE_MISC: Ionic login update-banner ("Update installieren")
                  if (ref.watch(appUpdateAvailableProvider))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => ref.read(appUpdateServiceProvider).applyUpdate(),
                        icon: const Icon(Icons.cloud_download_outlined, size: 18),
                        label: IonButtonLabel(context.l10n.loginInstallUpdate),
                      ),
                    ),
                  // Ionic always shows "Demo starten" (environment.demoMail);
                  // LEGAL_HELP: Impressum & Datenschutz modal.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text.rich(
                      TextSpan(
                        style: footerStyle,
                        children: [
                          TextSpan(
                              text: context.l10n
                                  .loginVersion(AppConstants.appVersion)),
                          const TextSpan(text: ' | '),
                          TextSpan(
                            text: context.l10n.loginStartDemo,
                            recognizer: _demoTap,
                          ),
                          const TextSpan(text: ' | '),
                          TextSpan(
                            text: context.l10n.loginLegal,
                            recognizer: _legalTap,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
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
    final ios = useIosLook(context);
    // ion-row / ion-col gaps measured on the Ionic card (px).
    const segmentToItem = 9.0; // .mode-col padding-bottom 4 + ion-col 5
    final itemGap = ios ? 17.0 : 16.0; // .mailItem margin-bottom: 1rem
    const itemsToLinks = 14.0; // ion-col 5 + ion-col 5 + button margin 4
    const linksToButton = 18.0;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TEAMS: link-mode note replaces the mode segment
          if (_teamsLinkMode)
            Text(
              context.l10n.loginLinkNote,
              style: const TextStyle(color: AppColors.medium),
            )
          else
            // AUTH: mode segment (Passwort / Code per E-Mail)
            AuthModeSegment(
              mode: _mode,
              enabled: !_isLoading,
              onChanged: _setMode,
            ),
          const SizedBox(height: segmentToItem),

          // E-mail: legacy stacked ion-label + ion-input
          IonStackedItem(
            label: context.l10n.loginEmail,
            metrics: IonStackedItemMetrics.legacy(ios: ios),
            builder: (decoration, style) => TextFormField(
              controller: _emailController,
              style: style,
              decoration: decoration,
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
          ),

          if (_mode == AuthMode.password) ...[
            SizedBox(height: itemGap),
            // Password: ion-input label labelPlacement="stacked" with the
            // eye button in its end slot.
            IonStackedItem(
              label: context.l10n.loginPassword,
              metrics: IonStackedItemMetrics.modern(ios: ios),
              trailingSize: ios ? 29.75 : 40,
              trailing: IconButton(
                tooltip: context.l10n.loginShowPassword,
                color: AppColors.primary,
                padding: EdgeInsets.zero,
                iconSize: ios ? 22 : 20,
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
              builder: (decoration, style) => TextFormField(
                controller: _passwordController,
                style: style,
                decoration: decoration,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _onSubmit(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.l10n.loginFlutterEnterPassword;
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: itemsToLinks),

            // Register + forgot password (Ionic: small clear buttons, left)
            Wrap(
              spacing: 4.5, // inline whitespace between the two ion-buttons
              children: [
                _smallClearButton(context.l10n.loginRegister, _openRegister),
                _smallClearButton(
                    context.l10n.loginForgotPassword, _forgotPassword),
              ],
            ),
            const SizedBox(height: linksToButton),
            _primaryButton(
                _teamsLinkMode
                    ? context.l10n.loginLinkAndSignIn
                    : context.l10n.loginSignIn,
                _login),
          ] else if (!_otpSent) ...[
            const SizedBox(height: itemsToLinks),
            Align(
              alignment: Alignment.centerLeft,
              child:
                  _smallClearButton(context.l10n.loginRegister, _openRegister),
            ),
            const SizedBox(height: linksToButton),
            _primaryButton(context.l10n.loginSendCode, _requestCode),
          ] else ...[
            const SizedBox(height: AppDimensions.paddingM),
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
