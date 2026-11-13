import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/parent_providers.dart';
import 'package:attendix/core/providers/player_providers.dart';
import 'package:attendix/core/providers/user_registration_providers.dart';
import 'package:attendix/core/utils/handover_request.dart';
import 'package:attendix/data/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../factories/test_factories.dart';
import '../../helpers/test_helpers.dart';
import '../../mocks/repository_mocks.dart';

class _MockRegistration extends Mock implements UserRegistrationRepository {}

class _MockParents extends Mock implements ParentRepository {}

/// Handover as a request (Z6): who hands over without being a lead of the
/// target group only asks; the target's leads take the person in or decline.
void main() {
  const request = HandoverRequest(
    fromTenantId: 12,
    fromTenantName: 'Jugendorchester',
    fromPersonId: 345,
    keep: false,
    by: 'lead@example.org',
  );

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(TestFactories.createPerson(id: 1));
    registerFallbackValue(request);
    registerFallbackValue(Role.player);
  });

  test('marker: written, read back, removed; malformed counts as none', () {
    final fields = {'field1': 'x', kHandoverRequestKey: request.toJson()};
    final read = HandoverRequest.fromAdditionalFields(fields)!;
    expect(read.fromTenantId, 12);
    expect(read.fromPersonId, 345);
    expect(read.fromTenantName, 'Jugendorchester');
    expect(read.keep, isFalse);
    expect(withoutHandoverRequest(fields), {'field1': 'x'});
    expect(HandoverRequest.fromAdditionalFields({kHandoverRequestKey: 'x'}), isNull);
    expect(HandoverRequest.fromAdditionalFields({kHandoverRequestKey: {'fromTenantId': 1}}), isNull);
    // Wrong types never break the Freigaben pages.
    final odd = HandoverRequest.fromAdditionalFields({
      kHandoverRequestKey: {'fromTenantId': 1, 'fromPersonId': 2, 'fromTenantName': 5, 'by': {}},
    })!;
    expect((odd.fromTenantName, odd.by, odd.keep), ('', '', false));
    // Only a waiting person is a request.
    final approved = TestFactories.createPerson(id: 1).copyWith(additionalFields: fields);
    expect(handoverRequestOf(approved), isNull);
    expect(handoverRequestOf(approved.copyWith(pending: true)), isNotNull);
  });

  test('the answer only reaches a person the asking group itself offered, once', () {
    Map<String, dynamic> row(List<String> texts) => {
          'history': [for (final t in texts) {'text': t, 'type': 99}],
        };
    final stays = PlayerRepository.handoverAskedNote('Kammerchor', keep: true);
    final moves = PlayerRepository.handoverAskedNote('Kammerchor', keep: false);
    expect(PlayerRepository.openHandoverKeep(row([stays]), 'Kammerchor'), isTrue);
    expect(PlayerRepository.openHandoverKeep(row([stays, moves]), 'Kammerchor'), isFalse, reason: 'asked again');
    // A marker pointed at a person nobody asked for, or asked for elsewhere.
    expect(PlayerRepository.openHandoverKeep(row(const []), 'Kammerchor'), isNull);
    expect(
      PlayerRepository.openHandoverKeep(
        row([moves, PlayerRepository.handoverAskedNote('Jugendchor', keep: true)]),
        'Bigband',
      ),
      isNull,
    );
    // Renamed since: the only open request is meant.
    expect(PlayerRepository.openHandoverKeep(row([moves]), 'Kammerchor Speyer'), isFalse);
    // Answered: nothing is open any more.
    expect(
      PlayerRepository.openHandoverKeep(row([moves, 'Person wurde zu "Kammerchor" übertragen.']), 'Kammerchor'),
      isNull,
    );
    expect(
      PlayerRepository.openHandoverKeep(
        row([moves, 'Übergabe an "Kammerchor" wurde abgelehnt: Kein Platz']),
        'Kammerchor',
      ),
      isNull,
    );
  });

  test('only Admin and Verantwortliche of the target hand over directly', () {
    final tenants = [
      TestFactories.createTenant(id: 1).copyWith(role: Role.admin.value),
      TestFactories.createTenant(id: 2).copyWith(role: Role.responsible.value),
      TestFactories.createTenant(id: 3).copyWith(role: Role.helper.value),
    ];
    expect(handoverNeedsRequest(tenants: tenants, targetTenantId: 1), isFalse);
    expect(handoverNeedsRequest(tenants: tenants, targetTenantId: 2), isFalse);
    expect(handoverNeedsRequest(tenants: tenants, targetTenantId: 3), isTrue);
    expect(handoverNeedsRequest(tenants: tenants, targetTenantId: 9), isTrue, reason: 'no member there');
    expect(handoverNeedsRequest(tenants: null, targetTenantId: 1), isTrue, reason: 'roles unknown');
  });

  group('answering a request in the target group', () {
    late MockPlayerRepository players;
    late _MockRegistration registration;
    late ProviderContainer container;
    final waiting = TestFactories.createPerson(id: 77, tenantId: 42).copyWith(
      pending: true,
      email: 'anna@example.org',
      additionalFields: {'field1': 'x', kHandoverRequestKey: request.toJson()},
    );

    setUp(() {
      players = MockPlayerRepository();
      registration = _MockRegistration();
      when(() => registration.hasTenantId).thenReturn(true);
      when(() => players.approvePlayer(
            any(),
            extra: any(named: 'extra'),
            onApproved: any(named: 'onApproved'),
          )).thenAnswer((inv) async {
        await (inv.namedArguments[#onApproved] as Future<void> Function()?)?.call();
      });
      when(() => players.copyProfileImage(any(), any(), targetTenantId: any(named: 'targetTenantId')))
          .thenAnswer((_) async => null);
      when(() => players.completeHandoverAtSource(any(), targetTenantName: any(named: 'targetTenantName')))
          .thenAnswer((_) async {});
      when(() => players.deleteHandoverRequest(any())).thenAnswer((_) async {});
      when(() => players.noteDeclinedHandoverAtSource(
            any(),
            targetTenantName: any(named: 'targetTenantName'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async {});
      when(() => registration.registerUser(
            email: any(named: 'email'),
            name: any(named: 'name'),
            role: any(named: 'role'),
          )).thenAnswer((_) async => 'acc-new');
      container = createTestContainer(
        tenant: TestFactories.createTenant(id: 42, longName: 'Kammerchor'),
        overrides: [
          playerRepositoryWithTenantProvider.overrideWithValue(players),
          userRegistrationRepositoryWithTenantProvider.overrideWithValue(registration),
          parentRepositoryWithTenantProvider.overrideWithValue(_MockParents()),
        ],
      );
      addTearDown(container.dispose);
    });

    test('Aufnehmen: account only now, marker gone, the asking group is told', () async {
      await container.read(playerNotifierProvider.notifier).approvePlayer(waiting);

      verify(() => registration.registerUser(email: 'anna@example.org', name: waiting.firstName, role: Role.player))
          .called(1);
      final extra = verify(() => players.approvePlayer(
            waiting,
            extra: captureAny(named: 'extra'),
            onApproved: any(named: 'onApproved'),
          )).captured.single as Map<String, dynamic>;
      expect(extra['appId'], 'acc-new');
      expect(extra['additional_fields'], {'field1': 'x'});
      final told = verify(
        () => players.completeHandoverAtSource(captureAny(), targetTenantName: 'Kammerchor'),
      ).captured.single as HandoverRequest;
      expect((told.fromTenantId, told.fromPersonId, told.keep), (12, 345, false));
      // No approval mail on top of the "hinzugefügt" mail of registerUser.
      verifyNever(() => registration.informUserAboutApproval(any(), any(), any()));
    });

    test('Ablehnen: the waiting row goes, the reason reaches the asking group, nobody gets a mail', () async {
      await container.read(playerNotifierProvider.notifier).declinePlayer(waiting, 'Kein Platz');

      verify(() => players.deleteHandoverRequest(waiting)).called(1);
      verify(() => players.noteDeclinedHandoverAtSource(any(), targetTenantName: 'Kammerchor', reason: 'Kein Platz'))
          .called(1);
      verifyNever(() => players.declinePlayer(any(), any()));
      verifyNever(() => registration.informUserAboutReject(any(), any()));
    });
  });
}
