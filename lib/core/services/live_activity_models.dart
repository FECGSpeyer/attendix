part of 'live_activity_service.dart';

// LIVE_ACTIVITY: port of Ionic src/app/services/live-activity/*.

/// A Live Activity of one plan of a Termin.
class LiveActivityTarget {
  const LiveActivityTarget({required this.attendanceId, required this.planKey});

  final int attendanceId;
  final String planKey;

  String get key => '$attendanceId:$planKey';

  static LiveActivityTarget? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['attendanceId'];
    final planKey = raw['planKey'];
    if (id is! num || planKey is! String) return null;
    return LiveActivityTarget(attendanceId: id.toInt(), planKey: planKey);
  }
}

/// A plan that should show a Live Activity right now.
class LivePlanCandidate extends LiveActivityTarget {
  const LivePlanCandidate({
    required super.attendanceId,
    required super.planKey,
    required this.title,
    required this.state,
  });

  final String title;
  final LivePlanState state;
}

/// What the service needs from the app (tenant, role, data access, navigation).
abstract class LiveActivityHost {
  int? get tenantId;

  /// IANA time zone of the tenant's plan times.
  String get timezone;
  Role get role;
  String? get userId;

  /// Supabase URL and anon key, for the native background token upload.
  String get apiUrl;
  String get apiKey;

  Future<bool> loadEnabled();

  /// Whether ORG-Pläne of other groups / ad-hoc ORG-Pläne should be shown as
  /// Live Activities on this device (default true).
  Future<bool> loadOrgPlansEnabled();

  Future<List<PlanAttendance>> loadAttendances(DateTime from, DateTime to);

  /// For non-leader players: subset of [attendanceIds] that the player sees in
  /// their Termine list and did not sign out from. Returns null when no player
  /// filter applies (leaders, viewers, or unsupported contexts).
  Future<Set<int>?> loadVisiblePlayerAttendanceIds(List<int> attendanceIds);

  /// Name and colour of the tenant's Termin types by id.
  Future<Map<String, LiveTermType>> termTypes();

  /// ORG plans of the current tenant's organisation dated within
  /// [[from], [to]] (Ionic 4.17.8 `addOrgPlans`); null without an
  /// organisation.
  Future<LiveOrgPlans?> loadOrgPlans(DateTime from, DateTime to);

  /// Checks whether a running native activity not covered by the current
  /// tenant's loaded candidates is still valid (e.g. an active plan in another
  /// tenant of the user) or should be ended as a stale/deleted ghost activity.
  Future<bool> isActivityStillValid(LiveActivityTarget target);

  Future<void> saveToken({
    required String userId,
    required String kind,
    required String token,
    int attendanceId = 0,
    String planKey = '',
  });

  /// SOL_FIX15: deletes this device's token rows ([tokens]) of [userId]
  /// (logout). Must run while [userId] is still signed in (RLS owner only).
  Future<void> removeTokens({required String userId, required List<String> tokens});

  /// Opens the plan viewer of a Termin in live mode.
  Future<void> openPlan(int attendanceId, {String planKey = ''});

  /// Opens an ad-hoc ORG plan (`shared_plans.id`) in the plan viewer in
  /// live mode, like on the ORG-Pläne page.
  Future<void> openSharedOrgPlan(String id);
}

/// Name and colour (`attendance_types.color`) of a Termin type.
typedef LiveTermType = ({String name, String? color});

/// ORG plans of the organisation: Termine marked as ORG plan and ad-hoc
/// ORG plans without a Termin.
typedef LiveOrgPlans = ({
  List<OrgLiveAttendance> attendances,
  List<SharedPlan> sharedPlans,
});

