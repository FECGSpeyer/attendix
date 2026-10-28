import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/user_registration_providers.dart'; // AUTH
import '../../../../core/providers/viewer_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/viewer/viewer.dart';

/// Viewers Page - manage external observers
class ViewersPage extends ConsumerWidget {
  const ViewersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewersAsync = ref.watch(viewersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beobachter'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddViewerDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: viewersAsync.when(
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
                onPressed: () => ref.invalidate(viewersProvider),
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
        data: (viewers) {
          if (viewers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.visibility_outlined, size: 80, color: AppColors.medium),
                  const SizedBox(height: AppDimensions.paddingL),
                  Text(
                    'Keine Beobachter',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  Text(
                    'Beobachter können Anwesenheitsdaten einsehen,\naber nicht bearbeiten.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.medium),
                  ),
                  const SizedBox(height: AppDimensions.paddingL),
                  ElevatedButton.icon(
                    onPressed: () => _showAddViewerDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Beobachter hinzufügen'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            // FN-011: await provider.future to show spinner until data loads
            onRefresh: () async {
              ref.invalidate(viewersProvider);
              await ref.read(viewersProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              itemCount: viewers.length,
              itemBuilder: (context, index) {
                final viewer = viewers[index];
                return _ViewerItem(
                  viewer: viewer,
                  onDelete: () => _deleteViewer(context, ref, viewer),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddViewerDialog(BuildContext context, WidgetRef ref) async {
    final emailController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Beobachter hinzufügen'),
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
        final notifier = ref.read(viewerNotifierProvider.notifier);
        // AUTH: Ionic db.createViewer: account via registerUser (attendix-user
        // Edge Function for new e-mails, inform mail for existing accounts).
        final appId = await ref
            .read(userRegistrationRepositoryWithTenantProvider)
            .registerUser(
              email: emailController.text.trim(),
              name: firstNameController.text.trim(),
              role: Role.viewer,
            );
        final viewer = Viewer(
          appId: appId,
          email: emailController.text.trim(),
          firstName: firstNameController.text.trim(),
          lastName: lastNameController.text.trim(),
        );

        final created = await notifier.createViewer(viewer);

        if (context.mounted) {
          if (created == null) {
            ToastHelper.showError(context, 'Fehler beim Hinzufügen');
          } else {
            ToastHelper.showSuccess(context, 'Beobachter hinzugefügt');
          }
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, 'Fehler: $e');
        }
      }
    }
  }

  Future<void> _deleteViewer(BuildContext context, WidgetRef ref, Viewer viewer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Beobachter entfernen?'),
        content: Text('Möchtest du ${viewer.fullName} als Beobachter entfernen?'),
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
        final notifier = ref.read(viewerNotifierProvider.notifier);
        await notifier.deleteViewer(viewer.id!);

        if (context.mounted) {
          ToastHelper.showSuccess(context, 'Beobachter entfernt');
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, 'Fehler: $e');
        }
      }
    }
  }
}

class _ViewerItem extends StatelessWidget {
  const _ViewerItem({
    required this.viewer,
    required this.onDelete,
  });

  final Viewer viewer;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            viewer.initials,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        title: Text(
          viewer.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(viewer.email),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: AppColors.danger),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
