import 'dart:async';

import 'package:attendix/core/services/teams/teams_sdk_stub.dart';
import 'package:attendix/core/services/teams/teams_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTeamsSdk implements TeamsSdk {
  FakeTeamsSdk({
    this.isFramed = true,
    this.loaded = true,
    this.initSucceeds = true,
    this.theme = 'default',
    this.token = 'aad-token',
  });

  @override
  final bool isFramed;
  final bool loaded;
  final bool initSucceeds;
  final String? theme;
  final String token;

  int notifySuccessCalls = 0;
  void Function(String)? themeHandler;
  TeamsTabConfig? Function()? saveBuilder;
  final validity = <bool>[];

  @override
  Future<bool> ensureLoaded() async => loaded;

  @override
  Future<void> initialize() =>
      initSucceeds ? Future.value() : Completer<void>().future; // hangs

  @override
  void notifySuccess() => notifySuccessCalls++;

  @override
  Future<String?> getTheme() async => theme;

  @override
  void onThemeChange(void Function(String theme) handler) =>
      themeHandler = handler;

  @override
  Future<String> getAuthToken() async => token;

  @override
  void registerConfigSaveHandler(
    TeamsTabConfig? Function() buildConfig,
    String failureMessage,
  ) =>
      saveBuilder = buildConfig;

  @override
  void setValidityState(bool valid) => validity.add(valid);
}

