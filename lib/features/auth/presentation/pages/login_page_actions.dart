part of 'login_page.dart';

/// Authentication actions, error prompts, and post-login routing for [LoginPage].
extension _LoginPageActions on _LoginPageState {
  /// Ionic `forgotPassword()`: alert "Passwort zurücksetzen" with the login
  /// e-mail prefilled, buttons Abbrechen / Zurücksetzen → db.resetPassword.
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

  /// Ionic `startDemo()`: log in with the demo credentials directly
  /// without touching the form. The demo account is write-protected (DEMO_GUARD).
  Future<void> _startDemo() async {
    if (_isLoading) return;
    _update(() => _isLoading = true);
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
      if (mounted) _update(() => _isLoading = false);
    }
  }

  /// AUTOFILL: after a successful password login, let iOS / Android / the
  /// browser offer to save the typed credentials (password suggestions).
  /// Not after the demo login: it does not use the form fields.
  void _saveCredentialsForAutofill() {
    try {
      TextInput.finishAutofillContext();
    } catch (e) {
      debugPrint('finishAutofillContext failed: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    _update(() => _isLoading = true);

    try {
      if (_teamsLinkMode) {
        await _linkTeamsAccount();
        return;
      }
      final user = await ref.read(authFlowServiceProvider).signInWithPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );
      _saveCredentialsForAutofill();
      if (mounted) await _routeAfterAuth(user);
    } on LoginFailure catch (failure) {
      if (!mounted) return;
      if (_teamsLinkMode) {
        // Ionic login() in linkMode: ssoLink catches the sign-in error and
        // only shows a danger toast. No follow-up dialog.
        _showError(switch (failure.kind) {
          LoginFailureKind.emailNotConfirmed => context.l10n.authConfirmEmailFirst,
          LoginFailureKind.invalidCredentials => context.l10n.authInvalidCredentials,
          _ => failure.message ?? context.l10n.authInvalidCredentials,
        });
        return;
      }
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
      if (mounted) _update(() => _isLoading = false);
    }
  }

  /// TEAMS: verify the Attendix credentials, then bind the Microsoft identity
  /// so future Teams launches sign in silently (Ionic login() in linkMode).
  Future<void> _linkTeamsAccount() async {
    // The root messenger outlives this page (the auth redirect may already
    // have left /login when linking finishes).
    final toastContext = ScaffoldMessenger.maybeOf(context)?.context;
    final l10n = context.l10n;
    final result = await ref.read(teamsServiceProvider).ssoLink(() async {
      await ref.read(authFlowServiceProvider).signInWithPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );
      // Credentials are valid even if the Microsoft link fails afterwards.
      _saveCredentialsForAutofill();
    });
    final message = result.ok
        ? l10n.loginToastMsLinked
        : (result.error ?? l10n.svcLinkFailed);
    if (toastContext != null && toastContext.mounted) {
      final beta = LegacySnackBar(
        color: result.ok ? AppColors.success : AppColors.danger,
        floating: true,
        duration: const Duration(seconds: 4),
      );
      if (result.ok) {
        ToastHelper.showSuccess(toastContext, message,
            duration: const Duration(seconds: 4), beta: beta);
      } else {
        ToastHelper.showError(toastContext, message, beta: beta);
      }
    }
    if (!result.ok || !mounted) return;
    _update(() => _teamsLinkMode = false);
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
    _update(() => _isLoading = true);
    final result = await ref
        .read(authFlowServiceProvider)
        .sendEmailOtp(email, allowCreate: false);
    if (!mounted) return;
    _update(() => _isLoading = false);
    if (result.success) {
      _update(() => _otpSent = true);
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
    _update(() => _isLoading = true);
    final result = await ref
        .read(authFlowServiceProvider)
        .verifyEmailOtp(_emailController.text.trim(), code);
    if (!mounted) return;
    _update(() => _isLoading = false);
    if (!result.success) {
      _showError(result.message);
      return;
    }
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user != null) await _routeAfterAuth(user);
  }

  /// Navigate after a successful sign-in (Ionic routeAfterAuth).
  Future<void> _routeAfterAuth(User user) async {
    final userPrefs = UserPreferences.fromUserMetadata(user.userMetadata);
    InstanceSelectionGate.afterSignIn = true;

    if (!userPrefs.wantInstanceSelection) {
      for (final id in await preferredTenantIds(userPrefs.currentTenantId)) {
        if (await _tryAutoNavigateToTenant(id)) return;
      }
    }

    if (mounted) {
      context.go('/tenants');
    }
  }

  /// Ionic `register()`: RegisterModalComponent as a modal over the login
  /// page. On `registered` show the toast, on `signedIn` route like a login.
  Future<void> _openRegister() async {
    final email = _emailController.text.trim();
    final prefill = email.isNotEmpty;
    final outcome = await showRegisterModal(
      context,
      email: prefill ? email : null,
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
        content: AppAlertInputGroup(
          betaCrossAxisAlignment: CrossAxisAlignment.start,
          message: Text(ctx.l10n.loginNotConfirmedMessage),
          children: [
            const AppAlertBetaGap(AppDimensions.paddingM),
            AppAlertInput(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              placeholder: ctx.l10n.loginEmailPlaceholder,
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

  /// Try to auto-navigate to the saved tenant.
  Future<bool> _tryAutoNavigateToTenant(int tenantId) async {
    // IOS_SHELL: capture the container and router before any async gap.
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    try {
      final tenants = await container.read(userTenantsProvider.future);
      final savedTenant = tenants.where((t) => t.id == tenantId).firstOrNull;
      if (savedTenant == null) return false;

      final role = await _getTenantUserRole(container, tenantId);
      if (!mounted) return false;

      await container
          .read(currentTenantProvider.notifier)
          .setTenantLocal(savedTenant);
      await container.read(currentTenantUserProvider.future);

      final prefsNotifier =
          container.read(userPreferencesNotifierProvider.notifier);

      router.go(homeRouteFor(role, tenantId,
          container.read(supabaseAuthProvider).currentUser?.userMetadata));

      prefsNotifier.updateCurrentTenantId(tenantId);
      return true;
    } catch (e) {
      debugPrint('Auto-navigation failed: $e');
      return false;
    }
  }

  /// Get the user's role for a specific tenant.
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
}
