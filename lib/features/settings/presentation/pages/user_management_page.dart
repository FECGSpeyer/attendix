import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/user_registration_providers.dart'; // AUTH
import '../../../../data/repositories/user_registration_repository.dart'; // AUTH
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';

/// TenantUser model
class TenantUser {
  final String id;
  final int tenantId;
  final String userId;
  final int role;
  final int? personId;
  final String? email;

  const TenantUser({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.role,
    this.personId,
    this.email,
  });

  factory TenantUser.fromJson(Map<String, dynamic> json) {
    return TenantUser(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenantId'] ?? json['tenant_id'] ?? 0,
      userId: json['userId'] ?? json['user_id'] ?? '',
      role: json['role'] ?? 99,
      personId: json['personId'] ?? json['person_id'],
      email: json['email'],
    );
  }

  Role get roleEnum => Role.fromValue(role);
}

/// Provider for tenant users
final tenantUsersProvider = FutureProvider<List<TenantUser>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final tenantId = ref.watch(currentTenantIdProvider);

  if (tenantId == null) return [];

  // Get tenant users
  final response = await supabase
      .from('tenantUsers')
      .select('*')
      .eq('tenantId', tenantId)
      .order('role', ascending: true);

  final users = (response as List).map((e) => TenantUser.fromJson(e)).toList();

  // Load emails from player table for users with personId (Issue #8)
  final personIds = users
      .where((u) => u.personId != null)
      .map((u) => u.personId!)
      .toSet()
      .toList();

  if (personIds.isEmpty) return users;

  final playerResponse = await supabase
      .from('player')
      .select('id, email')
      .eq('tenantId', tenantId)
      .inFilter('id', personIds);

  final emailMap = <int, String?>{};
  for (final p in playerResponse as List) {
    emailMap[p['id'] as int] = p['email'] as String?;
  }

  return users.map((u) {
    if (u.personId != null && emailMap.containsKey(u.personId)) {
      return TenantUser(
        id: u.id,
        tenantId: u.tenantId,
        userId: u.userId,
        role: u.role,
        personId: u.personId,
        email: emailMap[u.personId],
      );
    }
    return u;
  }).toList();
});

/// User Management Page
class UserManagementPage extends ConsumerWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(currentTenantProvider);
    final showParents = tenant?.parents ?? false;

    return DefaultTabController(
      length: showParents ? 4 : 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Benutzerverwaltung'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'Admins'),
              const Tab(text: 'Betrachter'),
              if (showParents) const Tab(text: 'Eltern'),
              const Tab(text: 'Alle Benutzer'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AdminsTab(),
            _ViewersTab(),
            if (showParents) _ParentsTab(),
            const _AllUsersTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddUserDialog(context, ref),
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }

  Future<void> _showAddUserDialog(BuildContext context, WidgetRef ref) async {
    final tenant = ref.read(currentTenantProvider);
    final showParents = tenant?.parents ?? false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddUserDialog(showParents: showParents),
    );

    if (result != null && context.mounted) {
      await _addUser(context, ref, result['email'], Role.fromValue(result['role']));
    }
  }

  Future<void> _addUser(BuildContext context, WidgetRef ref, String email, Role role) async {
    final registration = ref.read(userRegistrationRepositoryWithTenantProvider);
    if (!registration.hasTenantId) return;

    try {
      // AUTH: Ionic createAdmin → registerUser: links an existing account (and
      // informs it) or creates a new account server-side via the
      // attendix-user Edge Function, which sends the "set password" mail.
      await registration.registerUser(
        email: email.toLowerCase().trim(),
        name: '',
        role: role,
      );

      ref.invalidate(tenantUsersProvider);

      if (context.mounted) {
        ToastHelper.showSuccess(context, 'Benutzer hinzugefügt');
      }
    } on AccountFlowException catch (e) {
      if (context.mounted) ToastHelper.showError(context, e.message);
    } catch (e) {
      // SEC-020: Don't expose internal error details to user
      debugPrint('Error adding user: $e');
      if (context.mounted) {
        ToastHelper.showError(context, 'Fehler beim Hinzufügen des Benutzers');
      }
    }
  }
}

/// Dialog for adding a new user
class _AddUserDialog extends StatefulWidget {
  final bool showParents;

  const _AddUserDialog({required this.showParents});

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _emailController = TextEditingController();
  Role _selectedRole = Role.viewer;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Benutzer hinzufügen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'E-Mail-Adresse',
              hintText: 'email@beispiel.de',
            ),
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          DropdownButtonFormField<Role>(
            value: _selectedRole,
            decoration: const InputDecoration(labelText: 'Rolle'),
            items: [
              const DropdownMenuItem(value: Role.admin, child: Text('Administrator')),
              const DropdownMenuItem(value: Role.responsible, child: Text('Verantwortlich')),
              const DropdownMenuItem(value: Role.viewer, child: Text('Betrachter')),
              if (widget.showParents)
                const DropdownMenuItem(value: Role.parent, child: Text('Elternteil')),
            ],
            onChanged: (role) {
              if (role != null) setState(() => _selectedRole = role);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () {
            final email = _emailController.text.trim();
            if (email.isEmpty || !email.contains('@')) {
              ToastHelper.showError(context, 'Bitte gültige E-Mail eingeben');
              return;
            }
            Navigator.of(context).pop({
              'email': email,
              'role': _selectedRole.value,
            });
          },
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }
}

