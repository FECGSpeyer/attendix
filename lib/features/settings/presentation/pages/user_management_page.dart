import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/parent_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/providers/viewer_providers.dart';
import '../../../../data/models/parent/parent_model.dart';
import '../../../../data/models/viewer/viewer.dart';
import '../../../../core/providers/user_registration_providers.dart'; // AUTH
import '../../../../data/repositories/user_registration_repository.dart'; // AUTH
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';

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
          title: Text(context.l10n.settingsFlutterUserMgmtTitle),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: context.l10n.settingsFlutterUserMgmtTabAdmins),
              Tab(text: context.l10n.settingsViewers),
              if (showParents) Tab(text: context.l10n.settingsParents),
              Tab(text: context.l10n.settingsFlutterUserMgmtTabAll),
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
      await _addUser(
        context,
        ref,
        result['email'] as String,
        Role.fromValue(result['role'] as int),
        firstName: result['firstName'] as String? ?? '',
        lastName: result['lastName'] as String? ?? '',
      );
    }
  }

  Future<void> _addUser(
    BuildContext context,
    WidgetRef ref,
    String email,
    Role role, {
    String firstName = '',
    String lastName = '',
  }) async {
    final registration = ref.read(userRegistrationRepositoryWithTenantProvider);
    if (!registration.hasTenantId) return;

    try {
      // AUTH: Ionic createAdmin → registerUser: links an existing account (and
      // informs it) or creates a new account server-side via the
      // attendix-user Edge Function, which sends the "set password" mail.
      final normalizedEmail = email.toLowerCase().trim();
      final appId = await registration.registerUser(
        email: normalizedEmail,
        name: role == Role.viewer || role == Role.parent ? firstName : '',
        role: role,
      );

      // LOGIC_PEOPLE: Ionic db.createViewer / createParent also insert the
      // `viewers` / `parents` row (first + last name) and, for parents, set
      // tenantUsers.parent_id so the parents portal works.
      if (role == Role.viewer) {
        final created = await ref.read(viewerNotifierProvider.notifier).createViewer(
              Viewer(
                appId: appId,
                email: normalizedEmail,
                firstName: firstName,
                lastName: lastName,
              ),
            );
        if (created == null) {
          throw AccountFlowException(l10nWithoutContext.dbAddViewerFailed);
        }
      } else if (role == Role.parent) {
        final created = await ref.read(parentNotifierProvider.notifier).createParent(
              ParentModel(
                appId: appId,
                email: normalizedEmail,
                firstName: firstName,
                lastName: lastName,
              ),
            );
        if (created?.id == null) {
          throw AccountFlowException(l10nWithoutContext.dbAddParentFailed);
        }
        await registration.linkParentToTenantUser(appId, created!.id!);
      }

      ref.invalidate(tenantUsersProvider);

      if (context.mounted) {
        ToastHelper.showSuccess(context, context.l10n.settingsFlutterUserMgmtAdded);
      }
    } on AccountFlowException catch (e) {
      if (context.mounted) ToastHelper.showError(context, e.message);
    } catch (e) {
      // SEC-020: Don't expose internal error details to user
      debugPrint('Error adding user: $e');
      if (context.mounted) {
        ToastHelper.showError(context, context.l10n.settingsFlutterUserMgmtAddFailed);
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
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  Role _selectedRole = Role.viewer;

  bool get _needsName =>
      _selectedRole == Role.viewer || _selectedRole == Role.parent;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.settingsFlutterUserMgmtAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: context.l10n.settingsEmailAddress,
              hintText: context.l10n.settingsFlutterUserMgmtEmailPh,
            ),
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          DropdownButtonFormField<Role>(
            value: _selectedRole,
            decoration: InputDecoration(labelText: context.l10n.personRole),
            items: [
              DropdownMenuItem(value: Role.admin, child: Text(context.l10n.rolesAdministrator)),
              DropdownMenuItem(value: Role.responsible, child: Text(context.l10n.commonRolesResponsible)),
              DropdownMenuItem(value: Role.viewer, child: Text(context.l10n.commonRolesViewer)),
              if (widget.showParents)
                DropdownMenuItem(value: Role.parent, child: Text(context.l10n.commonRolesParent)),
            ],
            onChanged: (role) {
              if (role != null) setState(() => _selectedRole = role);
            },
          ),
          // LOGIC_PEOPLE: viewers / parents need a name (Ionic createViewer /
          // createParent insert firstName + lastName).
          if (_needsName) ...[
            const SizedBox(height: AppDimensions.paddingM),
            TextField(
              controller: _firstNameController,
              decoration: InputDecoration(labelText: context.l10n.peopleFirstName),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppDimensions.paddingS),
            TextField(
              controller: _lastNameController,
              decoration: InputDecoration(labelText: context.l10n.peopleLastName),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: () {
            final email = _emailController.text.trim();
            if (email.isEmpty || !email.contains('@')) {
              ToastHelper.showError(context, context.l10n.loginToastInvalidEmail);
              return;
            }
            final firstName = _firstNameController.text.trim();
            final lastName = _lastNameController.text.trim();
            if (_needsName && (firstName.isEmpty || lastName.isEmpty)) {
              ToastHelper.showError(context, context.l10n.personEnterNames);
              return;
            }
            Navigator.of(context).pop({
              'email': email,
              'role': _selectedRole.value,
              if (_needsName) 'firstName': firstName,
              if (_needsName) 'lastName': lastName,
            });
          },
          child: Text(context.l10n.attendanceAdd),
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
      error: (error, _) => Center(child: Text(context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(error)))),
      data: (users) {
        final admins = users.where((u) => u.roleEnum == Role.admin).toList();

        if (admins.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.admin_panel_settings, size: 64, color: AppColors.medium),
                SizedBox(height: 16),
                Text(context.l10n.settingsFlutterUserMgmtNoAdmins),
                SizedBox(height: 8),
                Text(
                  context.l10n.settingsFlutterUserMgmtNoAdminsHint,
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
      error: (error, _) => Center(child: Text(context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(error)))),
      data: (users) {
        final viewers = users.where((u) => u.roleEnum == Role.viewer).toList();

        if (viewers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility, size: 64, color: AppColors.medium),
                SizedBox(height: 16),
                Text(context.l10n.settingsFlutterUserMgmtNoViewers),
                SizedBox(height: 8),
                Text(
                  context.l10n.settingsFlutterUserMgmtNoViewersHint,
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
      error: (error, _) => Center(child: Text(context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(error)))),
      data: (users) {
        final parents = users.where((u) => u.roleEnum == Role.parent).toList();

        if (parents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.family_restroom, size: 64, color: AppColors.medium),
                SizedBox(height: 16),
                Text(context.l10n.settingsFlutterUserMgmtNoParents),
                SizedBox(height: 8),
                Text(
                  context.l10n.settingsFlutterUserMgmtNoParentsHint,
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
      error: (error, _) => Center(child: Text(context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(error)))),
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: AppColors.medium),
                SizedBox(height: 16),
                Text(context.l10n.settingsFlutterUserMgmtNoUsers),
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
                _buildRoleSection(context, ref, context.l10n.settingsAdmins, admins, Icons.admin_panel_settings),
              ],
              if (responsibles.isNotEmpty) ...[
                _buildRoleSection(context, ref, context.l10n.settingsFlutterUserMgmtResponsibles, responsibles, Icons.supervisor_account),
              ],
              if (players.isNotEmpty) ...[
                _buildRoleSection(context, ref, context.l10n.settingsFlutterUserMgmtPlayers, players, Icons.person),
              ],
              if (viewers.isNotEmpty) ...[
                _buildRoleSection(context, ref, context.l10n.settingsViewers, viewers, Icons.visibility),
              ],
              if (others.isNotEmpty) ...[
                _buildRoleSection(context, ref, context.l10n.commonOtherPlural, others, Icons.person_outline),
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
      title: Text(user.email ?? context.l10n.commonUnknown),
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
            context.l10n.settingsFlutterUserMgmtLastAdmin,
          );
        }
        return;
      }

      // Warn on self-demotion (Issue #2)
      if (isCurrentUser) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.settingsFlutterUserMgmtSelfDemoteTitle),
            content: Text(
              context.l10n.settingsFlutterUserMgmtSelfDemoteMessage,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(context.l10n.commonCancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(context.l10n.settingsFlutterUserMgmtSelfDemoteConfirm),
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
        ToastHelper.showSuccess(context, context.l10n.settingsFlutterUserMgmtRoleChanged(_getRoleLabel(newRole)));
      }
    } catch (e) {
      // SEC-020: Don't expose internal error details to user
      debugPrint('Error changing role: $e');
      if (context.mounted) {
        ToastHelper.showError(context, context.l10n.settingsFlutterUserMgmtRoleChangeFailed);
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
    final l10n = l10nWithoutContext;
    return switch (role) {
      Role.admin => l10n.rolesAdministrator,
      Role.responsible => l10n.commonRolesResponsible,
      Role.player => l10n.commonRolesMember,
      Role.viewer => l10n.commonRolesViewer,
      Role.helper => l10n.commonRolesHelper,
      Role.parent => l10n.commonRolesParent,
      Role.applicant => l10n.rolesApplicant,
      Role.voiceLeader => l10n.commonRolesVoiceLeader,
      Role.voiceLeaderHelper => l10n.commonRolesVoiceLeaderHelper,
      Role.none => l10n.settingsFlutterUserMgmtNoRole,
    };
  }
}
