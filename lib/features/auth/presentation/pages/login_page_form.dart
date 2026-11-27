part of 'login_page.dart';

/// Login form fields, mode toggle, and submit buttons for [LoginPage].
extension _LoginPageForm on _LoginPageState {
  /// Form with mode chips, grouped email/password card, primary action, and
  /// forgot-password / registration links.
  Widget _buildForm(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    Widget link(String label, VoidCallback onTap) =>
        RdTextLink(label: label, onTap: () => _isLoading ? null : onTap());
    final emailField = RdFieldRow(
      label: l10n.loginEmail,
      child: TextFormField(
        controller: _emailController,
        decoration: rdInputDecoration(p, l10n.loginEmailPlaceholder),
        keyboardType: TextInputType.emailAddress,
        textInputAction: _mode == AuthMode.password ? TextInputAction.next : TextInputAction.go,
        autocorrect: false,
        readOnly: _mode == AuthMode.otp && _otpSent,
        autofillHints: const [AutofillHints.email],
        onFieldSubmitted: _mode == AuthMode.otp && !_otpSent ? (_) => _requestCode() : null,
        validator: (value) {
          if (value == null || value.trim().isEmpty) return l10n.loginToastEnterEmail;
          if (!isValidEmail(value)) return l10n.loginToastInvalidEmail;
          return null;
        },
      ),
    );
    final passwordField = RdFieldRow(
      label: l10n.loginPassword,
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _passwordController,
              decoration: rdInputDecoration(p, ''),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _onSubmit(),
              validator: (value) {
                if (value == null || value.isEmpty) return l10n.loginFlutterEnterPassword;
                return null;
              },
            ),
          ),
          IconButton(
            tooltip: l10n.loginShowPassword,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: p.text2,
            ),
            onPressed: () => _update(() => _obscurePassword = !_obscurePassword),
          ),
        ],
      ),
    );
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_teamsLinkMode)
            Text(l10n.loginLinkNote, style: RdType.meta(p, size: 14))
          else
            // Wrap: with large system text the chips go to a second line.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RdChoiceChip(
                  label: l10n.loginModePassword,
                  selected: _mode == AuthMode.password,
                  onTap: _isLoading || _mode == AuthMode.password ? null : () => _setMode(AuthMode.password),
                ),
                RdChoiceChip(
                  label: l10n.loginModeOtp,
                  selected: _mode == AuthMode.otp,
                  onTap: _isLoading || _mode == AuthMode.otp ? null : () => _setMode(AuthMode.otp),
                ),
              ],
            ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: p.bg,
              borderRadius: BorderRadius.circular(p.cardRadius),
            ),
            child: Column(
              children: [
                emailField,
                if (_mode == AuthMode.password) ...[
                  Divider(height: 1, thickness: 1, color: p.line),
                  passwordField,
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_mode == AuthMode.password) ...[
            RdPrimaryButton(
              label: _teamsLinkMode ? l10n.loginLinkAndSignIn : l10n.loginSignIn,
              loading: _isLoading,
              onPressed: _isLoading || !_canSubmit ? null : _login,
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              children: [
                link(l10n.redesignLoginForgot, _forgotPassword),
                link(l10n.loginRegister, _openRegister),
              ],
            ),
          ] else if (!_otpSent) ...[
            RdPrimaryButton(
              label: l10n.loginSendCode,
              loading: _isLoading,
              onPressed: _isLoading || !_canSubmit ? null : _requestCode,
            ),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight, child: link(l10n.loginRegister, _openRegister)),
          ] else ...[
            OtpCodeField(
              controller: _otpController,
              enabled: !_isLoading,
              onCompleted: (_) => _verifyCode(),
            ),
            const SizedBox(height: 16),
            RdPrimaryButton(
              label: l10n.loginSignIn,
              loading: _isLoading,
              onPressed: _isLoading || !_canSubmit ? null : _verifyCode,
            ),
            const SizedBox(height: 6),
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
