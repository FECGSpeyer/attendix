import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/user_registration_providers.dart'; // AUTH
import '../../../../core/providers/parent_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/settings_list.dart'; // UX_SETTINGS
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/parent/parent_model.dart';
import '../../../../l10n/l10n.dart';

/// Parents Page - manage parents of players
class ParentsPage extends ConsumerWidget {
  const ParentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentsAsync = ref.watch(parentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsParents),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddParentDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: parentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text(context.l10n.settingsFlutterErrorDetail(e)),
              const SizedBox(height: AppDimensions.paddingM),
              ElevatedButton(
                onPressed: () => ref.invalidate(parentsProvider),
                child: Text(context.l10n.messagesRetry),
              ),
            ],
          ),
        ),
        // UX_SETTINGS: Ionic modal layout — hint card on top, then the list
        data: (parents) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(parentsProvider);
              await ref.read(parentsProvider.future);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, 88),
              itemCount: parents.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return SettingsHintCard(
                    icon: Icons.favorite_border,
                    text: context.l10n.settingsParentsHint,
                  );
                }
                final parent = parents[index - 1];
                return _ParentItem(
                  parent: parent,
                  onDelete: () => _deleteParent(context, ref, parent),
                );
              },
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

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
        final notifier = ref.read(parentNotifierProvider.notifier);
        // AUTH: Ionic db.createParent: account via registerUser (attendix-user
        // Edge Function for new e-mails, inform mail for existing accounts).
        final appId = await ref
            .read(userRegistrationRepositoryWithTenantProvider)
            .registerUser(
              email: emailController.text.trim(),
              name: firstNameController.text.trim(),
              role: Role.parent,
            );
        final parent = ParentModel(
          appId: appId,
          email: emailController.text.trim(),
          firstName: firstNameController.text.trim(),
          lastName: lastNameController.text.trim(),
        );

        final created = await notifier.createParent(parent);
        if (created?.id != null) {
          await ref
              .read(userRegistrationRepositoryWithTenantProvider)
              .linkParentToTenantUser(appId, created!.id!);
        }

        if (context.mounted) {
          if (created == null) {
            ToastHelper.showError(context, context.l10n.settingsFlutterAddFailed);
          } else {
            ToastHelper.showSuccess(context, context.l10n.settingsUserCreated);
          }
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(e));
        }
      }
    }
  }

  Future<void> _deleteParent(BuildContext context, WidgetRef ref, ParentModel parent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
          ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(e));
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
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.success.withValues(alpha: 0.1),
          child: Text(
            parent.initials,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ),
        title: Text(
          parent.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(parent.email),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: AppColors.danger),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
