// SOL_FIX15: "Meine Stammdaten" writes run for the account that started
// them. An account switch A→B while the save awaits the organisation
// fields must never write A's master data into B's rows (nor propagate it
// to B's other instances).
import 'dart:io';
import 'dart:typed_data';

import 'package:attendix/core/config/supabase_config.dart';
import 'package:attendix/core/providers/profile_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/core/services/offline_queue_service.dart';
import 'package:attendix/data/models/person/person.dart';
import 'package:attendix/data/repositories/attendance_repository.dart'
    show OfflineSessionChangedException;
import 'package:attendix/data/repositories/base_repository.dart';
import 'package:attendix/data/repositories/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records the writes; [onSharedFields] runs while the save awaits the
/// organisation fields (where the account switch happens).
class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(super.ref, {this.onSharedFields});

  final void Function()? onSharedFields;
  final writes = <String>[];

  @override
  Future<void> updateSharedFieldValues(
    int organisationId,
    String personKey,
    Map<String, dynamic> values, {
    bool Function()? isSessionCurrent,
  }) async {
    await Future<void>.delayed(Duration.zero);
    onSharedFields?.call();
    if (isSessionCurrent != null && !isSessionCurrent()) {
      throw const OfflineSessionChangedException();
    }
    writes.add('shared:$personKey');
  }

  @override
  Future<void> updateOwnProfile({
    required String userId,
    required bool Function() isSessionCurrent,
    required Map<String, dynamic> personalData,
    Map<String, dynamic>? additionalFields,
    String? churchId,
  }) async {
    // The real repository checks right before its first write.
    await Future<void>.delayed(Duration.zero);
    if (!isSessionCurrent()) throw const OfflineSessionChangedException();
    writes.add('profile:$userId');
  }
}

OwnProfile _profile(String appId) => OwnProfile(
      person: Person(id: 1, firstName: 'A', lastName: 'A', appId: appId),
      organisationId: 3,
      globalPersonId: 'gp-$appId',
    );

