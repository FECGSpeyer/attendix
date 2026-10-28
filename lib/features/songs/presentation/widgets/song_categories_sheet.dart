import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/song/song.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart';
import '../../../../core/utils/error_message.dart';

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
              top: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              // UX_SONGS_SELF: Ionic categoriesModal toolbar (title + add)
              IonSheetHeader(
                title: context.l10n.songsSongCategories,
                end: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddCategoryDialog(context),
                    tooltip: context.l10n.songsAddCategory,
                  ),
                ],
              ),
              if (notifierState.isLoading) const LinearProgressIndicator(),
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
                        Text(context.l10n.songsFlutterErrorWith(friendlyErrorMessage(error))),
                        const SizedBox(height: AppDimensions.paddingM),
                        ElevatedButton(
                          onPressed: () =>
                              ref.invalidate(songCategoriesProvider),
                          child: Text(context.l10n.messagesRetry),
                        ),
                      ],
                    ),
                  ),
                  data: (categories) {
                    final displayCategories =
                        _reorderedCategories ?? categories;

                    if (displayCategories.isEmpty) {
                      return Center(
                        // Ionic: plain centred text
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.paddingM),
                          child: Text(
                            context.l10n.songsNoCategories,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    }

                    return ReorderableListView.builder(
                      scrollController: scrollController,
                      buildDefaultDragHandles: false,
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
                          index: index,
                          isFirst: index == 0,
                          isLast: index == displayCategories.length - 1,
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
                  context.l10n.songsFlutterReorderCategoriesHint,
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
        title: Text(context.l10n.songsAddCategory),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: context.l10n.songsCategoryName,
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
      final created = await ref.read(songCategoryNotifierProvider.notifier).add(result);
      if (created != null && context.mounted) {
        ToastHelper.showSuccess(context, context.l10n.songsCategoryAdded);
      }
    }
  }

  Future<void> _showEditCategoryDialog(
      BuildContext context, SongCategory category) async {
    final controller = TextEditingController(text: category.name);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.songsEditCategory),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: context.l10n.songsCategoryName,
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
      final ok = await ref
          .read(songCategoryNotifierProvider.notifier)
          .update(category.id!, result);
      if (ok && context.mounted) ToastHelper.showSuccess(context, context.l10n.songsCategorySaved);
    }
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context, SongCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.songsDeleteCategory),
        content: Text(context.l10n.songsDeleteCategoryMessage),
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
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && category.id != null && mounted) {
      final ok = await ref
          .read(songCategoryNotifierProvider.notifier)
          .delete(category.id!);
      if (ok && context.mounted) ToastHelper.showSuccess(context, context.l10n.songsCategoryDeleted);
    }
  }
}

/// Ionic: `ion-item` in an inset list: name, pencil (warning), trash
/// (danger) and the reorder handle at the end.
class _CategoryTile extends StatelessWidget {
  final SongCategory category;
  final int index;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryTile({
    super.key,
    required this.category,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(IonInsetList.radiusOf(context));
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? radius : Radius.zero,
          bottom: isLast ? radius : Radius.zero,
        ),
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
              ),
      ),
      padding: const EdgeInsets.only(left: 16, right: 8),
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          Expanded(child: Text(category.name, style: const TextStyle(fontSize: 16))),
          IconButton(
            icon: const Icon(Icons.edit, size: 20, color: AppColors.warning),
            onPressed: onEdit,
            tooltip: context.l10n.commonEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20, color: AppColors.danger),
            onPressed: onDelete,
            tooltip: context.l10n.commonDelete,
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.reorder, color: AppColors.medium),
            ),
          ),
        ],
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
