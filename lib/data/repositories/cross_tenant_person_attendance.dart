part of 'sign_in_out_repository.dart';

/// Previous status of a sign-in – selects the notification text.
enum SignInType {
  normal('signin'),
  neutral('neutralSignin'),
  late('lateSignIn');

  const SignInType(this.telegramType);

  final String telegramType;

  /// Sign-in type derived from the current status (Ionic signin()).
  static SignInType fromStatus(AttendanceStatus status) {
    if (status == AttendanceStatus.lateExcused) return SignInType.late;
    if (status == AttendanceStatus.neutral) return SignInType.neutral;
    return SignInType.normal;
  }
}

/// Person attendance with its Termin (used by Meine Termine, Übersicht and
/// the plan viewer). In the cross-tenant overview it carries the tenant.
class CrossTenantPersonAttendance {
  final String? id;
  final int? personId;
  final int? attendanceId;
  final AttendanceStatus status;
  final String? notes;
  final String? date;
  final String? typeInfo;
  final String? startTime;
  final String? endTime;
  final String? deadline;
  final int tenantId;
  final String tenantName;
  final String tenantColor;
  final Map<String, dynamic>? plan;

  /// PARITY_SELF: Ionic `attendance.extra_plans` (further plans, e.g. one per
  /// day of a multi-day Termin) for the plan viewer's day chips.
  final List<Map<String, dynamic>>? extraPlans;
  final bool sharePlan;
  final String? typeId;
  final bool includeInAverage;
  final int? durationDays;
  final String? place;
  final String? filesFolder;
  final String? description;
  final String? attachmentUrl;
  final String? attachmentName;
  final List<int> songs;
  final AttendanceType? attendanceType;

  /// false when the person is not part of the Termin (show_all_attendances).
  final bool isMember;
  final Map<String, dynamic>? registrationAnswers;
  final String? legacyType;

  /// DUTY: 'requested' | 'confirmed' | 'self' or null
  final String? dutyState;

  /// IOS_ATT_PAGES: whether the title honours the type's `hide_name`.
  /// Ionic "Meine Termine" joins `attType:type_id(id, highlight,
  /// include_in_average, name, color, registration_fields, duty_mode)` –
  /// without `hide_name` – so its rows always show the type name ("Übung").
  /// The Übersicht loads the full types and honours it.
  final bool honorHideName;

  /// DUTY: Termin of a type in Dienst-Modus
  bool get isDutyType => attendanceType?.dutyMode ?? false;

  /// DUTY: own assignment that still waits for confirmation
  bool get isDutyRequested =>
      isDutyType && dutyState == DutyState.requested && !isCancelledStatus(status);

  CrossTenantPersonAttendance({
    this.id,
    this.personId,
    this.attendanceId,
    this.status = AttendanceStatus.neutral,
    this.notes,
    this.date,
    this.typeInfo,
    this.startTime,
    this.endTime,
    this.deadline,
    required this.tenantId,
    required this.tenantName,
    required this.tenantColor,
    this.plan,
    this.extraPlans,
    this.sharePlan = false,
    this.typeId,
    this.includeInAverage = true,
    this.durationDays,
    this.place,
    this.filesFolder,
    this.description,
    this.attachmentUrl,
    this.attachmentName,
    this.songs = const [],
    this.attendanceType,
    this.isMember = true,
    this.registrationAnswers,
    this.legacyType,
    this.dutyState,
    this.honorHideName = true,
  });