/// Tab showing admins only
class _AdminsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(tenantUsersProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Fehler: $error')),
      data: (users) {
        final admins = users.where((u) => u.roleEnum == Role.admin).toList();

        if (admins.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.admin_panel_settings, size: 64, color: AppColors.medium),
                SizedBox(height: 16),
                Text('Keine Administratoren'),
                SizedBox(height: 8),
                Text(
                  'Füge Admins über den + Button hinzu',
                  style: TextStyle(color: AppColors.medium, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          // FN-005: await provider.future to show spinner until data loads
          onRefresh: () async {
            ref.invalidate(tenantUsersProvider);
            await ref.read(tenantUsersProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            itemCount: admins.length,
            itemBuilder: (context, index) => _UserTile(user: admins[index]),
          ),
        );
      },
    );
  }
}

/// Tab showing viewers only
class _ViewersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(tenantUsersProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Fehler: $error')),
      data: (users) {
        final viewers = users.where((u) => u.roleEnum == Role.viewer).toList();

        if (viewers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility, size: 64, color: AppColors.medium),
                SizedBox(height: 16),
                Text('Keine Betrachter'),
                SizedBox(height: 8),
                Text(
                  'Betrachter können Anwesenheit sehen, aber nicht bearbeiten',
                  style: TextStyle(color: AppColors.medium, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          // FN-005: await provider.future to show spinner until data loads
          onRefresh: () async {
            ref.invalidate(tenantUsersProvider);
            await ref.read(tenantUsersProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            itemCount: viewers.length,
            itemBuilder: (context, index) => _UserTile(user: viewers[index]),
          ),
        );
      },
    );
  }
}

/// Tab showing parents only
class _ParentsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(tenantUsersProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Fehler: $error')),
      data: (users) {
        final parents = users.where((u) => u.roleEnum == Role.parent).toList();

        if (parents.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.family_restroom, size: 64, color: AppColors.medium),
                SizedBox(height: 16),
                Text('Keine Eltern'),
                SizedBox(height: 8),
                Text(
                  'Eltern können ihre Kinder an-/abmelden',
                  style: TextStyle(color: AppColors.medium, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          // FN-005: await provider.future to show spinner until data loads
          onRefresh: () async {
            ref.invalidate(tenantUsersProvider);
            await ref.read(tenantUsersProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            itemCount: parents.length,
            itemBuilder: (context, index) => _UserTile(user: parents[index]),
          ),
        );
      },
    );
  }
}

/// Tab showing all tenant users
class _AllUsersTab extends ConsumerWidget {
  const _AllUsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(tenantUsersProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Fehler: $error')),
      data: (users) {
        if (users.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: AppColors.medium),
                SizedBox(height: 16),
                Text('Keine Benutzer vorhanden'),
              ],
            ),
          );
        }

        // Group by role
        final admins = users.where((u) => u.roleEnum == Role.admin).toList();
        final responsibles = users.where((u) => u.roleEnum == Role.responsible).toList();
        final players = users.where((u) => u.roleEnum == Role.player).toList();
        final viewers = users.where((u) => u.roleEnum == Role.viewer).toList();
        final others = users.where((u) =>
          ![Role.admin, Role.responsible, Role.player, Role.viewer].contains(u.roleEnum)
        ).toList();

        return RefreshIndicator(
          // FN-005: await provider.future to show spinner until data loads
          onRefresh: () async {
            ref.invalidate(tenantUsersProvider);
            await ref.read(tenantUsersProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            children: [
              if (admins.isNotEmpty) ...[
                _buildRoleSection(context, ref, 'Administratoren', admins, Icons.admin_panel_settings),
              ],
              if (responsibles.isNotEmpty) ...[
                _buildRoleSection(context, ref, 'Verantwortliche', responsibles, Icons.supervisor_account),
              ],
              if (players.isNotEmpty) ...[
                _buildRoleSection(context, ref, 'Spieler', players, Icons.person),
              ],
              if (viewers.isNotEmpty) ...[
                _buildRoleSection(context, ref, 'Betrachter', viewers, Icons.visibility),
              ],
              if (others.isNotEmpty) ...[
                _buildRoleSection(context, ref, 'Sonstige', others, Icons.person_outline),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<TenantUser> users,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.medium),
              const SizedBox(width: 8),
              Text(
                '$title (${users.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.medium,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
          child: Column(
            children: users.map((user) => _UserTile(user: user)).toList(),
          ),
        ),
      ],
    );
  }
}