void main() {
  const fast = Duration(milliseconds: 20);

  TeamsService service(
    FakeTeamsSdk sdk, {
    List<Map<String, Object?>>? posted,
    TeamsSsoResponse response = const TeamsSsoResponse(),
    bool consumeOk = true,
    String? accessToken = 'supabase-jwt',
    List<String>? consumed,
  }) {
    return TeamsService(
      sdk: sdk,
      initTimeout: fast,
      loadTimeout: fast,
      postSso: (body) async {
        posted?.add(body);
        return response;
      },
      consumeTokenHash: (hash) async {
        consumed?.add(hash);
        return consumeOk;
      },
      accessToken: () => accessToken,
    );
  }

  group('TeamsService.init', () {
    test('not framed → not in Teams, SDK untouched', () async {
      final sdk = FakeTeamsSdk(isFramed: false);
      final svc = service(sdk);
      await svc.init();
      expect(svc.isInTeams(), isFalse);
      expect(sdk.notifySuccessCalls, 0);
    });

    test('framed but initialize hangs → timeout means not in Teams', () async {
      final svc = service(FakeTeamsSdk(initSucceeds: false));
      await svc.init();
      expect(svc.isInTeams(), isFalse);
    });

    test('SDK script failed to load → not in Teams', () async {
      final svc = service(FakeTeamsSdk(loaded: false));
      await svc.init();
      expect(svc.isInTeams(), isFalse);
    });

    test('in Teams → notifySuccess, theme wired, idempotent', () async {
      final sdk = FakeTeamsSdk(theme: 'dark');
      final svc = service(sdk);
      await svc.init();
      await svc.init();
      expect(svc.isInTeams(), isTrue);
      expect(sdk.notifySuccessCalls, 1);
      expect(svc.theme.value, 'dark');
      sdk.themeHandler!('contrast');
      expect(svc.theme.value, 'contrast');
    });

    test('no-op stub never detects Teams', () async {
      final svc = TeamsService(sdk: const NoopTeamsSdk());
      await svc.init();
      expect(svc.isInTeams(), isFalse);
      expect(await svc.ssoSignIn(), TeamsSsoResult.failed);
    });
  });

  test('themeModeFor maps Teams themes like Ionic body classes', () {
    expect(TeamsService.themeModeFor('dark'), ThemeMode.dark);
    expect(TeamsService.themeModeFor('contrast'), ThemeMode.dark);
    expect(TeamsService.themeModeFor('default'), isNull);
    expect(TeamsService.themeModeFor(null), isNull);
  });

  group('TeamsSsoResponse.fromJson', () {
    test('parses linked + token_hash', () {
      final r = TeamsSsoResponse.fromJson(
          {'linked': true, 'token_hash': 'abc'});
      expect(r.linked, isTrue);
      expect(r.tokenHash, 'abc');
      expect(r.error, isNull);
    });

    test('tolerates garbage', () {
      final r = TeamsSsoResponse.fromJson('oops');
      expect(r.linked, isNull);
      expect(r.tokenHash, isNull);
      expect(TeamsSsoResponse.fromJson({'token_hash': ''}).tokenHash, isNull);
    });
  });

  group('ssoSignIn', () {
    test('outside Teams → failed without calling the server', () async {
      final posted = <Map<String, Object?>>[];
      final svc = service(FakeTeamsSdk(isFramed: false), posted: posted);
      await svc.init();
      expect(await svc.ssoSignIn(), TeamsSsoResult.failed);
      expect(posted, isEmpty);
    });

    test('linked → consumes token hash → ok', () async {
      final posted = <Map<String, Object?>>[];
      final consumed = <String>[];
      final svc = service(
        FakeTeamsSdk(),
        posted: posted,
        consumed: consumed,
        response: const TeamsSsoResponse(linked: true, tokenHash: 'h1'),
      );
      await svc.init();
      expect(await svc.ssoSignIn(), TeamsSsoResult.ok);
      expect(posted.single, {'token': 'aad-token'});
      expect(consumed, ['h1']);
    });

    test('not linked → needsLink', () async {
      final svc = service(FakeTeamsSdk(),
          response: const TeamsSsoResponse(linked: false));
      await svc.init();
      expect(await svc.ssoSignIn(), TeamsSsoResult.needsLink);
    });

    test('verifyOtp failure → failed', () async {
      final svc = service(FakeTeamsSdk(),
          consumeOk: false,
          response: const TeamsSsoResponse(linked: true, tokenHash: 'h'));
      await svc.init();
      expect(await svc.ssoSignIn(), TeamsSsoResult.failed);
    });
  });

  group('ssoLink', () {
    test('signs in, posts link action with access token', () async {
      final posted = <Map<String, Object?>>[];
      var signedIn = false;
      final svc = service(FakeTeamsSdk(),
          posted: posted,
          response: const TeamsSsoResponse(linked: true, tokenHash: 'h'));
      await svc.init();
      final result = await svc.ssoLink(() async => signedIn = true);
      expect(signedIn, isTrue);
      expect(result.ok, isTrue);
      expect(posted.single, {
        'action': 'link',
        'token': 'aad-token',
        'access_token': 'supabase-jwt',
      });
    });

    test('server error message is returned', () async {
      final svc = service(FakeTeamsSdk(),
          response: const TeamsSsoResponse(
              linked: false, error: 'Bereits verknüpft'));
      await svc.init();
      final result = await svc.ssoLink(() async {});
      expect(result.ok, isFalse);
      expect(result.error, 'Bereits verknüpft');
    });

    test('sign-in failure propagates to the caller', () async {
      final svc = service(FakeTeamsSdk());
      await svc.init();
      expect(() => svc.ssoLink(() async => throw StateError('bad')),
          throwsStateError);
    });

    test('outside Teams → failure without signing in', () async {
      final svc = service(FakeTeamsSdk(isFramed: false));
      await svc.init();
      var signedIn = false;
      final result = await svc.ssoLink(() async => signedIn = true);
      expect(result.ok, isFalse);
      expect(signedIn, isFalse);
    });
  });

  group('trySsoSignIn', () {
    test('needsLink routes to login link mode', () async {
      final svc = service(FakeTeamsSdk(),
          response: const TeamsSsoResponse(linked: false));
      await svc.init();
      final visited = <String>[];
      final result =
          await trySsoSignIn(teams: svc, hasSession: false, go: visited.add);
      expect(result, TeamsSsoResult.needsLink);
      expect(visited, ['/login?teamsLink=1']);
    });

    test('existing session or outside Teams → nothing', () async {
      final inTeams = service(FakeTeamsSdk());
      await inTeams.init();
      expect(
          await trySsoSignIn(teams: inTeams, hasSession: true, go: (_) {}),
          isNull);
      final outside = service(FakeTeamsSdk(isFramed: false));
      await outside.init();
      expect(
          await trySsoSignIn(teams: outside, hasSession: false, go: (_) {}),
          isNull);
    });
  });

  group('links & tab config', () {
    test('attendance deep link matches Ionic format', () {
      expect(
        TeamsService.buildAttendanceDeepLink('app-1', 42, 7),
        'https://teams.microsoft.com/l/entity/app-1/attendix'
        '?webUrl=https%3A%2F%2Fattendix.de%2Fopen-attendance%3Fid%3D42%26tenantId%3D7'
        '&context=%7B%22subEntityId%22%3A%22att-42%22%7D',
      );
    });

    test('attendanceDeepLink is null outside Teams', () async {
      final svc = service(FakeTeamsSdk(isFramed: false));
      await svc.init();
      expect(svc.attendanceDeepLink('app', 1, 2), isNull);
    });

    test('tab config is scoped by tenant', () {
      expect(
        TeamsService.tabConfigFor(tenantId: 5, shortName: 'SO'),
        const TeamsTabConfig(
          entityId: 'attendix-tenant-5',
          contentUrl: 'https://attendix.de/open-attendance?tenantId=5',
          websiteUrl: 'https://attendix.de/open-attendance?tenantId=5',
          suggestedDisplayName: 'SO',
        ),
      );
      expect(
        TeamsService.tabConfigFor(tenantId: 5).suggestedDisplayName,
        'Attendix',
      );
    });
  });
}
