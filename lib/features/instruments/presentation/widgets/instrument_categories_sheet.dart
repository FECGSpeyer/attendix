import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/instrument_sort.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Bottom sheet for managing instrument categories (CRUD)
class InstrumentCategoriesSheet extends ConsumerStatefulWidget {
  const InstrumentCategoriesSheet({super.key});

  @override
  ConsumerState<InstrumentCategoriesSheet> createState() =>
      _InstrumentCategoriesSheetState();
}

class _InstrumentCategoriesSheetState
    extends ConsumerState<InstrumentCategoriesSheet> {
  bool _isReordering = false;
  List<GroupCategory>? _working;

  Future<void> _toggleReorder(List<GroupCategory> categories) async {
    if (!_isReordering) {
      setState(() {
        _isReordering = true;
        _working = [...categories];
      });
      return;
    }
    final ordered = _working ?? categories;
    setState(() {
      _isReordering = false;
      _working = null;
    });

    // New category sort_order (1-based) + resulting global instrument order
    final categoryOrders = <int, int>{};
    final updatedCats = <GroupCategory>[];
    for (var i = 0; i < ordered.length; i++) {
      final c = ordered[i];
      if (c.id != null) categoryOrders[c.id!] = i + 1;
      updatedCats.add(c.copyWith(sortOrder: i + 1));
    }
    final groups = ref.read(groupsProvider).valueOrNull ?? const [];
    final groupOrders = computeGlobalSortOrder(
      groupInstrumentsByCategory(groups, updatedCats),
    );

    final ok = await ref
        .read(groupNotifierProvider.notifier)
        .saveCategoryOrder(categoryOrders, groupSortOrders: groupOrders);
    if (!mounted) return;
    if (ok) {
      ToastHelper.showSuccess(context, context.l10n.typeSettingsOrderSaved);
    } else {
      ToastHelper.showError(context, context.l10n.instrumentsOrderFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(groupCategoriesProvider);
    final notifierState = ref.watch(groupNotifierProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.borderRadiusL),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.medium.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Row(
                  children: [
                    const Icon(Icons.category, color: AppColors.primary),
                    const SizedBox(width: AppDimensions.paddingS),
                    Expanded(
                      child: Text(
                        context.l10n.instrumentsCategories,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                          _isReordering ? Icons.check : Icons.swap_vert),
                      tooltip: _isReordering
                          ? context.l10n.peopleFlutterSaveOrder
                          : context.l10n.peopleReorder,
                      onPressed: categoriesAsync.hasValue
                          ? () => _toggleReorder(categoriesAsync.value!)
                          : null,
                    ),
                    if (!_isReordering)
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddCategoryDialog(context),
                        tooltip: context.l10n.instrumentsNewCategory,
                      ),
                    IconButton(
                      icon: Icon(Icons.close, semanticLabel: context.l10n.commonClose),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              if (notifierState.isLoading)
                const LinearProgressIndicator()
              else
                const Divider(height: 1),
              // Content
              Expanded(
                child: categoriesAsync.when(
                  loading: () =>
                      const Center(child: AppSpinner()),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.danger),
                        const SizedBox(height: AppDimensions.paddingM),
                        Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(error))),
                        const SizedBox(height: AppDimensions.paddingM),
                        ElevatedButton(
                          onPressed: () =>
                              ref.invalidate(groupCategoriesProvider),
                          child: IonButtonLabel(context.l10n.messagesRetry),
                        ),
                      ],
                    ),
                  ),
                  data: (categories) {
                    if (categories.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.category_outlined,
                              size: 64,
                              color: AppColors.medium,
                            ),
                            const SizedBox(height: AppDimensions.paddingM),
                            Text(
                              context.l10n.instrumentsFlutterNoCategories,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppDimensions.paddingS),
                            Text(
                              context.l10n.instrumentsFlutterNoCategoriesHint,
                              style: const TextStyle(color: AppColors.medium),
                            ),
                          ],
                        ),
                      );
                    }

                    if (_isReordering) {
                      final working = _working ?? categories;
                      return Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.info_outline,
                                color: AppColors.primary),
                            title: Text(context.l10n.instrumentsDragCategories),
                          ),
                          Expanded(
                            child: ReorderableListView.builder(
                              scrollController: scrollController,
                              padding:
                                  const EdgeInsets.all(AppDimensions.paddingM),
                              itemCount: working.length,
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  final list = [...working];
                                  if (newIndex > oldIndex) newIndex -= 1;
                                  final item = list.removeAt(oldIndex);
                                  list.insert(newIndex, item);
                                  _working = list;
                                });
                              },
                              itemBuilder: (context, index) {
                                final category = working[index];
                                return Card(
                                  key: ValueKey(category.id ?? index),
                                  margin: const EdgeInsets.only(
                                      bottom: AppDimensions.paddingS),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      radius: 14,
                                      child: Text('${index + 1}',
                                          style:
                                              const TextStyle(fontSize: 12)),
                                    ),
                                    title: Text(category.name),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return _CategoryTile(
                          key: ValueKey(category.id ?? index),
                          category: category,
                          onEdit: () =>
                              _showEditCategoryDialog(context, category),
                          onDelete: () =>
                              _showDeleteConfirmation(context, category),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final controller = TextEditingController();

    final result = await showAppDialog<String>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.instrumentsNewCategory),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.l10n.instrumentsCategoryName,
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: Text(context.l10n.attendanceAdd),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await ref.read(groupNotifierProvider.notifier).createGroupCategory(result);
    }
  }

  Future<void> _showEditCategoryDialog(
      BuildContext context, GroupCategory category) async {
    final controller = TextEditingController(text: category.name);

    final result = await showAppDialog<String>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.instrumentsEditCategory),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.l10n.instrumentsCategoryName,
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );

    if (result != null && category.id != null && mounted) {
      await ref
          .read(groupNotifierProvider.notifier)
          .updateGroupCategory(category.id!, {'name': result});
    }
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context, GroupCategory category) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.commonConfirm),
        content: Text(context.l10n.instrumentsDeleteCategory),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.commonYes),
          ),
        ],
      ),
    );

    if (confirmed == true && category.id != null && mounted) {
      await ref
          .read(groupNotifierProvider.notifier)
          .deleteGroupCategory(category.id!);
    }
  }
}

class _CategoryTile extends StatelessWidget {
  final GroupCategory category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryTile({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      child: ListTile(
        leading: const Icon(Icons.category, size: 20),
        title: Text(category.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
              tooltip: context.l10n.commonEdit,
            ),
            IconButton(
              icon:
                  const Icon(Icons.delete, size: 20, color: AppColors.danger),
              onPressed: onDelete,
              tooltip: context.l10n.commonDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the instrument categories management sheet
Future<void> showInstrumentCategoriesSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const InstrumentCategoriesSheet(),
  );
}
