import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/user_registration_providers.dart'; // AUTH
import '../../../../core/providers/parent_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/parent/parent_model.dart';

/// Parents Page - manage parents of players
class ParentsPage extends ConsumerWidget {
  const ParentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentsAsync = ref.watch(parentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elternteile'),
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
              Text('Fehler: $e'),
              const SizedBox(height: AppDimensions.paddingM),
              ElevatedButton(
                onPressed: () => ref.invalidate(parentsProvider),
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
        data: (parents) {
          if (parents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.family_restroom_outlined, size: 80, color: AppColors.medium),
                  const SizedBox(height: AppDimensions.paddingL),
                  Text(
                    'Keine Elternteile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  Text(
                    'Elternteile können die Anwesenheit\nihrer Kinder einsehen.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.medium),
                  ),
                  const SizedBox(height: AppDimensions.paddingL),
                  ElevatedButton.icon(
                    onPressed: () => _showAddParentDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Elternteil hinzufügen'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            // FN-012: await provider.future to show spinner until data loads
            onRefresh: () async {
              ref.invalidate(parentsProvider);
              await ref.read(parentsProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              itemCount: parents.length,
              itemBuilder: (context, index) {
                final parent = parents[index];
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
        title: const Text('Elternteil hinzufügen'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'E-Mail',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'E-Mail ist erforderlich';
                  }
                  if (!value.contains('@')) {
                    return 'Ungültige E-Mail-Adresse';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.paddingM),
              TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Vorname',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vorname ist erforderlich';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.paddingM),
              TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Nachname',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nachname ist erforderlich';
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
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Hinzufügen'),
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
            ToastHelper.showError(context, 'Fehler beim Hinzufügen');
          } else {
            ToastHelper.showSuccess(context, 'Elternteil hinzugefügt');
          }
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, 'Fehler: $e');
        }
      }
    }
  }

  Future<void> _deleteParent(BuildContext context, WidgetRef ref, ParentModel parent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elternteil entfernen?'),
        content: Text('Möchtest du ${parent.fullName} als Elternteil entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final notifier = ref.read(parentNotifierProvider.notifier);
        await notifier.deleteParent(parent.id!);

        if (context.mounted) {
          ToastHelper.showSuccess(context, 'Elternteil entfernt');
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, 'Fehler: $e');
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
