import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import 'teams_sdk.dart';

export 'teams_sdk.dart' show TeamsTabConfig;

/// Result of an attempted silent Teams sign-in (Ionic `SsoResult`).
enum TeamsSsoResult {
  /// Signed in silently.
  ok,

  /// Verified Microsoft user, but no linked Attendix account yet.
  needsLink,

  /// Not in Teams, token/SDK error, or server error.
  failed,
}

/// Response of the `teams-sso` edge function.
@immutable
class TeamsSsoResponse {
  const TeamsSsoResponse({this.linked, this.tokenHash, this.error});

  /// Parses the JSON body (`{ linked, token_hash, error }`).
  factory TeamsSsoResponse.fromJson(Object? json) {
    if (json is! Map) return const TeamsSsoResponse();
    final linked = json['linked'];
    final tokenHash = json['token_hash'];
    final error = json['error'];
    return TeamsSsoResponse(
      linked: linked is bool ? linked : null,
      tokenHash: tokenHash is String && tokenHash.isNotEmpty ? tokenHash : null,
      error: error is String && error.isNotEmpty ? error : null,
    );
  }

  final bool? linked;
  final String? tokenHash;
  final String? error;
}

/// Outcome of the one-time account linking.
@immutable
class TeamsLinkResult {
  const TeamsLinkResult.success() : ok = true, error = null;
  const TeamsLinkResult.failure([this.error]) : ok = false;

  final bool ok;

  /// Server message (e.g. 409 "already linked elsewhere"), if any.
  final String? error;
}

typedef TeamsSsoPoster = Future<TeamsSsoResponse> Function(
    Map<String, Object?> body);
typedef TeamsTokenHashConsumer = Future<bool> Function(String tokenHash);
typedef TeamsAccessTokenGetter = String? Function();

/// TEAMS: Microsoft Teams tab integration (Ionic `TeamsService`).
///
/// Attendix runs inside Teams as a tab (an iframe with the live web app).
/// [init] tries `app.initialize()`; if it succeeds within a short timeout we
/// are in Teams. Outside an iframe (browser, PWA, native) nothing is loaded
/// and every method is a no-op.
class TeamsService {
  TeamsService({
    required TeamsSdk sdk,
    TeamsSsoPoster? postSso,
    TeamsTokenHashConsumer? consumeTokenHash,
    TeamsAccessTokenGetter? accessToken,
    this.initTimeout = const Duration(seconds: 2),
    this.loadTimeout = const Duration(seconds: 8),
  })  : _sdk = sdk,
        _postSso = postSso ?? _defaultPostSso,
        _consumeTokenHash = consumeTokenHash ?? _defaultConsumeTokenHash,
        _accessToken = accessToken ?? _defaultAccessToken;

  /// App-wide instance (initialised in `main()` before `runApp`).
  static final TeamsService instance = TeamsService(sdk: createTeamsSdk());

  /// Public web origin used in tab content URLs and deep links (Ionic
  /// hard-codes the same host).
  static const String webOrigin = 'https://attendix.de';

  final TeamsSdk _sdk;
  final TeamsSsoPoster _postSso;
  final TeamsTokenHashConsumer _consumeTokenHash;
  final TeamsAccessTokenGetter _accessToken;
  final Duration initTimeout;
  final Duration loadTimeout;

  bool _inTeams = false;
  Future<void>? _init;

  /// Current Teams theme ('default' | 'dark' | 'contrast'), null outside Teams.
  final ValueNotifier<String?> theme = ValueNotifier<String?>(null);

  TeamsSdk get sdk => _sdk;

  bool isInTeams() => _inTeams;

  /// Idempotent. Completes once we know whether we run inside Teams. Never
  /// throws: outside Teams `app.initialize()` hangs, so it is raced against
  /// [initTimeout] and a timeout means "not in Teams".
  Future<void> init() => _init ??= _doInit();

