import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Player history type enumeration
enum PlayerHistoryType {
  paused(1),
  unexcused(2),
  criticalPerson(3),
  attendance(4),
  notes(5),
  unpaused(6),
  instrumentChange(7),
  archived(8),
  returned(9),
  transferredFrom(10),
  transferredTo(11),
  copiedFrom(12),
  copiedTo(13),
  approved(14),
  declined(15),
  other(99);

  const PlayerHistoryType(this.value);
  final int value;

  static PlayerHistoryType fromValue(int value) {
    return PlayerHistoryType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PlayerHistoryType.other,
    );
  }
}

/// User role enumeration
enum Role {
  admin(1),
  player(2),
  viewer(3),
  helper(4),
  responsible(5),
  parent(6),
  applicant(7),
  voiceLeader(8),
  voiceLeaderHelper(9),
  none(99);

  const Role(this.value);
  final int value;

  static Role fromValue(int value) {
    return Role.values.firstWhere(
      (e) => e.value == value,
      orElse: () => Role.none,
    );
  }

  // Individual role checks
  bool get isAdmin => this == Role.admin;
  bool get isPlayer => this == Role.player;
  bool get isViewer => this == Role.viewer;
  bool get isHelper => this == Role.helper;
  bool get isResponsible => this == Role.responsible;
  bool get isParent => this == Role.parent;
  bool get isApplicant => this == Role.applicant;
  bool get isVoiceLeader => this == Role.voiceLeader;
  bool get isVoiceLeaderHelper => this == Role.voiceLeaderHelper;

  // Role categories - determines which UI is shown
  /// "Conductors" - have full admin access (see people list, attendance management)
  bool get isConductor =>
      this == Role.admin || this == Role.responsible || this == Role.viewer;

  /// "Helper roles" - have partial admin access (attendance management but not people list)
  bool get isHelperRole => this == Role.helper || this == Role.voiceLeaderHelper;

  /// "Player roles" - only see self-service (their own attendances)
  bool get isPlayerRole =>
      this == Role.player ||
      this == Role.voiceLeader ||
      this == Role.applicant ||
      this == Role.none;

  // Permission checks
  bool get canEdit =>
      this == Role.admin ||
      this == Role.responsible ||
      this == Role.helper ||
      this == Role.voiceLeaderHelper;
  bool get canView => this != Role.none && this != Role.applicant;

  // Tab visibility - determines which navigation tabs are shown
  /// Can see the "People" tab (people list)
  bool get canSeePeopleTab => isConductor;

  /// Can see the "Attendance" tab (attendance management)
  bool get canSeeAttendanceTab => isConductor || isHelperRole;

  /// Can see the "Self-Service" tab (own attendances)
  bool get canSeeSelfServiceTab => isPlayerRole || isHelperRole;

  /// Can see the "Members" tab (if tenant.showMembersList is enabled).
  ///
  /// Excluded roles:
  /// - Conductors (admin, responsible, viewer): see full People tab instead
  /// - APPLICANT: still in waiting/approval state, not yet a member
  /// - PARENT: has own portal
  /// - NONE: fallback role with no permissions (contradicts canView)
  bool get canSeeMembersTab =>
      this == Role.player ||
      this == Role.helper ||
      this == Role.voiceLeader ||
      this == Role.voiceLeaderHelper;

  /// Can see voice leader settings in settings page
  bool get canSeeVoiceLeaderSettings =>
      this == Role.voiceLeader || this == Role.voiceLeaderHelper;

  /// Can see notifications settings (excludes VIEWER, APPLICANT, PARENT, NONE)
  bool get canSeeNotifications =>
      this == Role.admin ||
      this == Role.responsible ||
      this == Role.helper ||
      this == Role.player ||
      this == Role.voiceLeader ||
      this == Role.voiceLeaderHelper;

  /// Can add/edit attendances (not VIEWER - view only)
  bool get canAddAttendance =>
      this == Role.admin ||
      this == Role.responsible ||
      this == Role.helper ||
      this == Role.voiceLeaderHelper;

  /// Get the default route for this role after tenant selection
  String get defaultRoute {
    if (isConductor) return '/people';
    if (isParent) return '/parents';
    return '/signout';
  }
}

/// Attendance status enumeration
enum AttendanceStatus {
  neutral(0),
  present(1),
  excused(2),
  late(3),
  absent(4),
  lateExcused(5);

