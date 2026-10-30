import 'package:flutter/gestures.dart';
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
import '../widgets/ion_buttons.dart';
import '../widgets/ion_input_decoration.dart';
import '../../../../shared/widgets/dialogs/ion_modal.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

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

  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => showLegalModal(context);

  @override
  void dispose() {
    _privacyTap.dispose();
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
    final ios = useIosLook(context);
    // register-modal.component.scss in rem (1rem = 17px on the iPhone).
    final rem = ios ? 17.0 : 16.0;
    final introStyle = TextStyle(
        fontSize: 0.95 * rem,
        height: 1.4,
        color: theme.brightness == Brightness.dark
            ? const Color(0xFFD0D0D0)
            // md: --ion-color-medium-shade as rendered (#57585c); iOS: the
            // darker grey of the iPhone screenshot audit.
            : (ios ? const Color(0xFF333333) : const Color(0xFF57585C)));
    final hintStyle = TextStyle(
        fontSize: 0.85 * rem, height: 1.4, color: const Color(0xFF636469));
    final privacyStyle = TextStyle(fontSize: 0.9 * rem, height: 1.4);
    final itemLine = theme.dividerTheme.color ?? theme.dividerColor;
    // ion-list md: 8px padding above/below the items.
    final listPad = ios ? 0.0 : 8.0;
    final fieldMetrics = IonStackedItemMetrics.modern(ios: ios);
    Widget field({
      required String label,
      required String placeholder,
      required Widget Function(InputDecoration, TextStyle) builder,
      Widget? trailing,
    }) =>
        IonStackedItem(
          label: label,
          placeholder: placeholder,
          metrics: fieldMetrics,
          indent: 16,
          lineColor: itemLine,
          focusHighlight: !ios,
          trailing: trailing,
          trailingSize: ios ? 29.75 : 40,
          builder: builder,
        );

    // Ionic register-modal: modal page on the plain background colour with
    // a close button on the right (no back arrow). Content starts at the top
    // (ion-content + ion-padding), no vertical centring, full width.
    return Scaffold(
      backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.l10n.registerModalTitle),
        // IOS_LOOK: ion-buttons end → ✕ in a Liquid Glass circle on iOS.
        actions: [
          ToolbarButtonGroup(children: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.l10n.commonClose,
              onPressed: _isLoading ? null : _close,
            ),
          ]),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), // ion-padding
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // AUTH: intro (Ionic registerModal.welcome/intro/hint)
                Text(
                  context.l10n.registerModalWelcome,
                  style: TextStyle(
                      fontSize: 1.25 * rem,
                      height: 1.2,
                      fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 0.5 * rem),
                Text(context.l10n.registerModalIntro, style: introStyle),
                SizedBox(height: 0.5 * rem),
                Text(
                  _mode == AuthMode.otp
                      ? context.l10n.registerModalHintOtp
                      : context.l10n.registerModalHintPassword,
                  style: hintStyle,
                ),
                // .hint margin-bottom .5rem + .intro margin-bottom 1rem
                // (collapsed to the larger one)
                SizedBox(height: rem),

                AuthModeSegment(
                  mode: _mode,
                  enabled: !_isLoading,
                  onChanged: _setMode,
                  // register-modal.component.scss: .1 track, 0.85rem
                  trackAlpha: 0.1,
                  fontSize: 13.6,
                ),
                SizedBox(height: rem + listPad),

                // ion-list lines="full": items directly below each other
                field(
                  label: context.l10n.loginEmail,
                  placeholder: context.l10n.registerModalEmailPlaceholder,
                  builder: (decoration, style) => TextFormField(
                    controller: _emailController,
                    style: style,
                    decoration: decoration,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    readOnly: _mode == AuthMode.otp && _otpSent,
                    autofillHints: const [AutofillHints.email],
                  ),
                ),

                if (_mode == AuthMode.password) ...[
                  field(
                    label: context.l10n.loginModePassword,
                    placeholder: context.l10n.registerModalPasswordPlaceholder,
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
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                  ),
                  field(
                    label: context.l10n.registerModalConfirmPassword,
                    placeholder:
                        context.l10n.registerModalConfirmPasswordPlaceholder,
                    builder: (decoration, style) => TextFormField(
                      controller: _confirmPasswordController,
                      style: style,
                      decoration: decoration,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (_canSubmit) _onSubmit();
                      },
                    ),
                  ),
                ] else if (_otpSent) ...[
                  const SizedBox(height: AppDimensions.paddingM),
                  OtpCodeField(
                    controller: _otpController,
                    enabled: !_isLoading,
                    onCompleted: (_) => _verifyCode(),
                  ),
                ],
                // ion-list padding-bottom (md) + margin-bottom 1rem
                SizedBox(height: listPad + rem),

                // LEGAL_HELP: privacy consent (ion-item lines="none" with a
                // start-slot ion-checkbox and a wrapping label)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: ios ? 23.4 : 18,
                        height: ios ? 23.4 : 18,
                        child: Checkbox(
                          value: _privacyAccepted,
                          // ion-checkbox: round in iOS mode
                          shape: ios ? const CircleBorder() : null,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          semanticLabel: context.l10n.registerModalAcceptPrivacy,
                          onChanged: (v) =>
                              setState(() => _privacyAccepted = v ?? false),
                        ),
                      ),
                      SizedBox(width: ios ? 12.75 : 12), // margin-right .75rem
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(
                              () => _privacyAccepted = !_privacyAccepted),
                          child: Text.rich(
                            TextSpan(
                              style: privacyStyle.copyWith(
                                  color: theme.colorScheme.onSurface),
                              children: [
                                TextSpan(
                                    text:
                                        '${context.l10n.registerModalPrivacyBefore} '),
                                TextSpan(
                                  text: context.l10n.registerModalPrivacyLink,
                                  recognizer: _privacyTap,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.primary,
                                  ),
                                ),
                                TextSpan(
                                    text:
                                        context.l10n.registerModalPrivacyAfter),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // .privacy-item margin-bottom 1rem (= .actions margin-top)
                // + ion-button margin-top 4
                SizedBox(height: rem + 4),

                // Ionic .actions: block buttons, gap .25rem + button margins
                IonBlockButton(
                  label: _mode == AuthMode.password
                      ? (_isLoading
                          ? context.l10n.registerModalSubmitting
                          : context.l10n.registerModalTitle)
                      : _otpSent
                          ? context.l10n.registerModalConfirm
                          : context.l10n.loginSendCode,
                  loading: _isLoading,
                  primaryWhenDisabled: false,
                  onPressed: _canSubmit ? _onSubmit : null,
                ),
                if (_mode == AuthMode.otp && _otpSent) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: ResendCodeButton(
                      cooldown: _cooldown,
                      enabled: !_isLoading,
                      onResend: _requestCode,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Ionic: clear "Abbrechen" button closes the modal.
                IonBlockButton(
                  label: context.l10n.commonCancel,
                  solid: false,
                  onPressed: _isLoading ? null : _close,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
