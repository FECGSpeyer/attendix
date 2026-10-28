import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Ionic `ion-input labelPlacement="stacked"` inside an `ion-item lines="full"`:
/// label above (black, ~15 pt), placeholder in #777 at the input size
/// (17 pt), full-width bottom line. Shared by the login, register and
/// forgot-password screens so they look alike.
///
/// [lineColor] defaults to the login card line (`rgba(primary, .3)`); the
/// register modal passes the plain item border colour of an `ion-list
/// lines="full"`.
InputDecoration ionStackedInputDecoration(
  String label, {
  String? hint,
  Widget? suffixIcon,
  double labelSize = 15,
  Color? lineColor,
  Color labelColor = AppColors.textPrimaryLight,
}) {
  final line = UnderlineInputBorder(
    borderSide: BorderSide(
        color: lineColor ?? AppColors.primary.withValues(alpha: 0.3)),
  );
  // Flutter draws a floating label at 75 % of its style size.
  final labelStyle = TextStyle(
    color: labelColor,
    fontSize: labelSize / 0.75,
    fontWeight: FontWeight.w400,
  );
  return InputDecoration(
    labelText: label,
    labelStyle: labelStyle,
    floatingLabelStyle: labelStyle,
    // ion-input placeholder: #777 at the input font size.
    hintText: hint ?? label,
    hintStyle: const TextStyle(
      color: Color(0xFF777777),
      fontSize: 17,
      fontWeight: FontWeight.w400,
    ),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    filled: false,
    contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
    border: line,
    enabledBorder: line,
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    ),
    suffixIcon: suffixIcon,
  );
}

/// Value style of the stacked inputs (17 pt like an iOS ion-input).
const TextStyle ionStackedInputStyle = TextStyle(fontSize: 17);
