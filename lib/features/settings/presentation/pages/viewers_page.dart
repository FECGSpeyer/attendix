import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../data/repositories/user_registration_repository.dart'
    show AccountFlowException;
import '../../../../core/providers/viewer_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/settings_list.dart'; // UX_SETTINGS
import '../widgets/settings_sheet.dart'; // IOS_SETTINGS2
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/viewer/viewer.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Viewers Page - manage external observers
/// IOS_SETTINGS2: Ionic settings "viewer-button" opens the "Beobachter" sheet
/// (`[breakpoints]="[0, 1]"`, initial 1, toolbar with the title only).
Future<void> showViewersSheet(BuildContext context) => showSettingsSheet<void>(
      context,
      builder: (_) => const ViewersPage(sheet: true),
    );

class ViewersPage extends ConsumerWidget {
  const ViewersPage({super.key, this.sheet = false});

  /// Presented as the Ionic sheet (no back button) instead of a route.
  final bool sheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewersAsync = ref.watch(viewersProvider);

    return Scaffold(
      appBar: sheet
          ? settingsSheetBar(context, title: context.l10n.settingsViewers)
          : AppBar(
              title: Text(context.l10n.settingsViewers),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, semanticLabel: context.l10n.commonBack),
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
                child: IonButtonLabel(context.l10n.messagesRetry),
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
            // UX_SETTINGS (WAVE 8): hint card, then one inset list with
            // h2 name / h3 e-mail; tapping an item asks to remove it.
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                ionListMargin(context), AppDimensions.paddingM, ionListMargin(context), 88),
              children: [
                SettingsHintCard(
                  icon: Icons.visibility_outlined,
                  text: context.l10n.settingsViewersHint,
                ),
                SettingsListSection(
                  icons: false,
                  children: [
                    for (final item in viewers)
                      _ViewerItem(
                        viewer: item,
                        onDelete: () => _deleteViewer(context, ref, item),
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
    final ios = ionIsIos(context);
    return ListTile(
      title: Text(viewer.fullName),
      subtitle: Text(
        viewer.email,
        style: ios ? TextStyle(fontSize: 14, color: IonIos.text(context)) : null,
      ),
      onTap: onDelete,
    );
  }
}
