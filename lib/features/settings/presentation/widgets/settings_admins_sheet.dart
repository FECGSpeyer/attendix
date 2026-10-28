import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../auth/data/auth_flow_service.dart';
import '../../../../l10n/l10n.dart';
import 'settings_list.dart'; // UX_SETTINGS (WAVE 8)
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// SETTINGS2: Ionic settings "Administratoren" modal (super admins only):
/// list with "Erstellt am", tap to remove, + to add an admin by e-mail.
Future<void> showAdminsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.9,
      child: _AdminsSheet(),
    ),
  );
}

String _errorText(Object e) =>
    e is AdminException ? e.message : friendlyErrorMessage(e);

class _AdminsSheet extends ConsumerWidget {
  const _AdminsSheet();

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final email = (await DialogHelper.showTextInput(
      context,
      title: context.l10n.settingsAddAdmin,
      hint: context.l10n.settingsEmailAddress,
      confirmText: context.l10n.attendanceAdd,
      keyboardType: TextInputType.emailAddress,
    ))
        ?.trim();
    if (email == null || email.isEmpty || !context.mounted) return;
    if (!isValidEmail(email)) {
      ToastHelper.showError(context, context.l10n.settingsFlutterInvalidEmail);
      return;
    }
    try {
      final informed =
          await ref.read(adminNotifierProvider.notifier).create(email);
      if (context.mounted) {
        if (informed) {
          ToastHelper.showSuccess(context, context.l10n.settingsAdminAdded);
        } else {
          ToastHelper.showWarning(context, context.l10n.settingsFlutterAdminAddedNotNotified);
        }
      }
    } catch (e) {
      if (context.mounted) ToastHelper.showError(context, _errorText(e));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, TenantAdmin admin) async {
    final ownId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (admin.userId == ownId) {
      ToastHelper.showError(context, context.l10n.settingsCannotRemoveSelf);
      return;
    }
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(ctx.l10n.settingsRemoveAdmin),
        content: Text(ctx.l10n.settingsRemoveMessage(admin.email ?? '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.commonYes),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(adminNotifierProvider.notifier).remove(admin.userId);
      if (context.mounted) {
        ToastHelper.showSuccess(context, context.l10n.settingsAdminRemoved);
      }
    } catch (e) {
      if (context.mounted) ToastHelper.showError(context, _errorText(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminsAsync = ref.watch(adminsProvider);
    final busy = ref.watch(adminNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsAdmins),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: busy ? null : () => _add(context, ref),
        child: busy
            ? const SizedBox(
                width: 20, height: 20, child: AppSpinner(strokeWidth: 2))
            : const Icon(Icons.add),
      ),
      // UX_SETTINGS (WAVE 8): Ionic admins modal — hint card with the
      // shield icon, then one inset list (h3 e-mail, p created-at).
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          SettingsHintCard(
            icon: Icons.verified_user_outlined,
            text: context.l10n.settingsAdminsHint,
          ),
          ...adminsAsync.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: AppSpinner()),
              ),
            ],
            error: (e, _) => [ListTile(title: Text(context.l10n.settingsFlutterErrorDetail(_errorText(e))))],
            data: (admins) => [
              SettingsListSection(
                icons: false,
                children: [
                  for (final a in admins)
                    ListTile(
                      title: Text(a.email ?? ''),
                      subtitle: a.createdAt != null
                          ? Text(context.l10n.commonCreatedAt(DateFormat(dateFmt()).format(a.createdAt!.toLocal())))
                          : null,
                      onTap: () => _remove(context, ref, a),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
