import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/auth_flow_service.dart';
import '../../../../l10n/l10n.dart'; // I18N_INFRA

/// AUTH: Login-Modus (Ionic ion-segment "Passwort" / "Code per E-Mail").
enum AuthMode { password, otp }

/// Segment to switch between password and e-mail code mode.
class AuthModeSegment extends StatelessWidget {
  const AuthModeSegment({
    super.key,
    required this.mode,
    required this.onChanged,
    this.enabled = true,
  });

  final AuthMode mode;
  final ValueChanged<AuthMode> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AuthMode>(
      segments: [
        ButtonSegment(
          value: AuthMode.password,
          label: Text(context.l10n.loginModePassword),
          icon: const Icon(Icons.lock_outline),
        ),
        ButtonSegment(
          value: AuthMode.otp,
          label: Text(context.l10n.loginModeOtp),
          icon: const Icon(Icons.mark_email_unread_outlined),
        ),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged:
          enabled ? (selection) => onChanged(selection.first) : null,
    );
  }
}

/// Countdown for "Code erneut senden" (Ionic startResendCooldown, 30 s).
class ResendCooldown extends ChangeNotifier {
  Timer? _timer;
  int _remaining = 0;

  int get remaining => _remaining;
  bool get active => _remaining > 0;

  void start([int seconds = kOtpResendCooldownSeconds]) {
    _timer?.cancel();
    _remaining = seconds;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _remaining -= 1;
      if (_remaining <= 0) {
        _remaining = 0;
        t.cancel();
      }
      notifyListeners();
    });
  }

  void reset() {
    _timer?.cancel();
    _remaining = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// 6-digit code field ("Code aus der E-Mail"); calls [onCompleted] when all
/// digits are entered (Ionic ionComplete).
class OtpCodeField extends StatelessWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.onCompleted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: kOtpLength,
      autofillHints: const [AutofillHints.oneTimeCode],
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            letterSpacing: 12,
            fontWeight: FontWeight.w600,
          ),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: context.l10n.loginOtpLabel,
        counterText: '',
        prefixIcon: const Icon(Icons.pin_outlined),
      ),
      onChanged: (value) {
        if (value.length == kOtpLength) onCompleted?.call(value);
      },
      onSubmitted: (value) {
        if (value.isNotEmpty) onCompleted?.call(value);
      },
    );
  }
}

/// "Code erneut senden" / "Erneut senden (Ns)" button.
class ResendCodeButton extends StatelessWidget {
  const ResendCodeButton({
    super.key,
    required this.cooldown,
    required this.onResend,
    this.enabled = true,
  });

  final ResendCooldown cooldown;
  final VoidCallback onResend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cooldown,
      builder: (context, _) => TextButton(
        onPressed: (!enabled || cooldown.active) ? null : onResend,
        child: Text(cooldown.active
            ? context.l10n.loginResendIn(cooldown.remaining)
            : context.l10n.loginResendCode),
      ),
    );
  }
}