void main() {
  group('ProfileNotifier.saveMasterData', () {
    late String? user;
    late ProviderContainer container;
    late _FakeProfileRepository repo;

    ProviderContainer build({void Function()? onSharedFields}) {
      user = 'user-a';
      return ProviderContainer(overrides: [
        currentTenantIdProvider.overrideWithValue(7),
        offlineQueueUserIdProvider.overrideWithValue(() => user),
        offlineQueueSessionIdProvider
            .overrideWithValue(() => user == null ? null : 'session-$user'),
        profileRepositoryWithTenantProvider.overrideWith((ref) {
          return repo =
              _FakeProfileRepository(ref, onSharedFields: onSharedFields)
                ..bindTenantId(7);
        }),
      ]);
    }

    Future<bool> save() =>
        container.read(profileNotifierProvider.notifier).saveMasterData(
              original: _profile('user-a'),
              firstName: 'Anna',
              lastName: 'A',
              phone: '',
              birthday: null,
              additionalFields: const {'org_field': 'x'},
              visibleFields: const [
                ProfileExtraField(
                  id: 'org_field',
                  name: 'Org',
                  type: 'text',
                  visibleToPlayers: true,
                  editableByPlayers: true,
                  isOrganisationField: true,
                ),
              ],
            );

    test('writes for the captured account', () async {
      container = build();
      addTearDown(container.dispose);
      expect(await save(), isTrue);
      expect(repo.writes, ['shared:global:gp-user-a', 'profile:user-a']);
    });

    test('an account switch while awaiting org fields aborts the save',
        () async {
      container = build(onSharedFields: () => user = 'user-b');
      addTearDown(container.dispose);
      expect(await save(), isFalse);
      expect(repo.writes, isEmpty);
      expect(repo.writes.where((w) => w.contains('user-b')), isEmpty);
    });

    test('a switch before the profile write never writes it as B',
        () async {
      container = build();
      addTearDown(container.dispose);
      final notifier = container.read(profileNotifierProvider.notifier);
      final future = notifier.saveMasterData(
        original: _profile('user-a'),
        firstName: 'Anna',
        lastName: 'A',
        phone: '',
        birthday: null,
        additionalFields: const {},
        visibleFields: const [],
      );
      user = 'user-b'; // switch before the first write
      expect(await future, isFalse);
      expect(repo.writes, isEmpty);
    });

    test("a form of another account's profile is never saved", () async {
      container = build();
      addTearDown(container.dispose);
      user = 'user-b';
      expect(await save(), isFalse);
      expect(repo.writes, isEmpty);
    });

    test('signed out → nothing is written', () async {
      container = build();
      addTearDown(container.dispose);
      user = null;
      expect(await save(), isFalse);
      expect(repo.writes, isEmpty);
    });
  });

  group('ProfileRepository session guard', () {
    late ProviderContainer container;
    late SupabaseClient client;

    setUp(() {
      // Unreachable host: a write that slipped through would fail with a
      // network error instead of OfflineSessionChangedException.
      client = SupabaseClient('http://localhost:1', 'anon-key');
      container = ProviderContainer(overrides: [
        supabaseClientProvider.overrideWithValue(client),
      ]);
    });

    tearDown(() async {
      container.dispose();
      await client.dispose();
    });

    ProfileRepository repo() => ProfileRepository(_RefProbe.of(container))
      ..bindTenantId(7);

    Future<void> expectSessionChanged(Future<void> Function() call) async {
      Object? error;
      try {
        await call();
      } catch (e) {
        error = e;
      }
      expect(error, isA<RepositoryException>());
      expect((error as RepositoryException).originalError,
          isA<OfflineSessionChangedException>());
    }

    test('updateOwnProfile checks the session before the first write',
        () async {
      await expectSessionChanged(() => repo().updateOwnProfile(
            userId: 'user-a',
            isSessionCurrent: () => false,
            personalData: const {'firstName': 'A'},
          ));
    });

    test('image writes check the session first', () async {
      await expectSessionChanged(() => repo().uploadOwnImage(
            userId: 'user-a',
            isSessionCurrent: () => false,
            playerId: 1,
            bytes: Uint8List(0),
          ));
      await expectSessionChanged(() => repo().removeOwnImage(
            'https://x/profiles/1',
            userId: 'user-a',
            isSessionCurrent: () => false,
          ));
    });
  });

  group('ProfileRepository source analysis', () {
    final src =
        File('lib/data/repositories/profile_repository.dart').readAsStringSync();

    String method(String signature) {
      final start = src.indexOf(signature);
      expect(start, isNot(-1), reason: signature);
      final next = src.indexOf('\n  Future<', start + signature.length);
      return src.substring(start, next == -1 ? src.length : next);
    }

    test('every own-profile write is preceded by a session check', () {
      final mutation = RegExp(
          r"await supabase(?:\s*\.from\('\w+'\)\s*\.(?:update|upsert)\(|\.storage\s*\.from\('profiles'\)\s*\.(?:uploadBinary|remove)\()");
      for (final sig in [
        'Future<void> updateOwnProfile(',
        'Future<void> _syncOwnPersonalData(',
        'Future<void> _syncOwnChurch(',
        'Future<String> uploadOwnImage(',
        'Future<void> removeOwnImage(',
        'Future<void> updateSharedFieldValues(',
      ]) {
        final body = method(sig);
        final writes = mutation.allMatches(body).toList();
        expect(writes, isNotEmpty, reason: sig);
        for (final w in writes) {
          final before = body.substring(0, w.start);
          final lastCheck = before.lastIndexOf('_ensureSession(');
          final lastAwait = before.lastIndexOf('await ');
          expect(lastCheck, greaterThan(lastAwait),
              reason: '$sig: write at ${w.start} without a session check '
                  'after the previous await');
        }
        // The account is captured by the caller, never re-read mid-flow.
        expect(body, isNot(contains('_userId')), reason: sig);
      }
    });
  });
}

/// Hands out a [Ref] of [container] for constructing repositories directly.
class _RefProbe {
  static Ref of(ProviderContainer container) =>
      container.read(_refProvider);
  static final _refProvider = Provider<Ref>((ref) => ref);
}
