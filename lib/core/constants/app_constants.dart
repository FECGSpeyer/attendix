import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'enums.dart';

/// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'Attendix';
  static const String appVersion = '0.24.2';

  /// Demo credentials from environment (Ionic `environment.demoMail` /
  /// `environment.demoPassword`).
  ///
  /// DEMO_GUARD: Ionic offers "Demo starten" in production too, and the
  /// `.env` asset is bundled into every build anyway, so the former
  /// debug-only gate (SEC-009) hid the link without protecting anything.
  /// The demo account is now write-protected via [DemoGuard]
  /// (lib/core/utils/demo_guard.dart). Leave DEMO_EMAIL/DEMO_PASSWORD
  /// unset to hide the link.
  static String get demoMail => _env('DEMO_EMAIL');

  static String get demoPassword => _env('DEMO_PASSWORD');

  /// E-mail used to detect the demo account for the write protection.
  static String get demoMailForGuard => demoMail;

  static String _env(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }
}

/// Default avatar image URL
const String kDefaultAvatarUrl = 'https://ionicframework.com/docs/img/demos/avatar.svg';

/// Standard sign-out/late reasons used across self-service and parents portal
const List<String> kSignOutReasons = [
  'Krankheitsbedingt',
  'Urlaubsbedingt',
  'Arbeitsbedingt',
  'Familienbedingt',
  'Sonstiger Grund',
];

/// Checklist deadline options (in hours before event)
const List<ChecklistDeadlineOption> kChecklistDeadlineOptions = [
  ChecklistDeadlineOption(label: '1 Stunde vorher', hours: 1),
  ChecklistDeadlineOption(label: '1 Tag vorher', hours: 24),
  ChecklistDeadlineOption(label: '2 Tage vorher', hours: 48),
  ChecklistDeadlineOption(label: '1 Woche vorher', hours: 168),
];

/// Checklist deadline option model
class ChecklistDeadlineOption {
  const ChecklistDeadlineOption({
    required this.label,
    required this.hours,
  });

  final String label;
  final int hours;
}

/// Attendance status transition mappings
class AttendanceStatusMapping {
  AttendanceStatusMapping._();

  /// Default status transition (all statuses enabled)
  static const Map<AttendanceStatus, AttendanceStatus> defaultMapping = {
    AttendanceStatus.neutral: AttendanceStatus.present,
    AttendanceStatus.absent: AttendanceStatus.present,
    AttendanceStatus.present: AttendanceStatus.excused,
    AttendanceStatus.excused: AttendanceStatus.late,
    AttendanceStatus.late: AttendanceStatus.absent,
    AttendanceStatus.lateExcused: AttendanceStatus.absent,
  };

  /// No neutral status
  static const Map<AttendanceStatus, AttendanceStatus> noNeutral = {
    AttendanceStatus.present: AttendanceStatus.excused,
    AttendanceStatus.excused: AttendanceStatus.late,
    AttendanceStatus.late: AttendanceStatus.absent,
    AttendanceStatus.absent: AttendanceStatus.present,
    AttendanceStatus.lateExcused: AttendanceStatus.absent,
  };

  /// No excused status
  static const Map<AttendanceStatus, AttendanceStatus> noExcused = {
    AttendanceStatus.neutral: AttendanceStatus.present,
    AttendanceStatus.absent: AttendanceStatus.present,
    AttendanceStatus.present: AttendanceStatus.late,
    AttendanceStatus.late: AttendanceStatus.absent,
    AttendanceStatus.lateExcused: AttendanceStatus.absent,
    AttendanceStatus.excused: AttendanceStatus.present,
  };

  /// No late status
  static const Map<AttendanceStatus, AttendanceStatus> noLate = {
    AttendanceStatus.neutral: AttendanceStatus.present,
    AttendanceStatus.absent: AttendanceStatus.present,
    AttendanceStatus.present: AttendanceStatus.excused,
    AttendanceStatus.excused: AttendanceStatus.absent,
    AttendanceStatus.late: AttendanceStatus.absent,
    AttendanceStatus.lateExcused: AttendanceStatus.absent,
  };

