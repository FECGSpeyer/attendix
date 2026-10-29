import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart'
    show AccountScopeKey, currentAuthUserIdProvider;

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
///
/// SOL_FIX15: the instance also follows the signed-in account, so every
/// provider built on it reloads on an account switch (RLS results and
/// role-dependent data never outlive the account that loaded them).
final userRegistrationRepositoryForTenantProvider =
    Provider.family<UserRegistrationRepository, int?>((ref, tenantId) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(
      _userRegistrationRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _userRegistrationRepositoryForAccountProvider =
    Provider.family<UserRegistrationRepository, AccountScopeKey>((ref, key) {
  final repo = UserRegistrationRepository(ref);
  if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
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
  /// [stopOnError]: IOS_SETTINGS2 — Ionic settings `createAccounts()` stops
  /// at the first failure (the loop runs inside one try/catch).
  ///
  /// SOL_FIX13: [expectedTenantId] = tenant the caller's person list was
  /// loaded for (captured before its first await). When the repository is
  /// bound to another tenant (switch between loading the list and starting
  /// the job) nothing is registered. Persons whose tenantId is not the
  /// bound tenant are rejected before any side effect; the repository also
  /// verifies membership in the database before each registration.
  Future<AccountCreationResult> createAccounts(
    List<Person> persons, {
    void Function(int done, int total)? onProgress,
    bool stopOnError = false,
    int? expectedTenantId,
  }) async {
    // SOL_FIX3: bind repository + tenant once for the whole job.
    final repo = _boundRepo();
    if (!repo.hasTenantId) {
      return AccountCreationResult(
          created: 0, errors: [l10nWithoutContext.coreFlutterNoInstanceSelected]);
    }
    final boundTenantId = repo.currentTenantId;
    if (expectedTenantId != null && expectedTenantId != boundTenantId) {
      return AccountCreationResult(
          created: 0, errors: [l10nWithoutContext.coreFlutterRepoPersonsNotInTenant]);
    }
    state = const AsyncValue.loading();
    final mainGroupId = await _mainGroupId(repo);
    var created = 0;
    final errors = <String>[];
    for (var i = 0; i < persons.length; i++) {
      final person = persons[i];
      try {
        // SOL_FIX13: never register a person of another tenant here.
        if (person.tenantId != null && person.tenantId != boundTenantId) {
          throw AccountFlowException(
              l10nWithoutContext.coreFlutterRepoPersonsNotInTenant);
        }
        await repo.createPlayerAccount(person, mainGroupId: mainGroupId);
        created++;
      } catch (e) {
        errors.add('${person.firstName} ${person.lastName}: $e');
        if (stopOnError) break;
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
