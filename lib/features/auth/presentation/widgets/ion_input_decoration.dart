import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Ionic `ion-input labelPlacement="stacked"` inside an `ion-item lines="full"`:
/// small label above, light placeholder, full-width bottom line. Shared by
/// the login, register and forgot-password screens so they look alike.
InputDecoration ionStackedInputDecoration(
  String label, {
  String? hint,
  Widget? suffixIcon,
}) {
  final line = UnderlineInputBorder(
    borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
  );
  return InputDecoration(
    labelText: label,
    // The placeholder is drawn light (ion-input placeholder opacity) so an
    // empty field never looks prefilled.
    hintText: hint ?? label,
    hintStyle: TextStyle(
      color: AppColors.medium.withValues(alpha: 0.75),
      fontWeight: FontWeight.w400,
    ),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    filled: false,
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    border: line,
    enabledBorder: line,
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    ),
    suffixIcon: suffixIcon,
  );
}
