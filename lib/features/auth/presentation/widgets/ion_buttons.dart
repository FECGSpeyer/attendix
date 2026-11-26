import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Ionic `ion-button expand="block"` on the pre-login screens (login card,
/// register modal), measured on the Ionic pages:
/// - iOS (ios26 theme): 44pt pill, 17pt regular label, no shadow,
/// - md: 36px high, 4px radius, uppercase 14px medium label with 0.06em
///   letter spacing; solid buttons are raised.
///
/// Disabled = the enabled look at opacity .5 (Ionic `button-disabled`),
/// except iOS solid buttons without `color` ([primaryWhenDisabled] false),
/// which the ios26 theme greys out (#ccc, see the app theme).
class IonBlockButton extends StatelessWidget {
  const IonBlockButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.solid = true,
    this.loading = false,
    this.primaryWhenDisabled = true,
  });

  final String label;
  final VoidCallback? onPressed;

  /// `fill="solid"` (default) or `fill="clear"`.
  final bool solid;
  final bool loading;

  /// `color="primary"` set explicitly (login card): disabled stays teal.
  final bool primaryWhenDisabled;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(4));
    const textStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.84,
    );
    const size = Size.fromHeight(36);
    const padding = EdgeInsets.symmetric(horizontal: 15.4);
    final text = Text(label.toUpperCase());
    final Widget child = loading
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: AppSpinner(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      solid ? Colors.white : AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: text),
            ],
          )
        : text;

    Widget button;
    if (solid) {
      button = ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary,
          disabledForegroundColor: Colors.white,
          minimumSize: size,
          maximumSize: size,
          padding: padding,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
          elevation: 2,
          shape: shape,
          textStyle: textStyle,
        ).copyWith(
          elevation: const WidgetStatePropertyAll(2),
        ),
        onPressed: onPressed,
        child: child,
      );
    } else {
      button = TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.primary,
          minimumSize: size,
          maximumSize: size,
          padding: padding,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
          shape: shape,
          textStyle: textStyle,
        ),
        onPressed: onPressed,
        child: child,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Opacity(opacity: disabled ? 0.5 : 1, child: button),
    );
  }
}
