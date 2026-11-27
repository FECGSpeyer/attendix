part of 'offline_queue_service.dart';

/// Checks the current network state (navigator.onLine on web).
final connectivityCheckProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true; // Unknown -> assume online, write directly
    }
  };
});

/// SOL_FIX4: id of the signed-in auth user (null when signed out or when
/// Supabase is not initialised, e.g. in tests). Read at call time.
final offlineQueueUserIdProvider = Provider<String? Function()>((ref) {
  return () {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  };
});

/// SOL_FIX9: identity of the current auth session (null when signed out).
/// Taken from the access token's `session_id` claim, which stays the same
/// across token refreshes but changes on every new sign-in; falls back to
/// the user id when the token carries no such claim. Read at call time.
final offlineQueueSessionIdProvider = Provider<String? Function()>((ref) {
  return () {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return null;
      return authSessionIdentity(session.accessToken) ??
          'user:${session.user.id}';
    } catch (_) {
      return null;
    }
  };
});

/// SOL_FIX9: `session_id` claim of a Supabase access token (JWT), or null
/// when the token cannot be decoded or has no such claim.
String? authSessionIdentity(String accessToken) {
  try {
    final parts = accessToken.split('.');
    if (parts.length != 3) return null;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return null;
    final id = payload['session_id'];
    return id is String && id.isNotEmpty ? id : null;
  } catch (_) {
    return null;
  }
}

/// SOL_FIX9: auth events (sign-out ends a running replay). Empty stream
/// when Supabase is not initialised (tests).
final offlineQueueAuthEventsProvider =
    Provider<Stream<AuthChangeEvent>>((ref) {
  try {
    return Supabase.instance.client.auth.onAuthStateChange.map((s) => s.event);
  } catch (_) {
    return const Stream<AuthChangeEvent>.empty();
  }
});

/// Replays one queued write against Supabase.
///
/// SOL_FIX11: [isSessionCurrent] must be checked again right before the
/// mutation (after any async validation). When it returns false the write
/// must not run; throw [OfflineSessionChangedException] so the entry stays
/// queued for its author.
typedef OfflineFlushFn = Future<void> Function(
  QueuedWrite entry,
  bool Function() isSessionCurrent,
);

final offlineFlushFnProvider = Provider<OfflineFlushFn>((ref) {
  return (entry, isSessionCurrent) async {
    // Fresh repository instance so the replay uses the tenant of the entry
    // without touching the shared (current tenant) repository.
    final repo = AttendanceRepository(ref)..bindTenantId(entry.tenantId);
    await repo.updatePersonAttendance(
      entry.personAttendanceId,
      Map<String, dynamic>.from(entry.payload),
      isSessionCurrent: isSessionCurrent,
      // changed_by = author of the queued write (the guard ensures it is
      // still the signed-in user), never a user re-read later.
      actingUserId: entry.userId,
    );
  };
});

/// SOL_FIX13: author, tenant and auth session of one person_attendances
/// write, captured synchronously when the user acts. [OfflineQueueNotifier.enqueueIfOffline]
/// binds the write to it; on the online path the caller passes [isCurrent]
/// and [userId] to the repository, which checks the session again right
/// before the mutation (an account / tenant switch in between never writes
/// under the new account).
class OfflineWriteSession {
  OfflineWriteSession._({
    required this.userId,
    required this.tenantId,
    required bool Function() isCurrent,
  }) : _isCurrent = isCurrent;

  /// SOL_FIX15: session of a direct (non-queued) write flow, e.g. the own
  /// master data: signed-in user, auth session and tenant, captured
  /// synchronously before the flow's first await. [isCurrent] is false
  /// once any of them changed – or when nobody was signed in.
  factory OfflineWriteSession.capture(Ref ref) {
    final userIdFn = ref.read(offlineQueueUserIdProvider);
    final sessionIdFn = ref.read(offlineQueueSessionIdProvider);
    final tenantId = ref.read(currentTenantIdProvider);
    final userId = userIdFn();
    final sessionId = sessionIdFn();
    return OfflineWriteSession._(
      userId: userId,
      tenantId: tenantId,
      isCurrent: () =>
          userId != null &&
          userIdFn() == userId &&
          sessionIdFn() == sessionId &&
          ref.read(currentTenantIdProvider) == tenantId,
    );
  }

  /// Signed-in user at capture time (null = signed out).
  final String? userId;

  /// Current tenant at capture time.
  final int? tenantId;
  final bool Function() _isCurrent;

  /// Whether the captured user, auth session and tenant are still active.
  bool isCurrent() {
    try {
      return _isCurrent();
    } catch (_) {
      return false;
    }
  }

  /// Throws [OfflineSessionChangedException] when the session changed.
  void ensureCurrent() {
    if (!isCurrent()) throw const OfflineSessionChangedException();
  }
}