  Future<void> _doInit() async {
    try {
      if (!_sdk.isFramed) return;
      final loaded = await _sdk.ensureLoaded().timeout(
            loadTimeout,
            onTimeout: () => false,
          );
      if (!loaded) return;
      await _sdk.initialize().timeout(initTimeout);
      _inTeams = true;
      // Tell Teams the tab loaded so it stops the loading spinner.
      _sdk.notifySuccess();

      // Follow the Teams in-app theme (it does not change the OS
      // prefers-color-scheme, so the app would not react on its own).
      try {
        theme.value = await _sdk.getTheme();
        _sdk.onThemeChange((t) => theme.value = t);
      } catch (e) {
        debugPrint('[teams] theme wiring failed: $e');
      }
    } catch (_) {
      // Not running inside Teams (or the SDK could not reach the host).
      _inTeams = false;
    }
  }

  /// Maps a Teams theme to the app theme mode. 'dark' and 'contrast' force
  /// dark; 'default' keeps following the system (Ionic only adds a dark body
  /// class and otherwise falls back to prefers-color-scheme).
  static ThemeMode? themeModeFor(String? teamsTheme) {
    switch (teamsTheme) {
      case 'dark':
      case 'contrast':
        return ThemeMode.dark;
      default:
        return null;
    }
  }

  /// Silent Microsoft SSO sign-in inside Teams (Ionic `ssoSignIn`).
  ///
  /// Gets an Entra token, exchanges it via the `teams-sso` edge function and –
  /// if this Microsoft identity is already linked – establishes the Supabase
  /// session with the returned magic-link token hash.
  Future<TeamsSsoResult> ssoSignIn() async {
    if (!_inTeams) return TeamsSsoResult.failed;
    try {
      final token = await _sdk.getAuthToken();
      final res = await _postSso({'token': token});
      if (res.linked == true && res.tokenHash != null) {
        return await _consumeTokenHash(res.tokenHash!)
            ? TeamsSsoResult.ok
            : TeamsSsoResult.failed;
      }
      return res.linked == false
          ? TeamsSsoResult.needsLink
          : TeamsSsoResult.failed;
    } catch (e) {
      debugPrint('[teams] ssoSignIn failed: $e');
      return TeamsSsoResult.failed;
    }
  }

  /// One-time account linking (Ionic `ssoLink`). [signIn] proves ownership
  /// of the Attendix account (email + password); its exceptions propagate so
  /// the login page can show its usual error handling. Afterwards the
  /// Microsoft identity is bound server-side so future launches sign in
  /// silently.
  Future<TeamsLinkResult> ssoLink(Future<void> Function() signIn) async {
    if (!_inTeams) return const TeamsLinkResult.failure();
    await signIn();
    try {
      final accessToken = _accessToken();
      if (accessToken == null) return const TeamsLinkResult.failure();
      final token = await _sdk.getAuthToken();
      final res = await _postSso({
        'action': 'link',
        'token': token,
        'access_token': accessToken,
      });
      if (res.linked == true && res.tokenHash != null) {
        // Settle on the freshly minted session so state is consistent.
        return await _consumeTokenHash(res.tokenHash!)
            ? const TeamsLinkResult.success()
            : const TeamsLinkResult.failure();
      }
      return TeamsLinkResult.failure(res.error);
    } catch (e) {
      debugPrint('[teams] ssoLink failed: $e');
      return const TeamsLinkResult.failure();
    }
  }

  /// Shareable Teams deep link opening the Attendix personal tab at an
  /// attendance. Null when not in Teams so callers fall back to a web link.
  String? attendanceDeepLink(String appId, int attendanceId, int tenantId) {
    if (!_inTeams) return null;
    return buildAttendanceDeepLink(appId, attendanceId, tenantId);
  }

  /// Teams deep-link format:
  /// `https://teams.microsoft.com/l/entity/<appId>/<entityId>?webUrl=<url>&context=<ctx>`.
  static String buildAttendanceDeepLink(
      String appId, int attendanceId, int tenantId) {
    final webUrl = Uri.encodeComponent(
      '$webOrigin/open-attendance?id=$attendanceId&tenantId=$tenantId',
    );
    final context =
        Uri.encodeComponent('{"subEntityId":"att-$attendanceId"}');
    return 'https://teams.microsoft.com/l/entity/$appId/attendix'
        '?webUrl=$webUrl&context=$context';
  }

