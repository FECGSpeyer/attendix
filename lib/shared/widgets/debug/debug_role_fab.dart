import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../core/providers/debug_providers.dart';
import '../../../core/providers/tenant_providers.dart';

/// Debug FAB for quickly switching roles during development
/// Only visible in debug mode (kDebugMode == true)
class DebugRoleFab extends ConsumerWidget {
  const DebugRoleFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Don't render anything in release mode
    if (kReleaseMode) return const SizedBox.shrink();

    final currentOverride = ref.watch(debugRoleOverrideProvider);
    final realRole = ref.watch(currentRoleProvider);
    final hasOverride = currentOverride != null;

    return FloatingActionButton.small(
      heroTag: 'debug_role_fab',
      backgroundColor: hasOverride ? Colors.orange : Colors.grey.shade600,
      onPressed: () => _showRolePicker(context, ref, realRole, currentOverride),
      child: Icon(
        hasOverride ? Icons.bug_report : Icons.bug_report_outlined,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  void _showRolePicker(
    BuildContext context,
    WidgetRef ref,
    Role realRole,
    Role? currentOverride,
  ) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      builder: (context) => _RolePickerSheet(
        realRole: realRole,
        currentOverride: currentOverride,
        onRoleSelected: (role) {
          ref.read(debugRoleOverrideProvider.notifier).state = role;
          Navigator.pop(context);
        },
        onReset: () {
          ref.read(debugRoleOverrideProvider.notifier).state = null;
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _RolePickerSheet extends StatelessWidget {
  const _RolePickerSheet({
    required this.realRole,
    required this.currentOverride,
    required this.onRoleSelected,
    required this.onReset,
  });

  final Role realRole;
  final Role? currentOverride;
  final ValueChanged<Role> onRoleSelected;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final effectiveRole = currentOverride ?? realRole;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.bug_report,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DEBUG: Role Override',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Echte Rolle: ${_getRoleName(realRole)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),

            // Role list
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final role in _testableRoles)
                      RadioListTile<Role>(
                        title: Text(_getRoleName(role)),
                        subtitle: Text(
                          _getRoleDescription(role),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        value: role,
                        groupValue: effectiveRole,
                        onChanged: (value) {
                          if (value != null) {
                            onRoleSelected(value);
                          }
                        },
                        secondary: Icon(
                          _getRoleIcon(role),
                          color: role == effectiveRole
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Reset button
            if (currentOverride != null) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Zurücksetzen zur echten Rolle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _testableRoles = [
    Role.admin,
    Role.player,
    Role.viewer,
    Role.helper,
    Role.responsible,
    Role.parent,
    Role.applicant,
    Role.voiceLeader,
    Role.voiceLeaderHelper,
  ];

  String _getRoleName(Role role) {
    return switch (role) {
      Role.admin => 'Admin',
      Role.player => 'Player',
      Role.viewer => 'Viewer',
      Role.helper => 'Helper',
      Role.responsible => 'Responsible',
      Role.parent => 'Parent',
      Role.applicant => 'Applicant',
      Role.voiceLeader => 'VoiceLeader',
      Role.voiceLeaderHelper => 'VoiceLeaderHelper',
      Role.none => 'None',
    };
  }

  String _getRoleDescription(Role role) {
    return switch (role) {
      Role.admin => 'Voller Zugriff, People Tab',
      Role.player => 'Self-Service Tab',
      Role.viewer => 'People Tab (nur lesen)',
      Role.helper => 'Attendance Tab',
      Role.responsible => 'People Tab (wie Admin)',
      Role.parent => 'Parents Portal Tab',
      Role.applicant => 'Eingeschränkt (Wartebereich)',
      Role.voiceLeader => 'Self-Service + VL Settings',
      Role.voiceLeaderHelper => 'Attendance + VL Settings',
      Role.none => 'Kein Zugriff',
    };
  }

  IconData _getRoleIcon(Role role) {
    return switch (role) {
      Role.admin => Icons.admin_panel_settings,
      Role.player => Icons.person,
      Role.viewer => Icons.visibility,
      Role.helper => Icons.handshake,
      Role.responsible => Icons.supervisor_account,
      Role.parent => Icons.family_restroom,
      Role.applicant => Icons.hourglass_empty,
      Role.voiceLeader => Icons.record_voice_over,
      Role.voiceLeaderHelper => Icons.support_agent,
      Role.none => Icons.block,
    };
  }
}
