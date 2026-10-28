import 'package:flutter/material.dart';

/// App color palette
class AppColors {
  AppColors._();

  // Primary colors (Ionic src/theme/variables.scss: --ion-color-primary
  // #438e96, tint #5699a1, shade #3b7d84)
  static const Color primary = Color(0xFF438E96);
  static const Color primaryLight = Color(0xFF5699A1);
  static const Color primaryDark = Color(0xFF3B7D84);

  // Secondary colors
  static const Color secondary = Color(0xFF3DC2FF);
  static const Color secondaryLight = Color(0xFF6FD4FF);
  static const Color secondaryDark = Color(0xFF0A9ACC);

  // Tertiary/Accent
  static const Color tertiary = Color(0xFF5260FF);
  static const Color tertiaryLight = Color(0xFF7A85FF);
  static const Color tertiaryDark = Color(0xFF2A3ACC);

  // Success (Ionic variables.scss: #00815E)
  static const Color success = Color(0xFF00815E);
  static const Color successLight = Color(0xFF3BB96D);
  static const Color successDark = Color(0xFF219C52);

  // Warning
  static const Color warning = Color(0xFFFFC409);
  static const Color warningLight = Color(0xFFFFCA22);
  static const Color warningDark = Color(0xFFE0AC08);

  // Danger/Error (Ionic variables.scss: #b95b5b)
  static const Color danger = Color(0xFFB95B5B);
  static const Color dangerLight = Color(0xFFC06B6B);
  static const Color dangerDark = Color(0xFFA35050);

  // Custom Ionic colors (variables.scss: rosa, mint, orange, holiday)
  static const Color rosa = Color(0xFFBE72C0);
  static const Color mint = Color(0xFF36C2C4);
  static const Color orange = Color(0xFFEC8D09);
  static const Color holiday = Color(0xFF9F6073);

  // Info (cyan blue)
  static const Color info = Color(0xFF3DC2FF);
  static const Color infoLight = Color(0xFF6FD4FF);
  static const Color infoDark = Color(0xFF0A9ACC);

  // Neutral colors
  static const Color dark = Color(0xFF222428);
  static const Color medium = Color(0xFF92949C);
  static const Color light = Color(0xFFF4F5F8);

  // Background colors. Ionic runs the iOS theme with inset lists: grouped
  // light-grey page background, white cards/lists; dark: black page with
  // #1c1c1d cards (variables.scss attendix-dark-theme-ios-body).
  static const Color backgroundLight = Color(0xFFF2F2F7);
  static const Color backgroundDark = Color(0xFF000000);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1C1C1D);
  // Toolbar / tab bar (iOS translucent bars)
  static const Color barLight = Color(0xFFF7F7F7);
  static const Color barDark = Color(0xFF161617);
  // Input fill on white cards
  static const Color inputFillLight = Color(0xFFF4F5F8);
  static const Color inputFillDark = Color(0xFF2C2C2E);

  // Text colors
  static const Color textPrimaryLight = Color(0xFF222428);
  static const Color textSecondaryLight = Color(0xFF5F6368);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);

  // Attendance status colors (Ionic status-info.component getStatusColor /
  // utilities/event-list statusColor): present=success, absent=danger,
  // excused=warning, late=tertiary, lateExcused=rosa, neutral=medium.
  static const Color statusPresent = success;
  static const Color statusAbsent = danger;
  static const Color statusExcused = warning;
  static const Color statusLate = tertiary;
  static const Color statusNeutral = medium;
  static const Color statusLateExcused = rosa;

  // Divider
  static const Color dividerLight = Color(0xFFC8C7CC);
  static const Color dividerDark = Color(0xFF38383A);

  // Shadow
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowDark = Color(0x40000000);

  /// Get color for attendance status
  static Color getStatusColor(int statusValue) {
    switch (statusValue) {
      case 0:
        return statusNeutral;
      case 1:
        return statusPresent;
      case 2:
        return statusExcused;
      case 3:
        return statusLate;
      case 4:
        return statusAbsent;
      case 5:
        return statusLateExcused;
      default:
        return statusNeutral;
    }
  }

  /// Get contrast color (black or white) for a given background
  static Color getContrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
