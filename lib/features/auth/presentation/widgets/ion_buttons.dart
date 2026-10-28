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
    final ios = useIosLook(context);
    final disabled = onPressed == null;
    final shape = ios
        ? const StadiumBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(4));
    final textStyle = ios
        ? const TextStyle(fontSize: 17, fontWeight: FontWeight.w400)
        : const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.84);
    final size = Size.fromHeight(ios ? 44 : 36);
    final padding = EdgeInsets.symmetric(horizontal: ios ? 12 : 15.4);
    final text = Text(ios ? label : label.toUpperCase());
    // ion-spinner slot="start" next to the label while submitting.
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
    var fade = disabled;
    if (solid) {
      final greyDisabled = ios && !primaryWhenDisabled;
      if (greyDisabled) fade = false;
      button = ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              greyDisabled ? AppColors.iosDisabledButton : AppColors.primary,
          disabledForegroundColor: Colors.white,
          minimumSize: size,
          maximumSize: size,
          padding: padding,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
          elevation: ios ? 0 : 2,
          shadowColor: ios ? Colors.transparent : null,
          shape: shape,
          textStyle: textStyle,
        ).copyWith(
          // md keeps the raised look while disabled (only the opacity
          // changes).
          elevation: ios ? null : const WidgetStatePropertyAll(2),
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
      // ion-button block margin: 4px 2px
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Opacity(opacity: fade ? 0.5 : 1, child: button),
    );
  }
}

/// Ionic `ion-button size="small" fill="clear"`: iOS 13.8pt (0.8125em of
/// the 17pt root) in a 29pt pill, md uppercase 13px medium, 27px high.
class IonSmallClearButton extends StatelessWidget {
  const IonSmallClearButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ios = useIosLook(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: ios
              ? const TextStyle(fontSize: 13.8125, fontWeight: FontWeight.w400)
              : const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.78),
          padding: EdgeInsets.symmetric(horizontal: ios ? 12.4 : 11.7),
          minimumSize: Size(0, ios ? 29 : 27.3),
          maximumSize: Size(double.infinity, ios ? 29 : 27.3),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
          shape: ios
              ? const StadiumBorder()
              : RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: onPressed,
        child: Text(ios ? label : label.toUpperCase()),
      ),
    );
  }
}
