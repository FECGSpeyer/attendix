import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/group_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/instrument_sort.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/instrument/instrument.dart';
import '../widgets/instrument_categories_sheet.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../../../people/presentation/widgets/ion/ion_widgets.dart'; // UX_PEOPLE
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2
import '../../../../shared/widgets/layout/ionic_ios.dart' show ionPlainContentBackground; // PARITY_R5

/// Instruments list page — grouped by category with player counts.
/// Supports drag & drop reordering (sort_order) like Ionic instrument-list.
class InstrumentsListPage extends ConsumerStatefulWidget {
  const InstrumentsListPage({super.key});

  @override
  ConsumerState<InstrumentsListPage> createState() =>
      _InstrumentsListPageState();
}

class _InstrumentsListPageState extends ConsumerState<InstrumentsListPage> {
  bool _isReordering = false;

  /// Local working copy while reordering
  List<InstrumentCategorySection>? _reorderSections;

  Future<void> _toggleReorder(
      List<Group> groups, List<GroupCategory> categories) async {
    if (!_isReordering) {
      setState(() {
        _isReordering = true;
        _reorderSections = groupInstrumentsByCategory(groups, categories);
      });
      return;
    }

    // Leaving reorder mode → save global order
    final sections = _reorderSections ?? const <InstrumentCategorySection>[];
    final orders = computeGlobalSortOrder(sections);
    setState(() {
      _isReordering = false;
      _reorderSections = null;
    });
    final ok =
        await ref.read(groupNotifierProvider.notifier).saveGroupOrder(orders);
    if (!mounted) return;
    if (!ok) {
      ToastHelper.showError(context, context.l10n.instrumentsOrderFailed);
    }
  }

  void _onReorder(
      InstrumentCategorySection section, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = section.groups.removeAt(oldIndex);
      section.groups.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    final categoriesAsync = ref.watch(groupCategoriesProvider);
    final playerCountsAsync = ref.watch(playerCountsForGroupsProvider);
    final currentRole = ref.watch(currentRoleProvider);
    // Ionic instrument-list isAdmin = Admin or Responsible
    final isAdmin = currentRole.isAdmin || currentRole.isResponsible;
    final tenant = ref.watch(currentTenantProvider);
    final count = groupsAsync.valueOrNull?.length ?? 0;

    Future<void> refresh() async {
      ref.invalidate(groupsProvider);
      ref.invalidate(groupCategoriesProvider);
      ref.invalidate(playerCountsForGroupsProvider);
      await ref.read(groupsProvider.future);
    }

    // UX_PEOPLE: Ionic instrument-list — back, "Gruppen (n)" (condensed
    // large title on iOS), reorder toggle + categories, plain ion-list.
    return IonPage(
      title: context.l10n.instrumentsGroupsCount(count),
      leading: IconButton(
        icon: const BackButtonIcon(),
        onPressed: () => context.go('/settings'),
      ),
      actions: [
        if (isAdmin) ...[
          IconButton(
            icon: Icon(_isReordering ? Icons.check : Icons.swap_vert),
            tooltip: _isReordering
                ? context.l10n.peopleFlutterSaveOrder
                : context.l10n.peopleReorder,
            onPressed: groupsAsync.hasValue
                ? () => _toggleReorder(groupsAsync.value!,
                    categoriesAsync.valueOrNull ?? const [])
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.sell_outlined),
            onPressed: () => showInstrumentCategoriesSheet(context),
            tooltip: context.l10n.instrumentsCategories,
          ),
        ],
      ],
      onRefresh: refresh,
      slivers: [
        ...groupsAsync.when(
          loading: () => [
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: AppSpinner()),
            ),
          ],
          error: (error, stack) => [
            SliverFillRemaining(
              hasScrollBody: false,
              child: IonNoData(
                icon: Icons.error_outline,
                label: context.l10n.peopleFlutterErrorWith(friendlyErrorMessage(error)),
                actions: [
                  (context.l10n.messagesRetry, () => ref.invalidate(groupsProvider)),
                ],
              ),
            ),
          ],
          data: (groups) {
            final categories = categoriesAsync.valueOrNull ?? [];
            final playerCounts = playerCountsAsync.valueOrNull ?? {};
            final sections = _isReordering && _reorderSections != null
                ? _reorderSections!
                : groupInstrumentsByCategory(groups, categories);
            return [
              SliverToBoxAdapter(
                child: _GroupedInstrumentsList(
                  sections: sections,
                  playerCounts: playerCounts,
                  tenantType: tenant?.type,
                  isReordering: _isReordering,
                  onReorder: _onReorder,
                  onEdit: isAdmin
                      ? (group) => _openInstrumentPage(context, ref, group,
                          categories, tenantType: tenant?.type)
                      : null,
                ),
              ),
            ];
          },
        ),
      ],
      floatingActionButton: TabBarFab.wrap(isAdmin
          ? IonFabButton(
              onPressed: () => _showAddGroupSheet(
                  context, ref, categoriesAsync.valueOrNull ?? const []),
            )
          : null),
    );
  }
}

