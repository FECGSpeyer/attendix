// REDESIGN: pure logic of Verwaltung › Rollen und Rechte (thread "Rollen und
// Rechte neu aufziehen", Stufe A): the page is a list of roles, each role
// opens its own page. Same roles and rights as before, only sorted by role.

import '../../../core/constants/enums.dart';
import '../../../data/models/person/person.dart';
import '../../settings/presentation/pages/user_management_page.dart' show TenantUser;

/// What `RdRolePermissionsPage` shows: the list of roles or one role.
/// [key] is the path segment of `/ich/verwaltung/rollen/:role`.
enum RdRoleView {
  list(''),
  admin('admin'),
  responsible('verantwortliche'),
  helper('helfer'),
  leader('stimmfuehrer'),
  member('mitglied');

  const RdRoleView(this.key);
  final String key;

  /// The role page of a path segment; null for the list and unknown ones.
  static RdRoleView? fromKey(String? key) =>
      values.where((v) => v != list && v.key == key).firstOrNull;

  /// The account roles a page stands for. Stimmführer are a Zusatz: a
  /// Stimmführer-Helfer is a Helfer and a Stimmführer, a Stimmführer is a
  /// Mitglied and a Stimmführer.
  Set<Role> get roles => switch (this) {
        RdRoleView.list => const {},
        RdRoleView.admin => const {Role.admin},
        RdRoleView.responsible => const {Role.responsible},
        RdRoleView.helper => const {Role.helper, Role.voiceLeaderHelper},
        RdRoleView.leader => const {Role.voiceLeader, Role.voiceLeaderHelper},
        RdRoleView.member => const {Role.player, Role.voiceLeader},
      };

  /// Whether the page has switches (needs the stored rights).
  bool get hasSwitches =>
      this == RdRoleView.list || this == RdRoleView.helper || this == RdRoleView.leader || this == RdRoleView.member;
}

/// The accounts of [users] with a role of [view].
List<TenantUser> rdRoleAccounts(Iterable<TenantUser> users, RdRoleView view) {
  final roles = view.roles;
  return [
    for (final u in users)
      if (roles.contains(u.roleEnum)) u,
  ];
}

/// An account with a role and its person in the group (null when the
/// account has no person here, e.g. an admin from outside).
class RdRolePerson {
  const RdRolePerson(this.account, this.person);

  final TenantUser account;
  final Person? person;

  /// Name of the person, else the e-mail of the account.
  String get name {
    final full = person?.fullName.trim() ?? '';
    if (full.isNotEmpty) return full;
    final email = account.email?.trim() ?? '';
    return email.isEmpty ? '–' : email;
  }
}

/// [accounts] with their persons from [players] (matched by the account
/// id), persons first by last and first name, then accounts without one.
List<RdRolePerson> rdRolePeople(Iterable<TenantUser> accounts, Iterable<Person> players) {
  final byAccount = <String, Person>{
    for (final p in players)
      if ((p.appId ?? '').isNotEmpty) p.appId!: p,
  };
  final people = [for (final a in accounts) RdRolePerson(a, byAccount[a.userId])];
  String sortKey(RdRolePerson r) {
    final p = r.person;
    return p == null ? '1 ${r.name}' : '0 ${p.lastName} ${p.firstName}';
  }

  people.sort((a, b) => sortKey(a).toLowerCase().compareTo(sortKey(b).toLowerCase()));
  return people;
}
