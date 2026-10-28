import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/providers/tenant_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/person/person.dart';
import '../ion/ion_widgets.dart';
import '../../../../../shared/widgets/sheets/field_editor_sheet.dart';
import '../../../../../l10n/l10n.dart';
import '../../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

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

    return IonAccordion(
      title: context.l10n.personAccount,
      expanded: isExpanded,
      onToggle: onToggle,
      // UX_PEOPLE: ion-items span the full width, other content is inset.
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
        child: _buildContent(context, ref),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(currentTenantProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email
        IonFieldRow(
          icon: Icons.email,
          label: context.l10n.peopleEmail,
          value: (draftEmail ?? person.email) ?? context.l10n.personFlutterNotSpecified,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS),
            child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onSearchOtherInstance,
              icon: const Icon(Icons.search, size: 18),
              label: Text(context.l10n.personFlutterSearchOtherInstance),
            ),
          ),
          ),

        // Account linked status
        if (person.appId != null) ...[
          IonFieldRow(
            icon: Icons.badge,
            label: context.l10n.personAccount,
            value: context.l10n.personFlutterLinked,
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Role selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
            child: _buildRoleSelector(context, tenant?.id),
          ),
          const SizedBox(height: AppDimensions.paddingM),

          // Unlink button
          if (canEdit)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
              child: OutlinedButton.icon(
                onPressed: onUnlinkAccount,
                icon: const Icon(Icons.link_off, color: AppColors.danger),
                label: Text(context.l10n.personFlutterUnlinkAccount),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              ),
            ),
        ],

        // Create account button for persons with email but no account
        if (person.appId == null && person.email != null) ...[
          const SizedBox(height: AppDimensions.paddingM),
          if (canEdit)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
              child: FilledButton.icon(
                onPressed: onCreateAccount,
                icon: const Icon(Icons.person_add),
                label: Text(context.l10n.personFlutterCreateAccount),
              ),
            ),
          if (!canEdit)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: AppDimensions.paddingS),
                  Expanded(
                    child: Text(
                      context.l10n.personFlutterNoAccountLinked,
                      style: const TextStyle(fontSize: 13, color: AppColors.dark),
                    ),
                  ),
                ],
              ),
            ),
        ],

        // PEOPLE2: Ionic account help (person.accountHelp / existingUserHint)
        if (canEdit)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS),
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showHelp(context),
              icon: const Icon(Icons.help_outline, size: 18),
              label: Text(context.l10n.personHelp),
            ),
          ),

        if (person.appId == null && person.email == null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.warning),
                const SizedBox(width: AppDimensions.paddingS),
                Expanded(
                  child: Text(
                    context.l10n.personFlutterEmailRequiredForAccount,
                    style: const TextStyle(fontSize: 13),
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
      return const Center(child: AppSpinner());
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
        Text(
          context.l10n.personRole,
          style: const TextStyle(fontSize: 12, color: AppColors.medium),
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
                  Text(_getRoleLabel(context.l10n, role)),
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

  void _showHelp(BuildContext context) {
    showAppDialog<void>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.personHelp),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (person.appId == null) ...[
              Text(context.l10n.personAccountHelp),
              const SizedBox(height: AppDimensions.paddingM),
            ],
            Text(context.l10n.personExistingUserHint),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
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
      title: context.l10n.peopleEmail,
      initialValue: person.email ?? '',
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value != null && value.trim().isNotEmpty && !value.contains('@')) {
          return context.l10n.personInvalidEmail;
        }
        return null;
      },
    );
    if (result != null) {
      onFieldChanged?.call('email', result.isEmpty ? null : result);
    }
  }

  String _getRoleLabel(AppLocalizations l10n, Role role) {
    return switch (role) {
      Role.admin => l10n.personFlutterRoleAdmin,
      Role.responsible => l10n.commonRolesResponsible,
      Role.helper => l10n.commonRolesHelper,
      Role.viewer => l10n.commonRolesViewer,
      Role.player => l10n.commonRolesMember,
      Role.voiceLeader => l10n.rolesVoiceLeader,
      Role.voiceLeaderHelper => l10n.commonRolesVoiceLeaderHelper,
      Role.parent => l10n.rolesParents,
      Role.applicant => l10n.rolesApplicant,
      Role.none => l10n.personFlutterRoleNone,
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
