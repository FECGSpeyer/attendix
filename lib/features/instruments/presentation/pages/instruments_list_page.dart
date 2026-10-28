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
      ToastHelper.showError(context, 'Fehler beim Speichern der Reihenfolge');
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

    return Scaffold(
      // Ionic header: back, "Gruppen (n)", reorder toggle + categories
      appBar: AppBar(
        title: Text('Gruppen ($count)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: Icon(_isReordering ? Icons.check : Icons.swap_vert),
              tooltip: _isReordering
                  ? 'Reihenfolge speichern'
                  : 'Reihenfolge anpassen',
              onPressed: groupsAsync.hasValue
                  ? () => _toggleReorder(groupsAsync.value!,
                      categoriesAsync.valueOrNull ?? const [])
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.sell_outlined),
              onPressed: () => showInstrumentCategoriesSheet(context),
              tooltip: 'Kategorien',
            ),
          ],
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text('Fehler: $error'),
              const SizedBox(height: AppDimensions.paddingM),
              ElevatedButton(
                onPressed: () => ref.invalidate(groupsProvider),
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
        data: (groups) {
          final categories = categoriesAsync.valueOrNull ?? [];
          final playerCounts = playerCountsAsync.valueOrNull ?? {};
          final sections = _isReordering && _reorderSections != null
              ? _reorderSections!
              : groupInstrumentsByCategory(groups, categories);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(groupsProvider);
              ref.invalidate(groupCategoriesProvider);
              ref.invalidate(playerCountsForGroupsProvider);
              await ref.read(groupsProvider.future);
            },
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
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showAddGroupSheet(
                  context, ref, categoriesAsync.valueOrNull ?? const []),
              child: const Icon(Icons.add),
            )
          : null,
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
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (isReordering)
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM, vertical: 10),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.white),
                SizedBox(width: AppDimensions.paddingM),
                Expanded(
                  child: Text(
                    'Ziehe die Gruppen, um die Reihenfolge anzupassen. '
                    'Klicke auf das Häkchen, um zu speichern.',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        for (final section in sections) ...[
          _SectionHeader(title: section.name, count: section.groups.length),
          if (isReordering)
            ReorderableListView(
              key: ValueKey('section-${section.categoryId}'),
              shrinkWrap: true,
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
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM, vertical: 6),
      child: Text(
        '$title ($count)',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
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
      title = '${group.name} (Hauptgruppe)';
    } else if (!_isChoirOrGeneral) {
      title = '${group.name} (${group.tuning ?? 'C'})';
    } else {
      title = group.name;
    }
    final clefText =
        (group.clefs ?? const <String>[]).map(_clefLabel).join(', ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom:
                  BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM, vertical: 10),
          child: Row(
            children: [
              if (dragIndex != null) ...[
                ReorderableDragStartListener(
                  index: dragIndex!,
                  child: const Icon(Icons.reorder, color: AppColors.medium),
                ),
                const SizedBox(width: AppDimensions.paddingM),
              ],
              if (group.sortOrder != null) ...[
                _Badge(text: '${group.sortOrder}', color: AppColors.medium),
                const SizedBox(width: AppDimensions.paddingM),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    if (group.maingroup != true &&
                        !_isChoirOrGeneral &&
                        clefText.isNotEmpty)
                      Text(clefText, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              _Badge(
                text: playerCount == 1 ? '1 Person' : '$playerCount Personen',
                color: playerCount == 0 ? AppColors.danger : AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ionic ion-badge
class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
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
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _AddGroupSheet(categories: categories),
  );
  if (added == true) ref.invalidate(playerCountsForGroupsProvider);
  if (added == false && context.mounted) {
    ToastHelper.showError(context, 'Fehler beim Hinzufügen');
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
      ToastHelper.showError(context, 'Bitte gib einen Namen an');
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
          Text('Gruppe hinzufügen',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimensions.paddingM),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Gruppe',
              hintText: 'z.B. Mädchen, Posaune, Alt 1, etc.',
            ),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.paddingM),
            DropdownButtonFormField<int?>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Kategorie'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Keine')),
                for (final c in categories)
                  DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ],
          const SizedBox(height: AppDimensions.paddingL),
          FilledButton(
            onPressed: _add,
            child: const Text('Hinzufügen'),
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
  final result = await Navigator.of(context).push<Map<String, dynamic>>(
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

  const cannotDelete =
      'Du kannst das Instrument nicht löschen, da es Spieler gibt (gab), die darauf spielen';
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
          context, '${result['name']} wurde erfolgreich aktualisiert');
    } else {
      ToastHelper.showError(context, 'Fehler beim Speichern');
    }
  }
  ref.invalidate(playerCountsForGroupsProvider);
}

/// Tuning options for instruments
const _tuningOptions = ['C', 'Es', 'B', 'F'];

/// Clef options
const _clefOptions = ['G', 'F', 'C'];

/// MISC2: localized clef names (Ionic common.clef.*)
const _clefNames = {'G': 'Violinschlüssel', 'F': 'Bassschlüssel', 'C': 'Altschlüssel'};
String _clefLabel(String clef) => _clefNames[clef.toUpperCase()] ?? '${clef.toUpperCase()}-Schlüssel';

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
      ToastHelper.showError(context, 'Bitte gib zuerst einen Namen an!');
      return;
    }
    setState(() => _generatingSynonyms = true);
    try {
      final synonyms = await ref.read(aiServiceProvider).getGroupSynonyms(name);
      _synonymsController.text = synonyms;
      if (mounted) ToastHelper.showSuccess(context, 'Synonyme erfolgreich generiert!');
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Fehler beim Generieren der Synonyme');
    } finally {
      if (mounted) setState(() => _generatingSynonyms = false);
    }
  }

  late final TextEditingController _nameController;
  late final TextEditingController _shortNameController;
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
    _shortNameController = TextEditingController(text: group?.shortName ?? '');
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
    _shortNameController.dispose();
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
      appBar: AppBar(
        title: Text(widget.group?.name ?? 'Gruppe hinzufügen'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Schließen',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte gib einen Namen an!';
                }
                return null;
              },
              autofocus: !isEditing,
            ),
            const SizedBox(height: AppDimensions.paddingM),
            DropdownButtonFormField<int?>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Kategorie'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Keine')),
                ...widget.categories.map((cat) => DropdownMenuItem<int?>(
                      value: cat.id,
                      child: Text(cat.name),
                    )),
              ],
              onChanged: (value) => setState(() => _selectedCategoryId = value),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            if (showMusicFields) ...[
              DropdownButtonFormField<String>(
                value: _tuningOptions.contains(_selectedTuning)
                    ? _selectedTuning
                    : 'C',
                decoration: const InputDecoration(labelText: 'Stimmung'),
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
                decoration: const InputDecoration(labelText: 'Tonumfang'),
              ),
              const SizedBox(height: AppDimensions.paddingM),
              Text(
                'Notenschlüssel',
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
                    label: Text('${_clefLabel(clef)} ($clef)'),
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
                  labelText: 'Synonyme',
                  helperText:
                      'Definiere Synonyme um beim Hinzufügen von Dateien zu Werken die Instrumente automatisch zuordnen zu können. Synonyme durch Komma trennen.',
                  helperMaxLines: 4,
                  suffixIcon: _generatingSynonyms
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Synonyme generieren',
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
              decoration: const InputDecoration(labelText: 'Notizen'),
              minLines: 1,
              maxLines: 5,
            ),
            const SizedBox(height: AppDimensions.paddingM),
            // Flutter extra (not in Ionic): short name used in exports
            TextFormField(
              controller: _shortNameController,
              decoration: const InputDecoration(labelText: 'Kurzname'),
            ),
            const SizedBox(height: AppDimensions.paddingL),
            FilledButton(
              onPressed: _save,
              child: Text(isEditing ? 'Aktualisieren' : 'Hinzufügen'),
            ),
            if (isEditing && !_isMain) ...[
              const SizedBox(height: AppDimensions.paddingS),
              FilledButton(
                onPressed: () => _confirmDelete(context),
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                child: const Text('Entfernen'),
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

      final shortName = _shortNameController.text.trim();
      if (shortName.isNotEmpty) {
        result['shortName'] = shortName;
      } else {
        result['shortName'] = null;
      }

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bestätigen'),
        content: const Text('Gruppe wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ja'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop({'_delete': true});
    }
  }
}