  const AttendanceStatus(this.value);
  final int value;

  static AttendanceStatus fromValue(int value) {
    return AttendanceStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AttendanceStatus.neutral,
    );
  }

  bool get isPresent => this == AttendanceStatus.present;
  bool get isAbsent => this == AttendanceStatus.absent;
  bool get isExcused => this == AttendanceStatus.excused || this == AttendanceStatus.lateExcused;
  bool get isLate => this == AttendanceStatus.late || this == AttendanceStatus.lateExcused;
  bool get isNeutral => this == AttendanceStatus.neutral;

  /// Returns true if this status counts as "attended" for percentage calculations.
  /// BL-003: Centralized definition - present, late, and lateExcused count as attended.
  bool get countsAsPresent =>
      this == AttendanceStatus.present ||
      this == AttendanceStatus.late ||
      this == AttendanceStatus.lateExcused;

  /// SETTINGS2: Ionic `Utils.getPercentage` — like [countsAsPresent], but with
  /// the tenant flag `shift_excused_as_present` a shift-/work-excused absence
  /// ("Schichtbedingt"/"Arbeitsbedingt" in the notes) also counts as attended.
  bool countsAsAttended({String? notes, bool shiftExcusedAsPresent = false}) =>
      countsAsPresent ||
      (shiftExcusedAsPresent &&
          this == AttendanceStatus.excused &&
          isWorkExcusedNote(notes));

  /// UI color for this status — single source of truth for all attendance colors
  Color get color => switch (this) {
    AttendanceStatus.present => AppColors.success,
    AttendanceStatus.absent => AppColors.danger,
    AttendanceStatus.excused => AppColors.statusExcused,
    AttendanceStatus.late => AppColors.statusLate,
    AttendanceStatus.lateExcused => AppColors.statusLateExcused,
    AttendanceStatus.neutral => AppColors.medium,
  };

  /// UI icon for this status
  IconData get icon => switch (this) {
    AttendanceStatus.present => Icons.check_circle,
    AttendanceStatus.absent => Icons.cancel,
    AttendanceStatus.excused => Icons.event_busy,
    AttendanceStatus.late => Icons.schedule,
    AttendanceStatus.lateExcused => Icons.schedule,
    AttendanceStatus.neutral => Icons.help_outline,
  };

  /// Localized label for this status
  String get label => switch (this) {
    AttendanceStatus.present => 'Anwesend',
    AttendanceStatus.absent => 'Abwesend',
    AttendanceStatus.excused => 'Entschuldigt',
    AttendanceStatus.late => 'Verspätet',
    AttendanceStatus.lateExcused => 'Verspätet (entsch.)',
    AttendanceStatus.neutral => 'Nicht erfasst',
  };
}

/// Supabase table names
enum SupabaseTable {
  conductors('conductors'),
  player('player'),
  viewers('viewers'),
  tenants('tenants'),
  tenantUsers('tenant_users'),
  attendances('attendances'),
  personAttendances('person_attendances'),
  songs('songs'),
  songFiles('song_files'),
  groups('groups'),
  groupCategories('group_categories'),
  teachers('teachers'),
  meetings('meetings'),
  attendanceTypes('attendance_types'),
  shiftPlans('shifts'),
  shiftDefinitions('shift_definitions'),
  history('history'),
  organisations('organisations'),
  churches('bfecg_churches'),
  feedback('feedback'),
  questions('questions');

  const SupabaseTable(this.tableName);
  final String tableName;
}

/// Default attendance type identifiers
enum DefaultAttendanceType {
  orchestra('orchestra'),
  choir('choir'),
  general('general');

  const DefaultAttendanceType(this.value);
  final String value;
}

/// Extra field types for dynamic forms
enum FieldType {
  text('text'),
  textarea('textarea'),
  number('number'),
  date('date'),
  boolean('boolean'),
  select('select'),
  bfecgChurch('bfecg_church');

  const FieldType(this.value);
  final String value;

  static FieldType fromValue(String value) {
    return FieldType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FieldType.text,
    );
  }
}

/// SETTINGS2: Ionic `Utils.isWorkExcused` — absence note marks a shift- or
/// work-related excuse.
bool isWorkExcusedNote(String? notes) =>
    notes != null &&
    (notes.contains('Schichtbedingt') || notes.contains('Arbeitsbedingt'));
