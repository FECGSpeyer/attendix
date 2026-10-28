import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../data/repositories/user_registration_repository.dart'
    show AccountFlowException;
import '../../../../core/providers/viewer_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/settings_list.dart'; // UX_SETTINGS
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/viewer/viewer.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Viewers Page - manage external observers
class ViewersPage extends ConsumerWidget {
  const ViewersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewersAsync = ref.watch(viewersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsViewers),
        leading: IconButton(
          icon: const BackButtonIcon(),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddViewerDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: viewersAsync.when(
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
                onPressed: () => ref.invalidate(viewersProvider),
                child: Text(context.l10n.messagesRetry),
              ),
            ],
          ),
        ),
        // UX_SETTINGS: Ionic modal layout — hint card on top, then the list
        data: (viewers) {
          return RefreshIndicator.adaptive(
            onRefresh: () async {
              ref.invalidate(viewersProvider);
              await ref.read(viewersProvider.future);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, 88),
              itemCount: viewers.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return SettingsHintCard(
                    icon: Icons.visibility_outlined,
                    text: context.l10n.settingsViewersHint,
                  );
                }
                final viewer = viewers[index - 1];
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

    final result = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.settingsAddViewer),
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
        // REVIEW_FIX3: shared invite flow (Ionic db.createViewer).
        await ref.read(viewerNotifierProvider.notifier).invite(
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

  Future<void> _deleteViewer(BuildContext context, WidgetRef ref, Viewer viewer) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.settingsRemoveViewer),
        content: Text(context.l10n.settingsRemoveMessage(viewer.firstName)),
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
        final notifier = ref.read(viewerNotifierProvider.notifier);
        await notifier.deleteViewer(viewer.id!, appId: viewer.appId);

        if (context.mounted) {
          ToastHelper.showSuccess(context, context.l10n.settingsFlutterViewerRemoved);
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, context.l10n.settingsFlutterErrorDetail(friendlyErrorMessage(e)));
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
