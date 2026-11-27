import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/services/update_hint.dart';
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
import '../../../../core/providers/redesign_providers.dart' show redesignSettingsProvider;
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/display/attendix_logo.dart';
import '../../../../shared/widgets/redesign/rd_account_switch.dart' show RdSavedAccountsOnLogin;
import '../../../../shared/widgets/redesign/rd_logo.dart' show rdLogoColors;
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../attendance/presentation/widgets/event/rd_form_widgets.dart';
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../widgets/reset_password_dialog.dart';

part 'login_page_actions.dart';
part 'login_page_form.dart';

/// Login page
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  /// LOGO: colours of the active Farbwelt.
  AttendixLogoColors _logoColors() =>
      rdLogoColors(ref.watch(redesignSettingsProvider).world);

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

  void _update(VoidCallback fn) => setState(fn);

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

  /// ACCOUNT_SWITCH: saved account without a valid session → its e-mail
  /// goes into the form, the password field gets the focus.
  void _pickSavedEmail(String email) {
    if (_mode != AuthMode.password) _setMode(AuthMode.password);
    setState(() {
      _emailController.text = email;
      _passwordController.clear();
    });
  }

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
    final cardColor = context.rd.surface;
    const footerStyle = TextStyle(
      fontSize: 16,
      height: 20 / 16,
      color: Colors.white,
    );
    const rem = 16.0;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
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
                            33.1,
                          ),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(context.rd.cardRadius),
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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (!_teamsLinkMode)
                                    RdSavedAccountsOnLogin(onPickEmail: _pickSavedEmail),
                                  KeyedSubtree(
                                    key: _formBoxKey,
                                    // AUTOFILL: e-mail + password form one
                                    // autofill context, so iOS / Web offer
                                    // saved passwords and to save them after
                                    // a login. Leaving the page without a
                                    // successful login must not offer that.
                                    child: AutofillGroup(
                                      onDisposeAction:
                                          AutofillContextAction.cancel,
                                      child: _buildForm(context),
                                    ),
                                  ),
                                ],
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
          // KEYBOARD_FOOTER: while the keyboard is open the body shrinks and
          // the line would slide over the card (Ionic leaves it behind the
          // keyboard), so it is hidden then.
          if (!keyboardOpen)
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
                    if (showUpdateHint(ref.watch(appUpdateAvailableProvider)))
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
                          label: Text(context.l10n.loginInstallUpdate),
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
                                    .loginVersion(AppConstants.displayVersion)),
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
}