/// Grouped list of instruments by category (Ionic: primary sticky dividers
/// "Kategorie (n)", items with sort-order badge and "n Personen" badge).
class _GroupedInstrumentsList extends StatelessWidget {
  const _GroupedInstrumentsList({
    required this.sections,
    required this.playerCounts,
    required this.tenantType,
    required this.isReordering,
    required this.onReorder,
    required this.onEdit,
  });

  final List<InstrumentCategorySection> sections;
  final Map<int, int> playerCounts;
  final String? tenantType;
  final bool isReordering;
  final void Function(InstrumentCategorySection, int, int) onReorder;
  final void Function(Group)? onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ionic: ion-item color="primary" lines="none" with info icon
        if (isReordering)
          IonItem(
            lines: false,
            background: AppColors.primary,
            start: const Icon(Icons.info, color: Colors.white),
            child: Text(
              context.l10n.instrumentsDragGroups,
              style: IonText.p(context).copyWith(color: Colors.white),
            ),
          ),
        for (final section in sections) ...[
          _SectionHeader(title: section.name, count: section.groups.length),
          if (isReordering)
            ReorderableListView(
              key: ValueKey('section-${section.categoryId}'),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (o, n) => onReorder(section, o, n),
              children: [
                for (var i = 0; i < section.groups.length; i++)
                  _GroupListItem(
                    key: ValueKey(section.groups[i].id ?? i),
                    group: section.groups[i],
                    tenantType: tenantType,
                    playerCount: playerCounts[section.groups[i].id] ?? 0,
                    onTap: null,
                    dragIndex: i,
                  ),
              ],
            )
          else
            ...section.groups.map((group) => _GroupListItem(
                  group: group,
                  tenantType: tenantType,
                  playerCount: playerCounts[group.id] ?? 0,
                  onTap: onEdit == null ? null : () => onEdit!(group),
                )),
        ],
      ],
    );
  }
}

/// Ionic ion-item-divider color="primary"
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return IonItemDivider(text: '$title ($count)', color: AppColors.primary);
  }
}

/// Instrument row (Ionic instrument-list ion-item)
class _GroupListItem extends StatelessWidget {
  const _GroupListItem({
    super.key,
    required this.group,
    required this.tenantType,
    required this.playerCount,
    required this.onTap,
    this.dragIndex,
  });

  final Group group;
  final String? tenantType;
  final int playerCount;
  final VoidCallback? onTap;

  /// Set in reorder mode: shows the drag handle at the start.
  final int? dragIndex;

  bool get _isChoirOrGeneral =>
      tenantType == 'choir' || tenantType == 'general';

