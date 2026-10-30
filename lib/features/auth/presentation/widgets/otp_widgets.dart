import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/auth_flow_service.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/ion_button_label.dart';

/// AUTH: Login-Modus (Ionic ion-segment "Passwort" / "Code per E-Mail").
enum AuthMode { password, otp }

/// Segment to switch between password and e-mail code mode
/// (Ionic `.mode-segment` of login.page.scss / register-modal.component.scss).
///
/// MD: primary-tinted track with a tinted pill behind the checked label.
/// iOS: the page stylesheet hides the native indicator, so only the label
/// colour (primary vs. primary 60 %) marks the checked button.
class AuthModeSegment extends StatelessWidget {
  const AuthModeSegment({
    super.key,
    required this.mode,
    required this.onChanged,
    this.enabled = true,
    this.trackAlpha = 0.08,
    this.fontSize = 12.8,
  });

  final AuthMode mode;
  final ValueChanged<AuthMode> onChanged;
  final bool enabled;

  /// `--background: rgba(primary, .08)` (login) / `.1` (register modal).
  final double trackAlpha;

  /// 0.8rem (login) / 0.85rem (register modal).
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    Widget button(AuthMode value, String label) {
      final checked = value == mode;
      return Expanded(
        child: Semantics(
          button: true,
          selected: checked,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled && !checked ? () => onChanged(value) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              // min-height 34px; md segment buttons stay 46 high (48 - 2).
              constraints: BoxConstraints(minHeight: ios ? 34 : 46),
              margin: ios ? const EdgeInsets.symmetric(vertical: 2) : null,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                // --background-checked rgba(primary, .18) in both modes; iOS
                // only drops the indicator (login/register scss `.ios &`).
                color: checked
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(ios ? 25 : 9.6),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  // rem-based: 1rem = 17px on the iPhone (-apple-system-body)
                  fontSize: ios ? fontSize * 17 / 16 : fontSize,
                  fontWeight: FontWeight.w600,
                  color: checked
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: trackAlpha),
          // iOS 26 theme: ion-segment border-radius 15.5px; MD: 0.75rem.
          borderRadius: BorderRadius.circular(ios ? 15.5 : 12),
        ),
        child: Row(
          children: [
            button(AuthMode.password, context.l10n.loginModePassword),
            button(AuthMode.otp, context.l10n.loginModeOtp),
          ],
        ),
      ),
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
///
/// Looks like Ionic `ion-input-otp size="small"`: six round outlined boxes
/// (44 x 48, narrower on small phones) with the label centred below.
class OtpCodeField extends StatefulWidget {
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
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant OtpCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.controller.text;
    final width = MediaQuery.sizeOf(context).width;
    // ion-input-otp: --width clamp(32px, 12vw, 44px), --height clamp(38px, 13vw, 48px)
    final boxWidth = (width * 0.12).clamp(32.0, 44.0);
    final boxHeight = (width * 0.13).clamp(38.0, 48.0);
    final borderIdle = theme.brightness == Brightness.dark
        ? AppColors.dividerDark
        : AppColors.dividerLight;

    Widget box(int i) {
      final active = _focusNode.hasFocus &&
          (i == text.length || (i == kOtpLength - 1 && text.length == kOtpLength));
      return Container(
        width: boxWidth,
        height: boxHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.primary : borderIdle,
            width: active ? 2 : 1,
          ),
        ),
        child: Text(
          i < text.length ? text[i] : '',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
      );
    }

    return Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < kOtpLength; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    box(i),
                  ],
                ],
              ),
              // Invisible input on top: keyboard, paste and SMS/e-mail
              // one-time-code autofill go through a real text field.
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: kOtpLength,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (value) {
                      if (value.length == kOtpLength) {
                        widget.onCompleted?.call(value);
                      }
                    },
                    onSubmitted: (value) {
                      if (value.isNotEmpty) widget.onCompleted?.call(value);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.loginOtpLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.medium),
          ),
        ],
      ),
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
        child: IonButtonLabel(cooldown.active
            ? context.l10n.loginResendIn(cooldown.remaining)
            : context.l10n.loginResendCode),
      ),
    );
  }
}
