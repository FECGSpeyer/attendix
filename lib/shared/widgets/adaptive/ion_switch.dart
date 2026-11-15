import 'package:flutter/material.dart';

import '../../../core/theme/redesign/rd_theme.dart';
import 'adaptive_platform.dart';

/// IONIC_PARITY: `ion-toggle`.
///
/// iOS look and the Beta keep the platform switch (`Switch.adaptive`, themed
/// app-wide). The Material look draws the Ionic md toggle, which Material 3
/// has no shape for: a 36 × 14 track with a 20px handle that ends flush
/// with the track (the Material 3 switch is 52 × 32).
class IonSwitch extends StatelessWidget {
  const IonSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.activeTrackColor,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final Color? activeTrackColor;

  /// Whether [context] draws the Ionic md toggle instead of the platform one.
  static bool usesMdToggle(BuildContext context) =>
      !useIosLook(context) && context.rdSkin == null;

  @override
  Widget build(BuildContext context) {
    if (!usesMdToggle(context)) {
      return Switch.adaptive(
        value: value,
        onChanged: onChanged,
        // ignore: deprecated_member_use
        activeColor: activeColor,
        activeTrackColor: activeTrackColor,
      );
    }
    final theme = SwitchTheme.of(context);
    final states = <WidgetState>{if (value) WidgetState.selected};
    final scheme = Theme.of(context).colorScheme;
    final handle = (value ? activeColor : null) ??
        theme.thumbColor?.resolve(states) ??
        (value ? scheme.primary : Colors.white);
    final track = (value ? activeTrackColor : null) ??
        theme.trackColor?.resolve(states) ??
        (value
            ? scheme.primary.withValues(alpha: 0.5)
            : scheme.onSurface.withValues(alpha: 0.39));
    final enabled = onChanged != null;
    void toggle() => onChanged?.call(!value);
    return Semantics(
      toggled: value,
      enabled: enabled,
      onTap: enabled ? toggle : null,
      // Keyboard: Tab reaches the toggle, Space/Enter switch it (as the
      // Material switch did before).
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => toggle()),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? toggle : null,
          onHorizontalDragEnd: enabled
              ? (d) {
                  final v = d.primaryVelocity ?? 0;
                  final rtl = Directionality.of(context) == TextDirection.rtl;
                  if (v == 0) return;
                  if (((v > 0) != rtl) != value) toggle();
                }
              : null,
          child: Opacity(
            // ion-toggle.toggle-disabled: opacity .3
            opacity: enabled ? 1 : 0.3,
            child: SizedBox(
              width: 36,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 36,
                    height: 14,
                    decoration: BoxDecoration(
                      color: track,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    alignment: value
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: handle,
                        shape: BoxShape.circle,
                        // md elevation 2
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x33000000),
                              offset: Offset(0, 3),
                              blurRadius: 1,
                              spreadRadius: -2),
                          BoxShadow(
                              color: Color(0x24000000),
                              offset: Offset(0, 2),
                              blurRadius: 2),
                          BoxShadow(
                              color: Color(0x1F000000),
                              offset: Offset(0, 1),
                              blurRadius: 5),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// IONIC_PARITY: an `ion-item` with an `ion-toggle` at the end
/// (`SwitchListTile.adaptive` with the Ionic md toggle in the Material
/// look, see [IonSwitch]).
class IonSwitchListTile extends StatelessWidget {
  const IonSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    if (!IonSwitch.usesMdToggle(context)) {
      return SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: title,
        subtitle: subtitle,
        secondary: secondary,
        contentPadding: contentPadding,
      );
    }
    final enabled = onChanged != null;
    return MergeSemantics(
      child: ListTile(
        leading: secondary,
        title: title,
        subtitle: subtitle,
        contentPadding: contentPadding,
        enabled: enabled,
        onTap: enabled ? () => onChanged!(!value) : null,
        trailing: ExcludeFocus(
          child: IonSwitch(value: value, onChanged: onChanged),
        ),
      ),
    );
  }
}