  /// Channel-tab configuration for a tenant (Ionic TeamsConfigPage save
  /// handler). The content page `/open-attendance?tenantId=` switches to it.
  static TeamsTabConfig tabConfigFor({
    required int tenantId,
    String? shortName,
  }) {
    final contentUrl = '$webOrigin/open-attendance?tenantId=$tenantId';
    return TeamsTabConfig(
      entityId: 'attendix-tenant-$tenantId',
      contentUrl: contentUrl,
      websiteUrl: contentUrl,
      suggestedDisplayName:
          shortName != null && shortName.isNotEmpty ? shortName : 'Attendix',
    );
  }

  // --- defaults (Supabase) ----------------------------------------------------

  static Future<TeamsSsoResponse> _defaultPostSso(
      Map<String, Object?> body) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'teams-sso',
        body: body,
        // Like Ionic: call with the anon key, the user is identified by the
        // Entra token (and access_token for linking) in the body.
        headers: {
          'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        },
      );
      return TeamsSsoResponse.fromJson(res.data);
    } on FunctionException catch (e) {
      // 409 (already linked elsewhere) / 401 (bad token) carry a message.
      // REVIEW_FIX2: "not linked yet" is a 200 `{linked: false}` from the
      // function; any non-2xx is an error, so `linked` stays null → sign-in
      // reports `failed` (no link prompt), linking surfaces the message.
      return toErrorResponse(e.status, e.details);
    }
  }

  /// Maps a non-2xx `teams-sso` response (status + JSON body) to a response
  /// that never means "needs link".
  @visibleForTesting
  static TeamsSsoResponse toErrorResponse(int status, Object? details) {
    final parsed = TeamsSsoResponse.fromJson(details);
    // status is unused for the mapping itself (any non-2xx is an error);
    // a missing message makes callers show their own fallback text.
    return TeamsSsoResponse(error: parsed.error);
  }

  static Future<bool> _defaultConsumeTokenHash(String tokenHash) async {
    try {
      await Supabase.instance.client.auth.verifyOTP(
        tokenHash: tokenHash,
        type: OtpType.magiclink,
      );
      return true;
    } catch (e) {
      debugPrint('[teams] verifyOtp failed: $e');
      return false;
    }
  }

  static String? _defaultAccessToken() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }
}

/// TEAMS: the app-wide [TeamsService].
final teamsServiceProvider =
    Provider<TeamsService>((ref) => TeamsService.instance);

/// TEAMS: completes once Teams detection finished. `main()` starts
/// [TeamsService.init] without awaiting it (REVIEW_FIX2: no blank start
/// screen while a non-Teams frame times out), so dependants watch this.
final teamsInitProvider = FutureProvider<void>(
  (ref) => ref.watch(teamsServiceProvider).init(),
);

/// TEAMS: true when the app runs inside a Microsoft Teams tab. False until
/// detection finished, then rebuilt with the real value.
final isInTeamsProvider = Provider<bool>((ref) {
  ref.watch(teamsInitProvider);
  return ref.watch(teamsServiceProvider).isInTeams();
});

/// TEAMS: theme forced by the Teams client (null = follow system).
final teamsThemeModeProvider = Provider<ThemeMode?>((ref) {
  final notifier = ref.watch(teamsServiceProvider).theme;
  void listener() => ref.invalidateSelf();
  notifier.addListener(listener);
  ref.onDispose(() => notifier.removeListener(listener));
  return TeamsService.themeModeFor(notifier.value);
});

/// TEAMS: silent SSO at app start (Ionic `AppComponent.trySsoSignIn`).
///
/// Inside Teams without a session: sign in silently; if the Microsoft user is
/// not linked yet, open the login page in one-time link mode. A successful
/// sign-in is routed by the router's auth redirect. Returns the result for
/// tests/logging; null when nothing was attempted.
Future<TeamsSsoResult?> trySsoSignIn({
  required TeamsService teams,
  required bool hasSession,
  required void Function(String location) go,
}) async {
  if (!teams.isInTeams() || hasSession) return null;
  final result = await teams.ssoSignIn();
  if (result == TeamsSsoResult.needsLink) {
    go('/login?teamsLink=1');
  }
  // failed → stay on the normal login form; ok → auth redirect takes over.
  return result;
}