  @override
  Widget build(BuildContext context) {
    final String title;
    if (group.maingroup == true) {
      title = context.l10n.instrumentsMainGroup(group.name);
    } else if (!_isChoirOrGeneral) {
      title = '${group.name} (${group.tuning ?? 'C'})';
    } else {
      title = group.name;
    }
    final clefText =
        (group.clefs ?? const <String>[]).map((c) => _clefLabel(context.l10n, c)).join(', ');

    final hasStart = dragIndex != null || group.sortOrder != null;
    return IonItem(
      onTap: onTap,
      start: hasStart
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dragIndex != null) ...[
                  ReorderableDragStartListener(
                    index: dragIndex!,
                    child: const Icon(Icons.reorder, color: AppColors.medium),
                  ),
                  if (group.sortOrder != null) const SizedBox(width: 16),
                ],
                if (group.sortOrder != null)
                  IonBadge(text: '${group.sortOrder}', color: AppColors.medium),
              ],
            )
          : null,
      end: [
        IonBadge(
          text: context.l10n.commonPersons(playerCount),
          color: playerCount == 0 ? AppColors.danger : AppColors.primary,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: IonText.h2(context)),
          if (group.maingroup != true &&
              !_isChoirOrGeneral &&
              clefText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(clefText, style: IonText.h3(context)),
            ),
        ],
      ),
    );
  }
}

/// Ionic "Gruppe hinzufügen" sheet (FAB): Gruppe + Kategorie → Hinzufügen.
Future<void> _showAddGroupSheet(
  BuildContext context,
  WidgetRef ref,
  List<GroupCategory> categories,
) async {
  final added = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true, // IOS_SHELL2: above the tab bar
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _AddGroupSheet(categories: categories),
  );
  if (added == true) ref.invalidate(playerCountsForGroupsProvider);
  if (added == false && context.mounted) {
    ToastHelper.showError(context, context.l10n.instrumentsFlutterAddFailed);
  }
}

/// Owns its controller so it is disposed after the sheet's exit animation.
class _AddGroupSheet extends ConsumerStatefulWidget {
  const _AddGroupSheet({required this.categories});

  final List<GroupCategory> categories;

  @override
  ConsumerState<_AddGroupSheet> createState() => _AddGroupSheetState();
}

class _AddGroupSheetState extends ConsumerState<_AddGroupSheet> {
  final _controller = TextEditingController();
  int? _categoryId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ToastHelper.showError(context, context.l10n.instrumentsEnterName);
      return;
    }
    final created =
        await ref.read(groupNotifierProvider.notifier).createGroup({
      'name': name,
      'maingroup': false,
      if (_categoryId != null) 'category': _categoryId,
    });
    if (mounted) Navigator.pop(context, created != null);
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories;
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.paddingM,
        right: AppDimensions.paddingM,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.paddingM,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.instrumentsAddGroup,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimensions.paddingM),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.l10n.peopleGroup,
              hintText: context.l10n.instrumentsGroupPh,
            ),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.paddingM),
            AppDropdownFormField<int?>(
              iosInterface: AppSelectInterface.alert, // IOS_THEME2
              value: _categoryId,
              decoration: InputDecoration(labelText: context.l10n.instrumentsCategory),
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(context.l10n.generalSettingsNone)),
                for (final c in categories)
                  DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ],
          const SizedBox(height: AppDimensions.paddingL),
          FilledButton(
            onPressed: _add,
            child: Text(context.l10n.attendanceAdd),
          ),
        ],
      ),
    );
  }
}

/// Opens the instrument page (Ionic InstrumentPage modal) for [group].
Future<void> _openInstrumentPage(
  BuildContext context,
  WidgetRef ref,
  Group group,
  List<GroupCategory> categories, {
  String? tenantType,
}) async {
  final result = await Navigator.of(context, rootNavigator: true).push<Map<String, dynamic>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _InstrumentEditDialog(
        group: group,
        categories: categories,
        tenantType: tenantType,
      ),
    ),
  );
  if (result == null || !context.mounted) return;

  final cannotDelete = context.l10n.instrumentsCannotDelete;
  final notifier = ref.read(groupNotifierProvider.notifier);
  if (result['_delete'] == true) {
    final count =
        ref.read(playerCountsForGroupsProvider).valueOrNull?[group.id] ?? 0;
    if (count > 0) {
      ToastHelper.showError(context, cannotDelete);
      return;
    }
    await notifier.deleteGroup(group.id!);
    if (!context.mounted) return;
    if (ref.read(groupNotifierProvider).hasError) {
      ToastHelper.showError(context, cannotDelete);
    }
  } else {
    final updated = await notifier.updateGroup(group.id!, result);
    if (!context.mounted) return;
    if (updated != null) {
      ToastHelper.showSuccess(
          context, context.l10n.instrumentsUpdated(result['name'] as Object));
    } else {
      ToastHelper.showError(context, context.l10n.peopleSaveFailed);
    }
  }
  ref.invalidate(playerCountsForGroupsProvider);
}

