import 'package:flutter/material.dart';
import 'package:attendix/shared/widgets/dialogs/ion_sheet.dart';
import 'package:attendix/core/theme/redesign/rd_theme.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/base_repository.dart' show RepositoryException;
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
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../people/presentation/widgets/ion/ion_widgets.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import '../../../../shared/widgets/layout/ion_form_items.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart' show ionPlainContentBackground;

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

  /// Whether an item was actually moved in the current reorder session
  bool _moved = false;

  Future<void> _toggleReorder(
      List<Group> groups, List<GroupCategory> categories) async {
    if (!_isReordering) {
      setState(() {
        _isReordering = true;
        _moved = false;
        _reorderSections = groupInstrumentsByCategory(groups, categories);
      });
      return;
    }

    // Leaving reorder mode → save global order. Ionic saveOrder: without a
    // move the existing sort_order values are written unchanged (null stays
    // null); only a real move renumbers 1..n.
    final sections = _reorderSections ?? const <InstrumentCategorySection>[];
    final Map<int, int?> orders = _moved
        ? computeGlobalSortOrder(sections)
        : {
            for (final g in groups)
              if (g.id != null) g.id!: g.sortOrder,
          };
    setState(() {
      _isReordering = false;
      _reorderSections = null;
      _moved = false;
    });
    final notifier = ref.read(groupNotifierProvider.notifier);
    // EIB-19: Ionic saveOrder shows `ion-loading` "Reihenfolge wird
    // gespeichert…" while saving.
    final ok = context.rdSkin == null
        ? await withIonLoading(context, () => notifier.saveGroupOrder(orders),
            message: context.l10n.instrumentsSavingOrder)
        : await notifier.saveGroupOrder(orders);
    if (!mounted) return;
    if (ok) {
      ToastHelper.showSuccess(context, context.l10n.typeSettingsOrderSaved);
    } else {
      ToastHelper.showError(context, context.l10n.instrumentsOrderFailed);
    }
  }

  void _onReorder(
      InstrumentCategorySection section, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      if (newIndex != oldIndex) _moved = true;
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
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => context.go('/settings'),
      ),
      // EIB-12: Ionic – both end buttons share one `ion-buttons` group (iOS
      // glass capsule; md / Beta a plain row).
      actions: [
        if (isAdmin) ToolbarButtonGroup(children: [
          IconButton(
            icon: Icon(_isReordering ? AppIcons.check : AppIcons.swapVert),
            tooltip: _isReordering
                ? context.l10n.peopleFlutterSaveOrder
                : context.l10n.peopleReorder,
            onPressed: groupsAsync.hasValue
                ? () => _toggleReorder(groupsAsync.value!,
                    categoriesAsync.valueOrNull ?? const [])
                : null,
          ),
          IconButton(
            icon: Icon(AppIcons.sellOutlined),
            onPressed: () => showInstrumentCategoriesSheet(context),
            tooltip: context.l10n.instrumentsCategories,
          ),
        ]),
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
                icon: AppIcons.errorOutline,
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
              onPressed: () => showAddGroupSheet(
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
            start: Icon(AppIcons.info, color: Colors.white),
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
      title = '${group.name} (${group.tuning ?? ''})';
    } else {
      title = group.name;
    }
    final clefText =
        (group.clefs ?? const <String>[]).map((c) => groupClefLabel(context.l10n, c)).join(', ');

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
                    child: Icon(AppIcons.reorder, color: AppColors.medium),
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
/// Also used by the Beta list "Gruppen" (rd_groups_page.dart).
Future<void> showAddGroupSheet(
  BuildContext context,
  WidgetRef ref,
  List<GroupCategory> categories,
) async {
  final added = context.rdSkin == null
      // Ionic add-group modal: [breakpoints]="[0, 0.8]"
      // [initialBreakpoint]="0.8", ion-toolbar with the ion-title only.
      ? await showIonSheet<bool>(
          context,
          breakpoints: const [0, 0.8],
          initialBreakpoint: 0.8,
          builder: (ctx, controller) => IonSheetScaffold(
            title: ctx.l10n.instrumentsAddGroup,
            body: SingleChildScrollView(
              controller: controller,
              child: _AddGroupSheet(categories: categories, showTitle: false),
            ),
          ),
        )
      : await showModalBottomSheet<bool>(
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
  const _AddGroupSheet({required this.categories, this.showTitle = true});

  final List<GroupCategory> categories;

  /// False in the classic sheet: the title is in the sheet toolbar.
  final bool showTitle;

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

  String _categoryName(BuildContext context) =>
      widget.categories.where((c) => c.id == _categoryId).map((c) => c.name).firstOrNull ??
      context.l10n.generalSettingsNone;

  /// EIB-02 / EIB-04: classic sheet content – `ion-item`s with stacked
  /// labels (input with placeholder, `ion-select labelPlacement="stacked"`)
  /// and the square full-width `ion-button expand="full"`.
  Widget _buildClassic(BuildContext context) {
    final categories = widget.categories;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IonStackedInputItem(
          label: context.l10n.peopleGroup,
          controller: _controller,
          placeholder: context.l10n.instrumentsGroupPh,
          autofocus: true,
        ),
        if (categories.isNotEmpty)
          IonSelectItem(
            stacked: true,
            label: context.l10n.instrumentsCategory,
            value: _categoryName(context),
            onOpen: (anchor) async {
              final picked = await showAppSelect<int?>(
                context: anchor,
                interface: AppSelectInterface.alert,
                header: context.l10n.instrumentsCategory,
                value: _categoryId,
                options: [
                  AppSelectOption<int?>(value: null, label: context.l10n.generalSettingsNone),
                  for (final c in categories) AppSelectOption<int?>(value: c.id, label: c.name),
                ],
              );
              if (picked != null && mounted) setState(() => _categoryId = picked.value);
            },
          ),
        IonFullButton(
          onPressed: _add,
          child: IonButtonLabel(context.l10n.attendanceAdd),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showTitle) return _buildClassic(context);
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
          if (widget.showTitle) ...[
            Text(context.l10n.instrumentsAddGroup,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimensions.paddingM),
          ],
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
              interface: AppSelectInterface.alert,
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
            child: IonButtonLabel(context.l10n.attendanceAdd),
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
  Widget page(BuildContext _) => _InstrumentEditDialog(
        group: group,
        categories: categories,
        tenantType: tenantType,
      );
  // EIB-01: Ionic `modalController.create({ component: InstrumentPage,
  // presentingElement })` – iOS card modal, md phone full screen, from
  // 768px a centred 600px card. The Beta keeps its full-screen route.
  final result = context.rdSkin == null
      ? await showIonCardModal<bool>(
          context,
          builder: page,
          iosBackgroundColor: ionPlainContentBackground(context),
        )
      : await Navigator.of(context, rootNavigator: true).push<bool>(
          MaterialPageRoute(fullscreenDialog: true, builder: page),
        );
  // Ionic InstrumentPage saves/deletes itself and dismisses with
  // {updated: true}; the list then reloads.
  if (result == null || !context.mounted) return;
  ref.invalidate(playerCountsForGroupsProvider);
}

/// Tuning options for instruments
const groupTuningOptions = ['C', 'Es', 'B', 'F'];

/// Clef options
const groupClefOptions = ['G', 'F', 'C'];

/// MISC2: localized clef names (Ionic common.clef.*)
String groupClefLabel(AppLocalizations l10n, String clef) => switch (clef.toUpperCase()) {
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
    // EIB-19: Ionic shows `ion-loading` "Synonyme werden generiert…".
    final loading = context.rdSkin == null
        ? showIonLoading(context, message: context.l10n.instrumentsGeneratingSynonyms)
        : null;
    try {
      final synonyms = await ref.read(aiServiceProvider).getGroupSynonyms(name);
      loading?.dismiss();
      _synonymsController.text = synonyms;
      if (mounted) ToastHelper.showSuccess(context, context.l10n.instrumentsSynonymsGenerated);
    } catch (_) {
      loading?.dismiss();
      if (mounted) ToastHelper.showError(context, context.l10n.instrumentsSynonymsFailed);
    } finally {
      loading?.dismiss();
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
  String _categoryName(BuildContext context) =>
      widget.categories.where((c) => c.id == _selectedCategoryId).map((c) => c.name).firstOrNull ??
      context.l10n.generalSettingsNone;

  /// EIB-01 / EIB-04 / EIB-05: Ionic instrument.page in the classic design –
  /// modal toolbar (title, close in `slot="end"`), an `ion-grid` of
  /// `ion-item`s with stacked labels, the tuning / clef selects with the
  /// label at the start, two block buttons.
  Widget _buildClassic(BuildContext context) {
    final l10n = context.l10n;
    final showMusicFields = !_isChoir && !_isGeneral && !_isMain;
    // ion-grid padding 5 + ion-col padding 5.
    Widget col(Widget child) => Padding(padding: const EdgeInsets.all(5), child: child);
    final clefs = groupClefOptions.where(_selectedClefs.contains).toList();
    return IonSheetScaffold(
      title: widget.group?.name ?? l10n.instrumentsAddGroup,
      showClose: true,
      backgroundColor: ionPlainContentBackground(context),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.only(bottom: scrollEndPadding(context, base: AppDimensions.paddingM)),
          children: [
            Padding(
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  col(IonStackedInputItem(
                    label: l10n.typeSettingsName,
                    controller: _nameController,
                    autofocus: !isEditing,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? l10n.instrumentsNameRequired
                        : null,
                  )),
                  col(IonSelectItem(
                    stacked: true,
                    label: l10n.instrumentsCategory,
                    value: _categoryName(context),
                    onOpen: (anchor) async {
                      final picked = await showAppSelect<int?>(
                        context: anchor,
                        interface: AppSelectInterface.alert,
                        header: l10n.instrumentsCategory,
                        value: _selectedCategoryId,
                        options: [
                          AppSelectOption<int?>(value: null, label: l10n.generalSettingsNone),
                          for (final c in widget.categories)
                            AppSelectOption<int?>(value: c.id, label: c.name),
                        ],
                      );
                      if (picked != null && mounted) {
                        setState(() => _selectedCategoryId = picked.value);
                      }
                    },
                  )),
                  if (showMusicFields) ...[
                    // `ion-select interface="popover" [label]` (label at
                    // the start, value at the end).
                    col(IonSelectItem(
                      label: l10n.instrumentsTuning,
                      value: groupTuningOptions.contains(_selectedTuning) ? _selectedTuning : 'C',
                      onOpen: (anchor) async {
                        final picked = await showAppSelect<String>(
                          context: anchor,
                          interface: AppSelectInterface.popover,
                          value: _selectedTuning,
                          options: [
                            for (final t in groupTuningOptions) AppSelectOption(value: t, label: t),
                          ],
                        );
                        if (picked != null && mounted) {
                          setState(() => _selectedTuning = picked.value);
                        }
                      },
                    )),
                    col(IonStackedInputItem(
                      label: l10n.instrumentsRange,
                      controller: _rangeController,
                    )),
                    // `ion-select multiple`: one item row, the choice in a
                    // checkbox list. Ionic labels it "Stimmung" (copy bug);
                    // the label stays "Notenschlüssel".
                    col(IonSelectItem(
                      label: l10n.instrumentsFlutterClefs,
                      value: clefs.map((c) => '${groupClefLabel(l10n, c)} ($c)').join(', '),
                      onOpen: (anchor) async {
                        final picked = await showAppMultiSelect<String>(
                          context: anchor,
                          header: l10n.instrumentsFlutterClefs,
                          values: clefs,
                          options: [
                            for (final c in groupClefOptions)
                              AppSelectOption(value: c, label: '${groupClefLabel(l10n, c)} ($c)'),
                          ],
                        );
                        // At least one clef stays selected (as before).
                        if (picked != null && picked.isNotEmpty && mounted) {
                          setState(() => _selectedClefs = picked.toSet());
                        }
                      },
                    )),
                  ],
                  if (!_isGeneral && !_isMain)
                    col(IonStackedInputItem(
                      label: l10n.instrumentsSynonyms,
                      controller: _synonymsController,
                      helper: l10n.instrumentsSynonymsHelper,
                      // `<ion-button slot="end" fill="clear">` sparkles.
                      end: IconButton(
                        tooltip: l10n.instrumentsFlutterGenerateSynonyms,
                        color: AppColors.primary,
                        icon: Icon(AppIcons.autoAwesomeOutlined),
                        onPressed: _generatingSynonyms ? null : _generateSynonyms,
                      ),
                    )),
                  col(IonStackedInputItem(
                    label: l10n.peopleNotes,
                    controller: _notesController,
                    textarea: true,
                  )),
                ],
              ),
            ),
            IonButton(
              expand: true,
              label: isEditing ? l10n.instrumentsUpdate : l10n.attendanceAdd,
              onPressed: _busy ? null : _save,
            ),
            if (isEditing && !_isMain) ...[
              const SizedBox(height: 8),
              IonButton(
                expand: true,
                color: AppColors.danger,
                label: l10n.commonRemove,
                onPressed: _busy ? null : () => _confirmDelete(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.rdSkin == null) return _buildClassic(context);
    final showMusicFields = !_isChoir && !_isGeneral && !_isMain;
    return Scaffold(
      // PARITY_R5: instrument.page.html `<ion-content>` without colour → white.
      backgroundColor: ionPlainContentBackground(context),
      appBar: AppBar(
        title: Text(widget.group?.name ?? context.l10n.instrumentsAddGroup),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(AppIcons.close),
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
              interface: AppSelectInterface.alert,
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
                value: groupTuningOptions.contains(_selectedTuning)
                    ? _selectedTuning
                    : 'C',
                decoration: InputDecoration(labelText: context.l10n.instrumentsTuning),
                items: groupTuningOptions
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
                children: groupClefOptions.map((clef) {
                  final isSelected = _selectedClefs.contains(clef);
                  return FilterChip(
                    label: Text('${groupClefLabel(context.l10n, clef)} ($clef)'),
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
                          icon: Icon(AppIcons.autoAwesomeOutlined),
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
              onPressed: _busy ? null : _save,
              child: IonButtonLabel(isEditing ? context.l10n.instrumentsUpdate : context.l10n.attendanceAdd),
            ),
            if (isEditing && !_isMain) ...[
              const SizedBox(height: AppDimensions.paddingS),
              FilledButton(
                onPressed: _busy ? null : () => _confirmDelete(context),
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                child: IonButtonLabel(context.l10n.commonRemove),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Shared lock for save and delete (incl. count check and confirm
  /// dialog), so one cannot close or confirm the other.
  bool _busy = false;

  /// Trimmed text of [controller]; an empty field whose loaded value was null
  /// stays null (Ionic ngModel untouched), otherwise '' is written as ''.
  static String? _textValue(TextEditingController controller, String? loaded) {
    final text = controller.text.trim();
    return text.isEmpty && loaded == null ? null : text;
  }

  /// Ionic InstrumentPage.update(): saves, shows "{name} wurde erfolgreich
  /// aktualisiert" and closes only after the save. On an error the service
  /// toasts "Es kann nur eine Hauptgruppe existieren" (23505) or "Fehler beim
  /// updaten des Instruments" and the page stays open with the input.
  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    // Ionic InstrumentPage.update() writes the fields as loaded/entered:
    // '' stays '', an untouched null stays null, and fields hidden for this
    // group (choir/general/main group) keep their value. Text is trimmed.
    final group = widget.group!;
    final showMusicFields = !_isChoir && !_isGeneral && !_isMain;
    final result = <String, dynamic>{
      'name': _nameController.text.trim(),
      // Category — send the value even if null to clear it
      'category': _selectedCategoryId,
      'notes': _textValue(_notesController, group.notes),
    };

    if (showMusicFields) {
      // The picker shows 'C' / {'G'} for an unset value; only a real change
      // is written, otherwise the loaded value (also null / []) stays.
      final initialTuning = group.tuning ?? 'C';
      if (_selectedTuning != initialTuning) {
        result['tuning'] = _selectedTuning;
      }
      final initialClefs =
          (group.clefs ?? const ['g']).map((c) => c.toUpperCase()).toSet();
      if (initialClefs.isEmpty) initialClefs.add('G');
      if (_selectedClefs.length != initialClefs.length ||
          !_selectedClefs.containsAll(initialClefs)) {
        result['clefs'] = _selectedClefs.map((c) => c.toLowerCase()).toList();
      }
      result['range'] = _textValue(_rangeController, group.range);
    }

    if (!_isGeneral && !_isMain) {
      result['synonyms'] = _textValue(_synonymsController, group.synonyms);
    }

    final notifier = ref.read(groupNotifierProvider.notifier);
    setState(() => _busy = true);
    final updated = await notifier.updateGroup(widget.group!.id!, result);
    if (!mounted) return;
    setState(() => _busy = false);
    if (updated == null) {
      final error = ref.read(groupNotifierProvider).error;
      ToastHelper.showError(
        context,
        error is RepositoryException && error.code == '23505'
            ? context.l10n.svcOnlyOneMainGroup
            : context.l10n.svcUpdateGroupFailed,
      );
      return;
    }
    ToastHelper.showSuccess(
        context, context.l10n.instrumentsUpdated(result['name'] as Object));
    Navigator.of(context).pop(true);
  }

  /// Ionic InstrumentPage.delete(): first checks right away whether anyone
  /// (incl. archived, without pending registrations) is or was in the group
  /// → toast, page stays open. Otherwise alert "Bestätigen" / "Gruppe
  /// wirklich löschen?" → Abbrechen / Ja → delete and close.
  Future<void> _confirmDelete(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _delete(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final group = widget.group!;
    final repo = ref.read(groupRepositoryWithTenantProvider);
    final notifier = ref.read(groupNotifierProvider.notifier);
    final cannotDelete = context.l10n.instrumentsCannotDelete;
    int count;
    try {
      count = await repo.getPlayerCountInGroup(group.id!, includeArchived: true);
    } catch (_) {
      count = 0;
    }
    if (!context.mounted) return;
    if (count > 0) {
      ToastHelper.showError(context, cannotDelete);
      return;
    }
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.commonConfirm),
        content: Text(context.l10n.instrumentsDeleteGroup),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            // EIB-18: Ionic `role: 'destructive'` on "Abbrechen".
            style: appAlertDestructiveStyle(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonYes),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await notifier.deleteGroup(group.id!);
    if (!context.mounted) return;
    if (ref.read(groupNotifierProvider).hasError) {
      ToastHelper.showError(context, cannotDelete);
      return;
    }
    Navigator.of(context).pop(true);
  }
}