  /// No neutral and no excused
  static const Map<AttendanceStatus, AttendanceStatus> noNeutralNoExcused = {
    AttendanceStatus.present: AttendanceStatus.absent,
    AttendanceStatus.late: AttendanceStatus.present,
    AttendanceStatus.lateExcused: AttendanceStatus.present,
    AttendanceStatus.absent: AttendanceStatus.late,
    AttendanceStatus.excused: AttendanceStatus.present,
  };

  /// No late and no excused
  static const Map<AttendanceStatus, AttendanceStatus> noLateNoExcused = {
    AttendanceStatus.neutral: AttendanceStatus.present,
    AttendanceStatus.absent: AttendanceStatus.present,
    AttendanceStatus.present: AttendanceStatus.absent,
    AttendanceStatus.excused: AttendanceStatus.present,
    AttendanceStatus.late: AttendanceStatus.present,
    AttendanceStatus.lateExcused: AttendanceStatus.present,
  };

  /// No late and no neutral
  static const Map<AttendanceStatus, AttendanceStatus> noLateNoNeutral = {
    AttendanceStatus.present: AttendanceStatus.excused,
    AttendanceStatus.excused: AttendanceStatus.absent,
    AttendanceStatus.absent: AttendanceStatus.present,
    AttendanceStatus.late: AttendanceStatus.present,
    AttendanceStatus.lateExcused: AttendanceStatus.present,
  };

  /// Only present and absent
  static const Map<AttendanceStatus, AttendanceStatus> onlyPresentAbsent = {
    AttendanceStatus.present: AttendanceStatus.absent,
    AttendanceStatus.absent: AttendanceStatus.present,
    AttendanceStatus.late: AttendanceStatus.present,
    AttendanceStatus.lateExcused: AttendanceStatus.present,
    AttendanceStatus.excused: AttendanceStatus.present,
  };

  /// Only present and excused
  static const Map<AttendanceStatus, AttendanceStatus> onlyPresentExcused = {
    AttendanceStatus.present: AttendanceStatus.excused,
    AttendanceStatus.excused: AttendanceStatus.present,
    AttendanceStatus.late: AttendanceStatus.present,
    AttendanceStatus.lateExcused: AttendanceStatus.present,
  };

  /// Get the appropriate mapping based on settings
  static Map<AttendanceStatus, AttendanceStatus> getMapping({
    bool hasNeutral = true,
    bool hasExcused = true,
    bool hasLate = true,
  }) {
    if (!hasNeutral && !hasExcused && !hasLate) {
      return onlyPresentAbsent;
    }
    if (!hasNeutral && !hasExcused) {
      return noNeutralNoExcused;
    }
    if (!hasNeutral && !hasLate) {
      return noLateNoNeutral;
    }
    if (!hasExcused && !hasLate) {
      return noLateNoExcused;
    }
    if (!hasNeutral) {
      return noNeutral;
    }
    if (!hasExcused) {
      return noExcused;
    }
    if (!hasLate) {
      return noLate;
    }
    return defaultMapping;
  }

  /// Get the next status for cycling through attendance states
  static AttendanceStatus getNextStatus(
    AttendanceStatus current, {
    bool hasNeutral = true,
    bool hasExcused = true,
    bool hasLate = true,
  }) {
    final mapping = getMapping(
      hasNeutral: hasNeutral,
      hasExcused: hasExcused,
      hasLate: hasLate,
    );
    return mapping[current] ?? AttendanceStatus.present;
  }
}

/// Animation durations
class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 250);
}

/// App dimensions
class AppDimensions {
  AppDimensions._();

  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  static const double borderRadiusS = 4.0;
  static const double borderRadiusM = 8.0;
  static const double borderRadiusL = 12.0;
  static const double borderRadiusXL = 16.0;

  static const double iconSizeS = 16.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 32.0;
  static const double iconSizeXL = 48.0;

  static const double avatarSizeS = 32.0;
  static const double avatarSizeM = 48.0;
  static const double avatarSizeL = 64.0;
  static const double avatarSizeXL = 96.0;

  static const double maxContentWidth = 600.0;
  static const double maxFormWidth = 400.0;
}