  CrossTenantPersonAttendance copyWith({
    AttendanceStatus? status,
    String? notes,
    Map<String, dynamic>? registrationAnswers,
  }) {
    return CrossTenantPersonAttendance(
      id: id,
      personId: personId,
      attendanceId: attendanceId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      date: date,
      typeInfo: typeInfo,
      startTime: startTime,
      endTime: endTime,
      deadline: deadline,
      tenantId: tenantId,
      tenantName: tenantName,
      tenantColor: tenantColor,
      plan: plan,
      extraPlans: extraPlans,
      sharePlan: sharePlan,
      typeId: typeId,
      includeInAverage: includeInAverage,
      durationDays: durationDays,
      place: place,
      filesFolder: filesFolder,
      description: description,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      songs: songs,
      attendanceType: attendanceType,
      isMember: isMember,
      registrationAnswers: registrationAnswers ?? this.registrationAnswers,
      legacyType: legacyType,
      dutyState: dutyState,
      honorHideName: honorHideName,
    );
  }

  /// Duration including the type's default for all-day types.
  int? get effectiveDurationDays => durationDays ??
      ((attendanceType?.allDay ?? false) ? attendanceType?.durationDays : null);

  /// Past only once the last day of a multi-day Termin is over.
  bool get isPast => EventListUtils.hasEnded(date, effectiveDurationDays);

  /// Today, running or in the future.
  bool get isUpcoming => date != null && !isPast;

  /// Starts today or still running today ("Heute").
  bool get isRunning => EventListUtils.isRunning(date, effectiveDurationDays);

  /// Check if the deadline has passed
  bool get isDeadlinePassed => !EventListUtils.isSigninOpen(deadline);

  /// Status letter (Ionic att.text)
  String get text => isMember ? EventListUtils.attText(status) : '';

  /// Check if the person was present (attended)
  bool get attended => status.countsAsPresent;

  bool get isExcusedStatus =>
      status == AttendanceStatus.excused ||
      status == AttendanceStatus.lateExcused;

  /// Highlighted type (Vortrag etc.)
  bool get highlight => attendanceType?.highlight ?? legacyType == 'vortrag';

  /// Check if plan is available for viewing
  bool get hasPlan {
    if (!sharePlan || plan == null) return false;
    final fields = plan?['fields'] as List?;
    return fields != null && fields.isNotEmpty;
  }

  /// Get deadline as DateTime
  DateTime? get deadlineDateTime => EventListUtils.deadlineLocal(deadline);

  /// Get readable deadline text
  String? get deadlineText {
    if (deadline == null) return null;
    return EventListUtils.deadlineText(deadline);
  }

  /// Readable date ("Di., 20.10.2026", range for multi-day all-day types)
  String get readableDate => EventListUtils.readableDate(
        date,
        allDay: attendanceType?.allDay ?? false,
        durationDays: attendanceType?.durationDays,
      );

  /// Title like Ionic `getTypeTitle`: typeInfo, else type name unless hidden.
  String get title {
    if (typeInfo != null && typeInfo!.isNotEmpty) return typeInfo!;
    final type = attendanceType;
    if (type == null || (honorHideName && type.hideName)) return '';
    return type.name;
  }

  /// Title shown in the lists; falls back to the readable date.
  String get eventTitle => title.isNotEmpty ? title : readableDate;

  /// Registration fields of the attendance type.
  List<RegistrationField> get registrationFields =>
      attendanceType?.registrationFields ?? const [];

  /// Time line; multi-day Termine (and the current card) also show the date
  /// unless it is the title.
  String eventMeta({bool withDate = false, bool withPlace = true}) {
    final type = attendanceType;
    final showDate = withDate ||
        EventListUtils.isMultiDay(durationDays) ||
        ((type?.allDay ?? false) && (type?.durationDays ?? 1) > 1);
    final readable = readableDate;
    return EventListUtils.meta([
      showDate && readable != eventTitle ? readable : '',
      EventListUtils.timeRange(startTime ?? type?.startTime, endTime ?? type?.endTime),
      withPlace ? place : '',
    ]);
  }

  /// Display title - returns typeInfo if not empty, otherwise 'Termin'
  String get displayTitle {
    if (typeInfo != null && typeInfo!.isNotEmpty) {
      return typeInfo!;
    }
    return title.isNotEmpty ? title : l10nWithoutContext.attendanceEventFallback;
  }
}
