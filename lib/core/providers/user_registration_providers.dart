import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/person/person.dart';
import '../../data/repositories/user_registration_repository.dart';
import 'player_providers.dart';
import 'tenant_providers.dart';
import '../../l10n/l10n.dart';

/// AUTH: [UserRegistrationRepository] with tenant context.
///
/// SOL_FIX3: per-tenant bound instance (see
/// [userRegistrationRepositoryForTenantProvider]); a captured instance keeps
/// its tenant even when the user switches tenants mid-flow.
final userRegistrationRepositoryWithTenantProvider =
    Provider<UserRegistrationRepository>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  return ref.watch(userRegistrationRepositoryForTenantProvider(tenantId));
});

/// SOL_FIX3: one immutable [UserRegistrationRepository] per tenant.
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

  /// SOL_FIX3: repository bound to the tenant that is current when a job
  /// starts. Callers read it ONCE (before the first await) and use that
  /// instance for the whole job, so a tenant switch A→B never registers the
  /// remaining persons of A in B.
  UserRegistrationRepository _boundRepo() =>
      ref.read(userRegistrationRepositoryWithTenantProvider);

  /// Main group of the bound repository's tenant (null on error).
  Future<int?> _mainGroupId(UserRegistrationRepository repo) async {
    try {
      return await repo.getMainGroupId();
    } catch (_) {
      return null;
    }
  }

  /// Creates (or links) the account of one person. Throws
  /// [AccountFlowException] with a German message on failure.
  Future<String> createAccount(Person person) async {
    final repo = _boundRepo();
    if (!repo.hasTenantId) {
      throw AccountFlowException(l10nWithoutContext.coreFlutterNoInstanceSelected);
    }
    state = const AsyncValue.loading();
    try {
      final appId = await repo.createPlayerAccount(
        person,
        mainGroupId: await _mainGroupId(repo),
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
    // SOL_FIX3: bind repository + tenant once for the whole job.
    final repo = _boundRepo();
    if (!repo.hasTenantId) {
      return AccountCreationResult(
          created: 0, errors: [l10nWithoutContext.coreFlutterNoInstanceSelected]);
    }
    state = const AsyncValue.loading();
    final mainGroupId = await _mainGroupId(repo);
    var created = 0;
    final errors = <String>[];
    for (var i = 0; i < persons.length; i++) {
      final person = persons[i];
      try {
        await repo.createPlayerAccount(person, mainGroupId: mainGroupId);
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
