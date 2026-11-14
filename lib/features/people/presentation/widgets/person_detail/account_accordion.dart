import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/core/theme/app_icons.dart';
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
import '../../../../../shared/widgets/adaptive/adaptive.dart';

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
    this.onEmailTyped,
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

  /// Inline e-mail input (classic): every keystroke updates the draft
  /// through this callback; [onFieldChanged] (with the lookup in other
  /// instances) runs when the field loses focus.
  final void Function(String field, dynamic value)? onEmailTyped;

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
        // Ionic person.page.html: the e-mail `ion-item` with its button in
        // `slot="end"` – the search (no account yet) or the danger trash
        // that removes the account from the group.
        if (canEdit && person.appId == null && context.rdSkin == null)
          // PEO-01: Ionic `ion-input` in the item – typed inline; the
          // lookup in other instances runs on blur (Ionic onEmailBlur).
          IonInputRow(
            label: context.l10n.peopleEmail,
            value: draftEmail ?? person.email,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            onChanged: (v) {
              final t = v.trim();
              (onEmailTyped ?? onFieldChanged)
                  ?.call('email', t.isEmpty ? null : t);
            },
            onFocusLost: onEmailTyped == null
                ? null
                : (v) {
                    final t = v.trim();
                    if (t.isNotEmpty && t != (person.email ?? '')) {
                      onFieldChanged?.call('email', t);
                    }
                  },
            trailing: onSearchOtherInstance != null &&
                    ((draftEmail ?? person.email)?.trim().isNotEmpty ?? false)
                ? _ItemEndButton(
                    key: const Key('account-search-button'),
                    icon: AppIcons.search,
                    tooltip: context.l10n.personFlutterSearchOtherInstance,
                    color: AppColors.primary,
                    onPressed: onSearchOtherInstance,
                  )
                : null,
          )
        else
        IonFieldRow(
          icon: AppIcons.email,
          label: context.l10n.peopleEmail,
          value: (draftEmail ?? person.email) ?? context.l10n.personFlutterNotSpecified,
          editable: canEdit && person.appId == null,
          onTap: person.email != null
              ? () => _launchEmail(person.email!)
              : null,
          onEdit: () => _editEmail(context),
          trailing: !canEdit
              ? null
              : person.appId != null
                  ? _ItemEndButton(
                      key: const Key('account-unlink-button'),
                      icon: AppIcons.delete,
                      tooltip: context.l10n.personFlutterUnlinkAccount,
                      color: AppColors.danger,
                      onPressed: onUnlinkAccount,
                    )
                  : onSearchOtherInstance != null &&
                          ((draftEmail ?? person.email)?.trim().isNotEmpty ?? false)
                      ? _ItemEndButton(
                          key: const Key('account-search-button'),
                          icon: AppIcons.search,
                          tooltip: context.l10n.personFlutterSearchOtherInstance,
                          color: AppColors.primary,
                          onPressed: onSearchOtherInstance,
                        )
                      : null,
        ),

        // Ionic: `ion-select [label]="Rolle"` item (label start, value end).
        if (person.appId != null) _buildRoleSelector(context, tenant?.id),

        // Create account button for persons with email but no account
        if (person.appId == null && person.email != null) ...[
          const SizedBox(height: AppDimensions.paddingM),
          if (canEdit)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
              child: FilledButton.icon(
                onPressed: onCreateAccount,
                icon: Icon(AppIcons.personAdd),
                label: IonButtonLabel(context.l10n.personFlutterCreateAccount),
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
                  Icon(AppIcons.infoOutline, color: AppColors.primary, size: 20),
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
              icon: Icon(AppIcons.helpOutline, size: 18),
              label: IonButtonLabel(context.l10n.personHelp),
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
                Icon(AppIcons.infoOutline, color: AppColors.warning),
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

    final enabled = canEdit && !isMainGroup;
    final ios = ionIsIos(context);
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: IonItem(
        onTap: !enabled
            ? null
            : () async {
                // Ionic `ion-select` without `interface`: the radio alert.
                final picked = await showAppRadioAlert<Role>(
                  context,
                  title: context.l10n.personRole,
                  options: [
                    for (final role in availableRoles)
                      (role, _getRoleLabel(context.l10n, role)),
                  ],
                  initialValue: currentRole,
                  confirmText: context.l10n.commonOk,
                );
                final role = picked?.value;
                if (role != null && role != currentRole) onRoleChanged(role);
              },
        end: [
          Text(
            _getRoleLabel(context.l10n, currentRole),
            style: TextStyle(
              fontSize: ios ? 17 : 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (ios)
            const IonSelectIcon()
          else
            Icon(AppIcons.arrowDropDown, color: theme.hintColor),
        ],
        child: Text(
          context.l10n.personRole,
          style: TextStyle(
            fontSize: ios ? 17 : 16,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  /// Ionic accountHelpModal: sheet modal (breakpoint 0.5) with toolbar
  /// "Hilfe" and a close button.
  void _showHelp(BuildContext context) {
    if (context.rdSkin == null) {
      // [breakpoints]="[0, 0.5, 1]" [initialBreakpoint]="0.5"; ion-title +
      // close ✕ (end), padded text.
      showIonSheet<void>(
        context,
        breakpoints: const [0, 0.5, 1],
        initialBreakpoint: 0.5,
        builder: (ctx, controller) => IonSheetScaffold(
          title: ctx.l10n.personHelp,
          showClose: true,
          body: ListView(
            controller: controller,
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            children: [
              if (person.appId == null) ...[
                Text(ctx.l10n.personAccountHelp),
                const SizedBox(height: AppDimensions.paddingM),
              ],
              Text(ctx.l10n.personExistingUserHint),
            ],
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(ctx).height * 0.5,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingM,
            AppDimensions.paddingS,
            AppDimensions.paddingM,
            AppDimensions.paddingL,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      ctx.l10n.personHelp,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: Icon(AppIcons.close, semanticLabel: ctx.l10n.commonClose),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingM),
              if (person.appId == null) ...[
                Text(ctx.l10n.personAccountHelp),
                const SizedBox(height: AppDimensions.paddingM),
              ],
              Text(ctx.l10n.personExistingUserHint),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    try {
      // No canLaunchUrl pre-check: without LSApplicationQueriesSchemes /
      // <queries> it reports false for mailto: on iOS and Android 11+.
      await launchUrl(Uri.parse('mailto:$email'));
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
}

/// Ionic `ion-button slot="end"` inside an `ion-item`: a small solid
/// button with one icon (e.g. the danger trash next to the e-mail).
class _ItemEndButton extends StatelessWidget {
  const _ItemEndButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tooltip,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            minimumSize: const Size(44, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Icon(icon, size: 20, semanticLabel: tooltip),
        ),
      ),
    );
  }
}
