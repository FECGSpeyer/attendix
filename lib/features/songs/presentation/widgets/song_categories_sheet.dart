import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/song/song.dart';

/// Bottom sheet for managing song categories (CRUD)
class SongCategoriesSheet extends ConsumerStatefulWidget {
  const SongCategoriesSheet({super.key});

  @override
  ConsumerState<SongCategoriesSheet> createState() =>
      _SongCategoriesSheetState();
}

class _SongCategoriesSheetState extends ConsumerState<SongCategoriesSheet> {
  List<SongCategory>? _reorderedCategories;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(songCategoriesProvider);
    final notifierState = ref.watch(songCategoryNotifierProvider);

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
                        'Werk-Kategorien',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
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
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
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
                              ref.invalidate(songCategoriesProvider),
                          child: const Text('Erneut versuchen'),
                        ),
                      ],
                    ),
                  ),
                  data: (categories) {
                    final displayCategories =
                        _reorderedCategories ?? categories;

                    if (displayCategories.isEmpty) {
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

                    return ReorderableListView.builder(
                      scrollController: scrollController,
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      itemCount: displayCategories.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final items =
                              List<SongCategory>.from(displayCategories);
                          final item = items.removeAt(oldIndex);
                          items.insert(newIndex, item);
                          _reorderedCategories = items;
                        });
                        // Save new order
                        _saveReorder();
                      },
                      itemBuilder: (context, index) {
                        final category = displayCategories[index];
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
              // Hint
              Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Text(
                  'Ziehe Kategorien um sie neu zu sortieren',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.medium,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveReorder() async {
    if (_reorderedCategories == null) return;
    await ref
        .read(songCategoryNotifierProvider.notifier)
        .reorder(_reorderedCategories!);
    _reorderedCategories = null;
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
            hintText: 'z.B. Weihnachten',
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
      await ref.read(songCategoryNotifierProvider.notifier).add(result);
    }
  }

  Future<void> _showEditCategoryDialog(
      BuildContext context, SongCategory category) async {
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
          .read(songCategoryNotifierProvider.notifier)
          .update(category.id!, result);
    }
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context, SongCategory category) async {
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
          .read(songCategoryNotifierProvider.notifier)
          .delete(category.id!);
    }
  }
}

class _CategoryTile extends StatelessWidget {
  final SongCategory category;
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
        leading: const Icon(Icons.drag_handle),
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
              icon: const Icon(Icons.delete, size: 20, color: AppColors.danger),
              onPressed: onDelete,
              tooltip: 'Löschen',
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the song categories management sheet
Future<void> showSongCategoriesSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const SongCategoriesSheet(),
  );
}
