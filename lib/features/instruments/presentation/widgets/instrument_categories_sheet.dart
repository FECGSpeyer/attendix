import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/instrument_sort.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';

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
      ToastHelper.showSuccess(context, 'Reihenfolge gespeichert');
    } else {
      ToastHelper.showError(context, 'Fehler beim Speichern der Reihenfolge');
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
                        'Kategorien verwalten',
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
                          ? 'Reihenfolge speichern'
                          : 'Reihenfolge ändern',
                      onPressed: categoriesAsync.hasValue
                          ? () => _toggleReorder(categoriesAsync.value!)
                          : null,
                    ),
                    if (!_isReordering)
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddCategoryDialog(context),
                        tooltip: 'Neue Kategorie',
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
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
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.danger),
                        const SizedBox(height: AppDimensions.paddingM),
                        Text('Fehler: $error'),
                        const SizedBox(height: AppDimensions.paddingM),
                        ElevatedButton(
                          onPressed: () =>
                              ref.invalidate(groupCategoriesProvider),
                          child: const Text('Erneut versuchen'),
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
                              'Keine Kategorien',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppDimensions.paddingS),
                            const Text(
                              'Tippe + um eine Kategorie zu erstellen',
                              style: TextStyle(color: AppColors.medium),
                            ),
                          ],
                        ),
                      );
                    }

                    if (_isReordering) {
                      final working = _working ?? categories;
                      return Column(
                        children: [
                          const ListTile(
                            leading: Icon(Icons.info_outline,
                                color: AppColors.primary),
                            title: Text(
                                'Ziehe die Kategorien in die gewünschte Reihenfolge'),
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

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Kategorie'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'z.B. Streicher',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: const Text('Erstellen'),
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

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kategorie bearbeiten'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Name',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: const Text('Speichern'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kategorie löschen?'),
        content: Text(
            'Möchtest du die Kategorie "${category.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
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
              tooltip: 'Bearbeiten',
            ),
            IconButton(
              icon:
                  const Icon(Icons.delete, size: 20, color: AppColors.danger),
              onPressed: onDelete,
              tooltip: 'Löschen',
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
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const InstrumentCategoriesSheet(),
  );
}
