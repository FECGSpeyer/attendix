import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../data/repositories/user_registration_repository.dart'
    show AccountFlowException;
import '../../../../core/providers/parent_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/settings_list.dart'; // UX_SETTINGS
import '../widgets/settings_sheet.dart'; // IOS_SETTINGS2
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/parent/parent_model.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Parents Page - manage parents of players
/// IOS_SETTINGS2: Ionic settings "parents-button" opens the "Eltern" sheet
/// (`[breakpoints]="[0, 1]"`, initial 1, toolbar with the title only).
Future<void> showParentsSheet(BuildContext context) => showSettingsSheet<void>(
      context,
      builder: (_) => const ParentsPage(sheet: true),
    );

class ParentsPage extends ConsumerWidget {
  const ParentsPage({super.key, this.sheet = false});

  /// Presented as the Ionic sheet (no back button) instead of a route.
  final bool sheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentsAsync = ref.watch(parentsProvider);

    return Scaffold(
      appBar: sheet
          ? settingsSheetBar(context, title: context.l10n.settingsParents)
          : AppBar(
              title: Text(context.l10n.settingsParents),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, semanticLabel: context.l10n.commonBack),
                onPressed: () => context.pop(),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddParentDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: parentsAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text(context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e))),
              const SizedBox(height: AppDimensions.paddingM),
              ElevatedButton(
                onPressed: () => ref.invalidate(parentsProvider),
                child: IonButtonLabel(context.l10n.messagesRetry),
              ),
            ],
          ),
        ),
        // UX_SETTINGS: Ionic modal layout — hint card on top, then the list
        data: (parents) {
          return RefreshIndicator.adaptive(
            onRefresh: () async {
              ref.invalidate(parentsProvider);
              await ref.read(parentsProvider.future);
            },
            // UX_SETTINGS (WAVE 8): hint card, then one inset list with
            // h2 name / h3 e-mail; tapping an item asks to remove it.
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                ionListMargin(context), AppDimensions.paddingM, ionListMargin(context), 88),
              children: [
                SettingsHintCard(
                  icon: Icons.favorite_border,
                  text: context.l10n.settingsParentsHint,
                ),
                SettingsListSection(
                  icons: false,
                  children: [
                    for (final item in parents)
                      _ParentItem(
                        parent: item,
                        onDelete: () => _deleteParent(context, ref, item),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddParentDialog(BuildContext context, WidgetRef ref) async {
    final emailController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.settingsAddParent),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: context.l10n.settingsEmailAddress,
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.l10n.settingsFlutterEmailRequired;
                  }
                  if (!value.contains('@')) {
                    return context.l10n.registerModalInvalidEmail;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.paddingM),
              TextFormField(
                controller: firstNameController,
                decoration: InputDecoration(
                  labelText: context.l10n.peopleFirstName,
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.l10n.settingsFlutterFirstNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.paddingM),
              TextFormField(
                controller: lastNameController,
                decoration: InputDecoration(
                  labelText: context.l10n.peopleLastName,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.l10n.settingsFlutterLastNameRequired;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: Text(context.l10n.settingsInvite),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        // REVIEW_FIX3: shared invite flow (Ionic db.createParent).
        await ref.read(parentNotifierProvider.notifier).invite(
              email: emailController.text,
              firstName: firstNameController.text,
              lastName: lastNameController.text,
            );
        if (context.mounted) {
          ToastHelper.showSuccess(context, context.l10n.settingsUserCreated);
        }
      } on AccountFlowException catch (e) {
        if (context.mounted) ToastHelper.showError(context, e.message);
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e)));
        }
      }
    }
  }

  Future<void> _deleteParent(BuildContext context, WidgetRef ref, ParentModel parent) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.settingsRemoveParent),
        content: Text(context.l10n.settingsRemoveMessage(parent.firstName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonYes),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final notifier = ref.read(parentNotifierProvider.notifier);
        await notifier.deleteParent(parent.id!, appId: parent.appId);

        if (context.mounted) {
          ToastHelper.showSuccess(context, context.l10n.settingsFlutterParentRemoved);
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e)));
        }
      }
    }
  }
}

class _ParentItem extends StatelessWidget {
  const _ParentItem({
    required this.parent,
    required this.onDelete,
  });

  final ParentModel parent;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ios = ionIsIos(context);
    return ListTile(
      title: Text(parent.fullName),
      subtitle: Text(
        parent.email,
        style: ios ? TextStyle(fontSize: 14, color: IonIos.text(context)) : null,
      ),
      onTap: onDelete,
    );
  }
}