class _UserTile extends ConsumerWidget {
  final TenantUser user;

  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getRoleColor(user.roleEnum).withAlpha(30),
        child: Icon(
          _getRoleIcon(user.roleEnum),
          color: _getRoleColor(user.roleEnum),
          size: 20,
        ),
      ),
      title: Text(user.email ?? 'Unbekannt'),
      subtitle: Text(_getRoleLabel(user.roleEnum)),
      trailing: PopupMenuButton<Role>(
        onSelected: (role) => _changeRole(context, ref, role),
        itemBuilder: (context) {
          // Only show assignable roles (Issue #12)
          // Exclude: none, applicant, player, helper, voiceLeader, voiceLeaderHelper
          const assignableRoles = [
            Role.admin,
            Role.responsible,
            Role.viewer,
            Role.parent,
          ];
          final tenant = ref.read(currentTenantProvider);
          final showParent = tenant?.parents ?? false;

          return assignableRoles
              .where((r) => r != Role.parent || showParent)
              .map((role) => PopupMenuItem(
                    value: role,
                    child: Text(_getRoleLabel(role)),
                  ))
              .toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getRoleColor(user.roleEnum).withAlpha(20),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getRoleLabel(user.roleEnum),
                style: TextStyle(
                  color: _getRoleColor(user.roleEnum),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                color: _getRoleColor(user.roleEnum),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeRole(BuildContext context, WidgetRef ref, Role newRole) async {
    if (newRole.value == user.role) return;

    final supabase = ref.read(supabaseClientProvider);
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return;

    // Get current user ID for self-demotion check
    final currentUserId = supabase.auth.currentUser?.id;
    final isCurrentUser = user.userId == currentUserId;
    final isDemotion = user.roleEnum == Role.admin && newRole != Role.admin;

    // Check admin count for last-admin protection
    if (isDemotion) {
      final tenantUsers = ref.read(tenantUsersProvider).valueOrNull ?? [];
      final adminCount = tenantUsers.where((u) => u.roleEnum == Role.admin).length;
      final isLastAdmin = adminCount <= 1;

      // Block if this is the last admin (Issue #3)
      if (isLastAdmin) {
        if (context.mounted) {
          ToastHelper.showError(
            context,
            'Der letzte Administrator kann nicht herabgestuft werden. '
            'Bitte füge zuerst einen weiteren Admin hinzu.',
          );
        }
        return;
      }

      // Warn on self-demotion (Issue #2)
      if (isCurrentUser) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eigene Rolle ändern?'),
            content: const Text(
              'Du bist dabei, deine eigene Admin-Rolle zu entfernen. '
              'Du verlierst dadurch den Zugang zur Benutzerverwaltung. '
              'Möchtest du fortfahren?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Ja, Rolle ändern'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
      }
    }

    try {
      await supabase
          .from('tenantUsers')
          .update({'role': newRole.value})
          .eq('id', user.id)
          .eq('tenantId', tenantId);

      ref.invalidate(tenantUsersProvider);

      if (context.mounted) {
        ToastHelper.showSuccess(context, 'Rolle geändert zu ${_getRoleLabel(newRole)}');
      }
    } catch (e) {
      // SEC-020: Don't expose internal error details to user
      debugPrint('Error changing role: $e');
      if (context.mounted) {
        ToastHelper.showError(context, 'Fehler beim Ändern der Rolle');
      }
    }
  }

  Color _getRoleColor(Role role) {
    return switch (role) {
      Role.admin => Colors.red,
      Role.responsible => Colors.orange,
      Role.player => AppColors.primary,
      Role.viewer => Colors.grey,
      Role.helper => Colors.green,
      Role.parent => Colors.purple,
      _ => AppColors.medium,
    };
  }

  IconData _getRoleIcon(Role role) {
    return switch (role) {
      Role.admin => Icons.admin_panel_settings,
      Role.responsible => Icons.supervisor_account,
      Role.player => Icons.person,
      Role.viewer => Icons.visibility,
      Role.helper => Icons.handshake,
      Role.parent => Icons.family_restroom,
      _ => Icons.person_outline,
    };
  }

  String _getRoleLabel(Role role) {
    return switch (role) {
      Role.admin => 'Administrator',
      Role.responsible => 'Verantwortlich',
      Role.player => 'Spieler',
      Role.viewer => 'Betrachter',
      Role.helper => 'Helfer',
      Role.parent => 'Elternteil',
      Role.applicant => 'Bewerber',
      Role.voiceLeader => 'Stimmführer',
      Role.voiceLeaderHelper => 'Stimmführer & Helfer',
      Role.none => 'Keine Rolle',
    };
  }
}
