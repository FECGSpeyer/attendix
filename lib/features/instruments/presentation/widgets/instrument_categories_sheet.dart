import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/instrument_sort.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../shared/widgets/layout/ion_form_items.dart' show withIonLoading;
import '../../../../shared/widgets/layout/ionic_ios.dart' show ionPlainContentBackground;
import '../../../people/presentation/widgets/ion/ion_widgets.dart' show IonItem, IonBadge, IonText;

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

  /// Whether a category was actually moved in the current reorder session
  bool _moved = false;

  Future<void> _toggleReorder(List<GroupCategory> categories) async {
    if (!_isReordering) {
      setState(() {
        _isReordering = true;
        _moved = false;
        _working = [...categories];
      });
      return;
    }
    final ordered = _working ?? categories;
    final moved = _moved;
    setState(() {
      _isReordering = false;
      _working = null;
      _moved = false;
    });

    if (!moved) {
      // Ionic saveCategoryOrder without a move: the existing category
      // sort_order values are written unchanged (null stays null).
      // EIB-19: Ionic `ion-loading` "Reihenfolge wird gespeichert…".
      final ok = await withIonLoading(
        context,
        () => ref.read(groupNotifierProvider.notifier).saveCategoryOrder({
          for (final c in categories)
            if (c.id != null) c.id!: c.sortOrder,
        }),
        message: context.l10n.instrumentsSavingOrder,
      );
      if (!mounted) return;
      if (ok) {
        ToastHelper.showSuccess(context, context.l10n.typeSettingsOrderSaved);
      } else {
        ToastHelper.showError(context, context.l10n.instrumentsOrderFailed);
      }
      return;
    }

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

    final ok = await withIonLoading(
      context,
      () => ref
          .read(groupNotifierProvider.notifier)
          .saveCategoryOrder(categoryOrders, groupSortOrders: groupOrders),
      message: context.l10n.instrumentsSavingOrder,
    );
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

    // Ionic categories modal: [breakpoints]="[0, 0.6, 1]"
    // [initialBreakpoint]="0.6"; toolbar with the ion-title and the end
    // buttons reorder + add (no leading icon, no close button).
    return IonBreakpointSheet(
      breakpoints: const [0, 0.6, 1],
      initialBreakpoint: 0.6,
      builder: (context, scrollController) {
        return ColoredBox(
          // Ionic `ion-content` without colour.
          color: ionPlainContentBackground(context) ?? Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              IonSheetHeader(
                title: context.l10n.instrumentsCategories,
                end: [
                  IconButton(
                    icon: Icon(
                        _isReordering ? AppIcons.check : AppIcons.swapVert),
                    tooltip: _isReordering
                        ? context.l10n.peopleFlutterSaveOrder
                        : context.l10n.peopleReorder,
                    onPressed: categoriesAsync.hasValue
                        ? () => _toggleReorder(categoriesAsync.value!)
                        : null,
                  ),
                  if (!_isReordering)
                    IconButton(
                      icon: Icon(AppIcons.add),
                      onPressed: () => _showAddCategoryDialog(context),
                      tooltip: context.l10n.instrumentsNewCategory,
                    ),
                ],
              ),
              // Content
              Expanded(
                child: categoriesAsync.when(
                  loading: () =>
                      const Center(child: AppSpinner()),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.errorOutline,
                            size: 48, color: AppColors.danger),
                        const SizedBox(height: AppDimensions.paddingM),
                        Text(context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(error))),
                        const SizedBox(height: AppDimensions.paddingM),
                        IonButton(
                          onPressed: () =>
                              ref.invalidate(groupCategoriesProvider),
                          label: context.l10n.messagesRetry,
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
                            Icon(
                              AppIcons.categoryOutlined,
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // EIB-03: Ionic `ion-item color="primary"
                          // lines="none"` with the info icon and a `p`.
                          IonItem(
                            lines: false,
                            background: AppColors.primary,
                            start: Icon(AppIcons.info, color: Colors.white),
                            child: Text(
                              context.l10n.instrumentsDragCategories,
                              style: IonText.p(context).copyWith(color: Colors.white),
                            ),
                          ),
                          Expanded(
                            child: ReorderableListView.builder(
                              scrollController: scrollController,
                              padding: EdgeInsets.zero,
                              buildDefaultDragHandles: false,
                              itemCount: working.length,
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  final list = [...working];
                                  if (newIndex > oldIndex) newIndex -= 1;
                                  if (newIndex != oldIndex) _moved = true;
                                  final item = list.removeAt(oldIndex);
                                  list.insert(newIndex, item);
                                  _working = list;
                                });
                              },
                              itemBuilder: (context, index) {
                                final category = working[index];
                                return _CategoryTile(
                                  key: ValueKey(category.id ?? index),
                                  category: category,
                                  dragIndex: index,
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
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
        // Ionic alert input with a placeholder; "Abbrechen" has
        // `role: 'destructive'` (instrument-list.page.ts).
        content: AppAlertInput(
          controller: controller,
          placeholder: context.l10n.instrumentsCategoryName,
          betaDecoration: InputDecoration(
            labelText: context.l10n.instrumentsCategoryName,
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: appAlertDestructiveStyle(context),
            child: Text(context.l10n.commonCancel),
          ),
          // EIB-10: a plain alert button like Ionic.
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                // Ionic: red toast, the alert stays open (return false)
                ToastHelper.showError(context, context.l10n.instrumentsEnterName);
                return;
              }
              Navigator.of(context).pop(name);
            },
            child: Text(context.l10n.attendanceAdd),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final created = await ref.read(groupNotifierProvider.notifier).createGroupCategory(result);
      // Ionic GroupCategoryService: 'Fehler beim Hinzufügen der Kategorie'.
      if (created == null && mounted) {
        ToastHelper.showError(this.context, this.context.l10n.svcAddCategoryFailed);
      }
    }
  }

  Future<void> _showEditCategoryDialog(
      BuildContext context, GroupCategory category) async {
    final controller = TextEditingController(text: category.name);

    final result = await showAppDialog<String>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.instrumentsEditCategory),
        // Ionic alert input with a placeholder; "Abbrechen" has
        // `role: 'destructive'` (instrument-list.page.ts).
        content: AppAlertInput(
          controller: controller,
          placeholder: context.l10n.instrumentsCategoryName,
          betaDecoration: InputDecoration(
            labelText: context.l10n.instrumentsCategoryName,
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: appAlertDestructiveStyle(context),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                // Ionic: red toast, the alert stays open (return false)
                ToastHelper.showError(context, context.l10n.instrumentsEnterName);
                return;
              }
              Navigator.of(context).pop(name);
            },
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );

    if (result != null && category.id != null && mounted) {
      final updated = await ref
          .read(groupNotifierProvider.notifier)
          .updateGroupCategory(category.id!, {'name': result});
      if (updated == null && mounted) {
        ToastHelper.showError(this.context, this.context.l10n.svcUpdateCategoryFailed);
      }
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
          // EIB-18: Ionic `role: 'destructive'` on "Abbrechen", "Ja" plain.
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: appAlertDestructiveStyle(context),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
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
      if (mounted && ref.read(groupNotifierProvider).hasError) {
        ToastHelper.showError(this.context, this.context.l10n.svcDeleteCategoryFailed);
      }
    }
  }
}

/// EIB-03: Ionic category row – plain `ion-item` with `ion-reorder` (reorder
/// mode) and the medium sort badge at the start, the label, and the clear
/// `warning` pencil / `danger` trash buttons at the end.
class _CategoryTile extends StatelessWidget {
  final GroupCategory category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Set in reorder mode: drag handle at the start, no buttons.
  final int? dragIndex;

  const _CategoryTile({
    super.key,
    required this.category,
    this.onEdit,
    this.onDelete,
    this.dragIndex,
  });

  @override
  Widget build(BuildContext context) {
    final hasStart = dragIndex != null || category.sortOrder != null;
    return IonItem(
      start: hasStart
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dragIndex != null) ...[
                  ReorderableDragStartListener(
                    index: dragIndex!,
                    child: Icon(AppIcons.reorder, color: AppColors.medium),
                  ),
                  if (category.sortOrder != null) const SizedBox(width: 16),
                ],
                if (category.sortOrder != null)
                  IonBadge(text: '${category.sortOrder}', color: AppColors.medium),
              ],
            )
          : null,
      end: [
        if (dragIndex == null) ...[
          IconButton(
            icon: Icon(AppIcons.edit, color: AppColors.warning),
            onPressed: onEdit,
            tooltip: context.l10n.commonEdit,
          ),
          IconButton(
            icon: Icon(AppIcons.delete, color: AppColors.danger),
            onPressed: onDelete,
            tooltip: context.l10n.commonDelete,
          ),
        ],
      ],
      child: Text(category.name, style: IonText.p(context).copyWith(
        fontSize: useIosLook(context) ? 17 : 16,
        color: Theme.of(context).colorScheme.onSurface,
      )),
    );
  }
}

/// Shows the instrument categories management sheet. In the Beta the page
/// Gruppen › Kategorien opens instead.
Future<void> showInstrumentCategoriesSheet(BuildContext context) async {
  if (ProviderScope.containerOf(context, listen: false).read(redesignEnabledProvider)) {
    await context.push(RedesignRoutes.groupCategories);
    return;
  }
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    builder: (context) => const InstrumentCategoriesSheet(),
  );
}
