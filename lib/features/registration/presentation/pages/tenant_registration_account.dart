part of 'tenant_registration_page.dart';

extension _TenantRegistrationAccount on _TenantRegistrationPageState {
  Future<void> _showLoginDialog(Tenant tenant) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var loginError = '';

    try {
      final result = await showAppDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AppAlertDialog(
              title: Text(context.l10n.loginSignIn),
              // Ionic alert: `email` + `password` inputs with placeholders
              // (tenant-register.page.ts login); the hint / a login error is
              // the alert message.
              content: AppAlertInputGroup(
                // SEL-07: Ionic has no message; only a login error is shown.
                message: loginError.isNotEmpty ? Text(loginError) : null,
                beta: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.tenantRegisterFlutterSignInExisting),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: context.l10n.loginEmail,
                        prefixIcon: Icon(AppIcons.emailOutlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: context.l10n.loginPassword,
                        prefixIcon: Icon(AppIcons.lockOutlined),
                      ),
                      obscureText: true,
                    ),
                    if (loginError.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(loginError, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                    ],
                  ],
                ),
                children: [
                  AppAlertInput(
                    controller: emailController,
                    placeholder: context.l10n.tenantRegisterEmailAddress,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  AppAlertInput(
                    controller: passwordController,
                    placeholder: context.l10n.loginModePassword,
                    obscureText: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.commonCancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref.read(authFlowServiceProvider).signInWithPassword(
                            emailController.text.trim(),
                            passwordController.text,
                          );
                      if (context.mounted) Navigator.pop(context, true);
                    } on LoginFailure catch (failure) {
                      setDialogState(() {
                        loginError = failure.message ??
                            context.l10n.authConfirmEmailFirst;
                      });
                    } catch (e) {
                      setDialogState(() {
                        loginError = context.l10n.dbLoginFailed;
                      });
                    }
                  },
                  child: Text(context.l10n.loginSignIn),
                ),
              ],
            );
          },
        ),
      );

      if (result == true && mounted) {
        // Rebuild page to show logged-in state
        _update(() => _hasCheckedRegistration = false);
      }
    } finally {
      emailController.dispose();
      passwordController.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // AUTH: account block (Ionic tenant-register "Account")
  // ---------------------------------------------------------------------------

  Widget _buildAccountGroup() {
    if (_isLoggedIn) {
      final email = ref.read(supabaseClientProvider).auth.currentUser?.email ?? '';
      return IonInsetGroup(
        margin: _betaGroupMargin,
        color: _betaGroupColor,
        children: [IonItem(label: context.l10n.tenantRegisterSignedInAs(email))],
      );
    }

    final inputStyle = ionItemInputStyle(context);
    return IonInsetGroup(
      margin: _betaGroupMargin,
      color: _betaGroupColor,
      children: [
        IonButtonItem(
          label: context.l10n.tenantRegisterHaveAccount,
          onTap: _isLoading ? null : _showLoginDialogForCurrentTenant,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: AuthModeSegment(
            mode: _mode,
            enabled: !_isLoading,
            trackAlpha: 0.1,
            fontSize: 13.6,
            onChanged: (mode) {
              _update(() {
                _mode = mode;
                _otpSent = false;
                _otpController.clear();
              });
              _cooldown.reset();
            },
          ),
        ),
        IonInputItem(
          child: TextFormField(
            controller: _emailController,
            style: inputStyle,
            readOnly: _mode == AuthMode.otp && _otpSent,
            decoration: ionItemInputDecoration(
                context, context.l10n.tenantRegisterEmailAddress),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onSaved: (value) => _formData.email = value?.trim() ?? '',
          ),
        ),
        if (_mode == AuthMode.password) ...[
          IonInputItem(
            child: TextFormField(
              style: inputStyle,
              decoration: ionItemInputDecoration(
                  context, context.l10n.loginModePassword),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (value) => _formData.password = value,
              onSaved: (value) => _formData.password = value ?? '',
            ),
          ),
          IonInputItem(
            child: TextFormField(
              style: inputStyle,
              decoration: ionItemInputDecoration(
                  context, context.l10n.registerModalConfirmPassword),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              onSaved: (value) => _formData.confirmPassword = value ?? '',
            ),
          ),
        ] else if (_otpSent) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: OtpCodeField(
                controller: _otpController,
                enabled: !_isLoading,
                onCompleted: (_) => _verifyCode(),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _otpController,
            builder: (context, _) => IonButtonItem(
              label: context.l10n.tenantRegisterConfirmCode,
              onTap: _isLoading || _otpController.text.isEmpty
                  ? null
                  : _verifyCode,
            ),
          ),
          ListenableBuilder(
            listenable: _cooldown,
            builder: (context, _) => IonButtonItem(
              label: _cooldown.active
                  ? context.l10n.loginResendIn(_cooldown.remaining)
                  : context.l10n.loginResendCode,
              onTap: _isLoading || _cooldown.active ? null : _requestCode,
            ),
          ),
        ] else
          IonButtonItem(
            label: context.l10n.loginSendCode,
            onTap: _isLoading ? null : _requestCode,
          ),
        _buildTermsCheckbox(),
      ],
    );
  }

  /// Ionic privacy-item: round checkbox (iOS) + "Ich akzeptiere die
  /// Datenschutzerklärung." with the link.
  Widget _buildTermsCheckbox() {
    const privacyStyle = TextStyle(fontSize: 14.4, height: 1.4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
      child: Row(
        children: [
          Checkbox(
            value: _privacyAccepted,
            onChanged: (v) => _update(() => _privacyAccepted = v ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: privacyStyle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface),
                children: [
                  TextSpan(text: '${context.l10n.registerModalPrivacyBefore} '),
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
                  TextSpan(text: context.l10n.registerModalPrivacyAfter),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLoginDialogForCurrentTenant() async {
    final tenant =
        ref.read(tenantByRegisterIdProvider(widget.registerId)).valueOrNull;
    if (tenant != null) await _showLoginDialog(tenant);
  }
}
