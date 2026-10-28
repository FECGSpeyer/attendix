import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/person/person.dart';
import '../../../../../shared/widgets/editable/editable_info_row.dart';
import '../../../../../shared/widgets/sheets/field_editor_sheet.dart';

/// Accordion section displaying account information.
class AccountAccordion extends ConsumerWidget {
  const AccountAccordion({
    super.key,
    required this.person,
    required this.isExpanded,
    required this.onToggle,
    required this.userRole,
    required this.isLoadingRole,
    required this.onRoleChanged,
    required this.onUnlinkAccount,
    required this.onCreateAccount,
    required this.canEdit,
    this.onFieldChanged,
    this.draftEmail,
    this.isLeader = false,
    this.isMainGroup = false,
    this.onSearchOtherInstance,
  });

  final Person person;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Role? userRole;
  final bool isLoadingRole;
  final ValueChanged<Role> onRoleChanged;
  final VoidCallback onUnlinkAccount;
  final VoidCallback onCreateAccount;
  final bool canEdit;
  final void Function(String field, dynamic value)? onFieldChanged;

  /// Unsaved email value (shown instead of the stored one)
  final String? draftEmail;

  /// Draft "Stimmführer" flag — enables voice leader roles (Ionic)
  final bool isLeader;

  /// Person is in the main group → role is managed automatically (Ionic)
  final bool isMainGroup;

  /// Ionic searchPerson(): link to the same person in a linked tenant
  final VoidCallback? onSearchOtherInstance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only hide if person has no email, no appId, and user can't edit
    if (person.email == null && person.appId == null && !canEdit) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Account',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: onToggle,
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM,
                0,
                AppDimensions.paddingM,
                AppDimensions.paddingM,
              ),
              child: _buildContent(context, ref),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(currentTenantProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email
        EditableInfoRow(
          icon: Icons.email,
          label: 'E-Mail',
          value: (draftEmail ?? person.email) ?? 'Nicht angegeben',
          editable: canEdit && person.appId == null,
          onTap: person.email != null
              ? () => _launchEmail(person.email!)
              : null,
          onEdit: () => _editEmail(context),
        ),
        if (canEdit &&
            person.appId == null &&
            onSearchOtherInstance != null &&
            ((draftEmail ?? person.email)?.trim().isNotEmpty ?? false))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onSearchOtherInstance,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('In anderer Instanz suchen'),
            ),
          ),

        // Account linked status
        if (person.appId != null) ...[
          const InfoRow(
            icon: Icons.badge,
            label: 'Account',
            value: 'Verknüpft',
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Role selector
          _buildRoleSelector(context, tenant?.id),
          const SizedBox(height: AppDimensions.paddingM),

          // Unlink button
          if (canEdit)
            OutlinedButton.icon(
              onPressed: onUnlinkAccount,
              icon: const Icon(Icons.link_off, color: AppColors.danger),
              label: const Text('Account-Verknüpfung aufheben'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            ),
        ],

        // Create account button for persons with email but no account
        if (person.appId == null && person.email != null) ...[
          const SizedBox(height: AppDimensions.paddingM),
          if (canEdit)
            FilledButton.icon(
              onPressed: onCreateAccount,
              icon: const Icon(Icons.person_add),
              label: const Text('Account erstellen'),
            ),
          if (!canEdit)
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  SizedBox(width: AppDimensions.paddingS),
                  Expanded(
                    child: Text(
                      'Kein Account verknüpft. Ein Dirigent kann einen Account erstellen.',
                      style: TextStyle(fontSize: 13, color: AppColors.dark),
                    ),
                  ),
                ],
              ),
            ),
        ],

        if (person.appId == null && person.email == null)
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning),
                SizedBox(width: AppDimensions.paddingS),
                Expanded(
                  child: Text(
                    'Um einen Account zu erstellen, muss eine E-Mail-Adresse hinterlegt werden.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRoleSelector(BuildContext context, int? tenantId) {
    if (person.appId == null || tenantId == null) {
      return const SizedBox.shrink();
    }

    if (isLoadingRole) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentRole = userRole ?? Role.player;

    // Ionic person.page: Mitglied, Verantwortlicher, Helfer and — for
    // Stimmführer — the voice leader roles. A role outside this list
    // (e.g. Admin) stays visible but is not selectable from here.
    final availableRoles = <Role>[
      Role.player,
      Role.responsible,
      Role.helper,
      if (isLeader) Role.voiceLeaderHelper,
      if (isLeader) Role.voiceLeader,
    ];
    if (!availableRoles.contains(currentRole)) {
      availableRoles.add(currentRole);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rolle',
          style: TextStyle(fontSize: 12, color: AppColors.medium),
        ),
        const SizedBox(height: AppDimensions.paddingXS),
        DropdownButtonFormField<Role>(
          value: currentRole,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
              vertical: AppDimensions.paddingS,
            ),
          ),
          items: availableRoles.map((role) {
            return DropdownMenuItem(
              value: role,
              child: Row(
                children: [
                  Icon(_getRoleIcon(role), size: 20, color: AppColors.primary),
                  const SizedBox(width: AppDimensions.paddingS),
                  Text(_getRoleLabel(role)),
                ],
              ),
            );
          }).toList(),
          onChanged: canEdit && !isMainGroup
              ? (newRole) {
                  if (newRole != null && newRole != currentRole) {
                    onRoleChanged(newRole);
                  }
                }
              : null,
        ),
      ],
    );
  }

  Future<void> _launchEmail(String email) async {
    try {
      final uri = Uri.parse('mailto:$email');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      // PWA may not support mailto: links
    }
  }

  Future<void> _editEmail(BuildContext context) async {
    final result = await FieldEditorSheet.show(
      context,
      title: 'E-Mail',
      initialValue: person.email ?? '',
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value != null && value.trim().isNotEmpty && !value.contains('@')) {
          return 'Bitte gültige E-Mail eingeben';
        }
        return null;
      },
    );
    if (result != null) {
      onFieldChanged?.call('email', result.isEmpty ? null : result);
    }
  }

  String _getRoleLabel(Role role) {
    return switch (role) {
      Role.admin => 'Dirigent (Admin)',
      Role.responsible => 'Verantwortlicher',
      Role.helper => 'Helfer',
      Role.viewer => 'Beobachter',
      Role.player => 'Mitglied',
      Role.voiceLeader => 'Stimmführer',
      Role.voiceLeaderHelper => 'Stimmführer-Helfer',
      Role.parent => 'Eltern',
      Role.applicant => 'Bewerber',
      Role.none => 'Keine Rolle',
    };
  }

  IconData _getRoleIcon(Role role) {
    return switch (role) {
      Role.admin => Icons.admin_panel_settings,
      Role.responsible => Icons.manage_accounts,
      Role.helper => Icons.handshake,
      Role.viewer => Icons.visibility,
      Role.player => Icons.person,
      Role.voiceLeader => Icons.record_voice_over,
      Role.voiceLeaderHelper => Icons.support_agent,
      Role.parent => Icons.family_restroom,
      Role.applicant => Icons.pending,
      Role.none => Icons.person_off,
    };
  }
}