/// Tuning options for instruments
const _tuningOptions = ['C', 'Es', 'B', 'F'];

/// Clef options
const _clefOptions = ['G', 'F', 'C'];

/// MISC2: localized clef names (Ionic common.clef.*)
String _clefLabel(AppLocalizations l10n, String clef) => switch (clef.toUpperCase()) {
      'G' => l10n.commonClefG,
      'F' => l10n.commonClefF,
      'C' => l10n.commonClefC,
      _ => l10n.instrumentsFlutterClef(clef.toUpperCase()),
    };

/// Dialog for editing/creating an instrument with all fields
class _InstrumentEditDialog extends ConsumerStatefulWidget {
  const _InstrumentEditDialog({
    this.group,
    required this.categories,
    this.tenantType,
  });

  final Group? group;
  final List<GroupCategory> categories;
  final String? tenantType;

  @override
  ConsumerState<_InstrumentEditDialog> createState() => _InstrumentEditDialogState();
}

class _InstrumentEditDialogState extends ConsumerState<_InstrumentEditDialog> {
  bool _generatingSynonyms = false;

  // MISC2: Ionic instrument.page generateSynonyms (synonyms-gpt Edge Function)
  Future<void> _generateSynonyms() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ToastHelper.showError(context, context.l10n.instrumentsNameFirst);
      return;
    }
    setState(() => _generatingSynonyms = true);
    try {
      final synonyms = await ref.read(aiServiceProvider).getGroupSynonyms(name);
      _synonymsController.text = synonyms;
      if (mounted) ToastHelper.showSuccess(context, context.l10n.instrumentsSynonymsGenerated);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.instrumentsSynonymsFailed);
    } finally {
      if (mounted) setState(() => _generatingSynonyms = false);
    }
  }

  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late final TextEditingController _rangeController;
  late final TextEditingController _synonymsController;
  final _formKey = GlobalKey<FormState>();

  int? _selectedCategoryId;
  String _selectedTuning = 'C';
  Set<String> _selectedClefs = {'G'};

  bool get isEditing => widget.group != null;

  @override
  void initState() {
    super.initState();
    final group = widget.group;
    _nameController = TextEditingController(text: group?.name ?? '');
    _notesController = TextEditingController(text: group?.notes ?? '');
    _rangeController = TextEditingController(text: group?.range ?? '');
    _synonymsController = TextEditingController(text: group?.synonyms ?? '');
    _selectedCategoryId = group?.categoryId;
    _selectedTuning = group?.tuning ?? 'C';
    _selectedClefs = (group?.clefs ?? ['g'])
        .map((c) => c.toUpperCase())
        .toSet();
    if (_selectedClefs.isEmpty) _selectedClefs = {'G'};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _rangeController.dispose();
    _synonymsController.dispose();
    super.dispose();
  }

  bool get _isChoir => widget.tenantType == 'choir';
  bool get _isGeneral => widget.tenantType == 'general';
  bool get _isMain => widget.group?.maingroup == true;

  /// Ionic InstrumentPage: Name, Kategorie, Stimmung, Tonumfang,
  /// Notenschlüssel, Synonyme, Notizen → "Aktualisieren" / "Entfernen".
  @override
  Widget build(BuildContext context) {
    final showMusicFields = !_isChoir && !_isGeneral && !_isMain;
    return Scaffold(
      // PARITY_R5: instrument.page.html `<ion-content>` without colour → white.
      backgroundColor: ionPlainContentBackground(context),
      appBar: AppBar(
        title: Text(widget.group?.name ?? context.l10n.instrumentsAddGroup),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.commonClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: context.l10n.typeSettingsName),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.l10n.instrumentsNameRequired;
                }
                return null;
              },
              autofocus: !isEditing,
            ),
            const SizedBox(height: AppDimensions.paddingM),
            AppDropdownFormField<int?>(
              iosInterface: AppSelectInterface.alert, // IOS_THEME2
              value: _selectedCategoryId,
              decoration: InputDecoration(labelText: context.l10n.instrumentsCategory),
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(context.l10n.generalSettingsNone)),
                ...widget.categories.map((cat) => DropdownMenuItem<int?>(
                      value: cat.id,
                      child: Text(cat.name),
                    )),
              ],
              onChanged: (value) => setState(() => _selectedCategoryId = value),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            if (showMusicFields) ...[
              AppDropdownFormField<String>(
                value: _tuningOptions.contains(_selectedTuning)
                    ? _selectedTuning
                    : 'C',
                decoration: InputDecoration(labelText: context.l10n.instrumentsTuning),
                items: _tuningOptions
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedTuning = value);
                },
              ),
              const SizedBox(height: AppDimensions.paddingM),
              TextFormField(
                controller: _rangeController,
                decoration: InputDecoration(labelText: context.l10n.instrumentsRange),
              ),
              const SizedBox(height: AppDimensions.paddingM),
              Text(
                context.l10n.instrumentsFlutterClefs,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.medium),
              ),
              const SizedBox(height: AppDimensions.paddingXS),
              Wrap(
                spacing: AppDimensions.paddingS,
                children: _clefOptions.map((clef) {
                  final isSelected = _selectedClefs.contains(clef);
                  return FilterChip(
                    label: Text('${_clefLabel(context.l10n, clef)} ($clef)'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedClefs.add(clef);
                        } else if (_selectedClefs.length > 1) {
                          _selectedClefs.remove(clef);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimensions.paddingM),
            ],
            if (!_isGeneral && !_isMain) ...[
              TextFormField(
                controller: _synonymsController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.l10n.instrumentsSynonyms,
                  helperText: context.l10n.instrumentsSynonymsHelper,
                  helperMaxLines: 4,
                  suffixIcon: _generatingSynonyms
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: AppSpinner(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: context.l10n.instrumentsFlutterGenerateSynonyms,
                          icon: const Icon(Icons.auto_awesome_outlined),
                          onPressed: _generateSynonyms,
                        ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingM),
            ],
            TextFormField(
              controller: _notesController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: context.l10n.peopleNotes),
              minLines: 1,
              maxLines: 5,
            ),
            // DB_FIX: the Flutter-only "Kurzname" field was removed —
            // `instruments` has no shortName column (Ionic pickGroupFields),
            // so every group save failed with PGRST204.
            const SizedBox(height: AppDimensions.paddingL),
            FilledButton(
              onPressed: _save,
              child: Text(isEditing ? context.l10n.instrumentsUpdate : context.l10n.attendanceAdd),
            ),
            if (isEditing && !_isMain) ...[
              const SizedBox(height: AppDimensions.paddingS),
              FilledButton(
                onPressed: () => _confirmDelete(context),
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                child: Text(context.l10n.commonRemove),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final result = <String, dynamic>{
        'name': _nameController.text.trim(),
        'tuning': _selectedTuning,
        'clefs': _selectedClefs.map((c) => c.toLowerCase()).toList(),
      };

      // Category — send the value even if null to clear it
      result['category'] = _selectedCategoryId;

      final range = _rangeController.text.trim();
      result['range'] = range.isNotEmpty ? range : null;

      final synonyms = _synonymsController.text.trim();
      result['synonyms'] = synonyms.isNotEmpty ? synonyms : null;

      final notes = _notesController.text.trim();
      result['notes'] = notes.isNotEmpty ? notes : null;

      Navigator.of(context).pop(result);
    }
  }

  /// Ionic: alert "Bestätigen" / "Gruppe wirklich löschen?" → Abbrechen / Ja.
  void _confirmDelete(BuildContext context) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.commonConfirm),
        content: Text(context.l10n.instrumentsDeleteGroup),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonYes),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop({'_delete': true});
    }
  }
}
