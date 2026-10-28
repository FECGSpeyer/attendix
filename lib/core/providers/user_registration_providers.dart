import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/person/person.dart';
import '../../data/repositories/user_registration_repository.dart';
import 'group_providers.dart';
import 'player_providers.dart';
import 'tenant_providers.dart';
import '../../l10n/l10n.dart';

/// AUTH: [UserRegistrationRepository] with tenant context.
final userRegistrationRepositoryWithTenantProvider = Provider<UserRegistrationRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(userRegistrationRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable [UserRegistrationRepository] per tenant (`bindTenantId`),
/// so a tenant switch never changes the tenant of a running flow and
/// cross-tenant work uses its own bound instance. `null` (no tenant)
/// yields an unbound instance with `hasTenantId == false`.
final userRegistrationRepositoryForTenantProvider =
    Provider.family<UserRegistrationRepository, int?>((ref, tenantId) {
  final repo = UserRegistrationRepository(ref);
  if (tenantId != null) repo.bindTenantId(tenantId);
  return repo;
});

/// Result of a batch account creation.
class AccountCreationResult {
  const AccountCreationResult({required this.created, required this.errors});

  final int created;

  /// "Vorname Nachname: Fehler" per failed person.
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
}

/// AUTH: account mutations (Ionic db.createAccount / settings createAccounts).
class AccountCreationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  UserRegistrationRepository get _repo =>
      ref.read(userRegistrationRepositoryWithTenantProvider);

  Future<int?> _mainGroupId() async {
    try {
      return (await ref.read(mainGroupProvider.future))?.id;
    } catch (_) {
      return null;
    }
  }

  /// Creates (or links) the account of one person. Throws
  /// [AccountFlowException] with a German message on failure.
  Future<String> createAccount(Person person) async {
    if (!_repo.hasTenantId) {
      throw AccountFlowException(l10nWithoutContext.coreFlutterNoInstanceSelected);
    }
    state = const AsyncValue.loading();
    try {
      final appId = await _repo.createPlayerAccount(
        person,
        mainGroupId: await _mainGroupId(),
      );
      state = const AsyncValue.data(null);
      _invalidate(person.id);
      return appId;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Creates accounts one after another; [onProgress] is called after each.
  /// Like Ionic, the person list is processed sequentially.
  Future<AccountCreationResult> createAccounts(
    List<Person> persons, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (!_repo.hasTenantId) {
      return AccountCreationResult(
          created: 0, errors: [l10nWithoutContext.coreFlutterNoInstanceSelected]);
    }
    state = const AsyncValue.loading();
    final mainGroupId = await _mainGroupId();
    var created = 0;
    final errors = <String>[];
    for (var i = 0; i < persons.length; i++) {
      final person = persons[i];
      try {
        await _repo.createPlayerAccount(person, mainGroupId: mainGroupId);
        created++;
      } catch (e) {
        errors.add('${person.firstName} ${person.lastName}: $e');
      }
      onProgress?.call(i + 1, persons.length);
    }
    state = const AsyncValue.data(null);
    ref.invalidate(playersProvider);
    return AccountCreationResult(created: created, errors: errors);
  }

  void _invalidate(int? personId) {
    ref.invalidate(playersProvider);
    if (personId != null) ref.invalidate(playerByIdProvider(personId));
  }
}

final accountCreationNotifierProvider =
    NotifierProvider<AccountCreationNotifier, AsyncValue<void>>(
  AccountCreationNotifier.new,
);
